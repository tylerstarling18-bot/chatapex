import Float "mo:core/Float";
import List "mo:core/List";
import TrainingTypes "../types/training";
import TradingTypes "../types/trading";
import AnalyticsTypes "../types/analytics";
import MarketTypes "../types/market";
import ConfidenceTypes "../types/confidence";

// AI training and learning engine
module {
  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  func regimeEqual(a : MarketTypes.MarketCondition, b : MarketTypes.MarketCondition) : Bool {
    switch (a, b) {
      case (#StrongBullish, #StrongBullish)   true;
      case (#Bullish, #Bullish)               true;
      case (#Neutral, #Neutral)               true;
      case (#Ranging, #Ranging)               true;
      case (#WeakBearish, #WeakBearish)       true;
      case (#StrongBearish, #StrongBearish)   true;
      case (#HighVolatility, #HighVolatility) true;
      case (#ManipulationRisk, #ManipulationRisk) true;
      case (#LowLiquidityDanger, #LowLiquidityDanger) true;
      case _ false;
    };
  };

  func strategyEqual(
    a : TradingTypes.StrategyMode,
    b : TradingTypes.StrategyMode,
  ) : Bool {
    switch (a, b) {
      case (#TrendFollowing, #TrendFollowing) true;
      case (#MeanReversion,  #MeanReversion)  true;
      case (#Scalping,       #Scalping)        true;
      case (#Defensive,      #Defensive)       true;
      case (#Observation,    #Observation)     true;
      case _                                   false;
    };
  };

  // Clamp a float to [lo, hi]
  func clamp(v : Float, lo : Float, hi : Float) : Float {
    if (v < lo) lo else if (v > hi) hi else v;
  };

  // ---------------------------------------------------------------------------
  // updateStrategyPerformance
  // ---------------------------------------------------------------------------

  public func updateStrategyPerformance(
    performances : [TradingTypes.StrategyPerformance],
    trade : TradingTypes.Trade,
    decision : TradingTypes.TradeDecision,
    now : Int,
  ) : [TradingTypes.StrategyPerformance] {
    let isWin = switch (trade.pnl) { case (?p) p > 0.0; case null false };
    let pnl   = switch (trade.pnl) { case (?p) p; case null 0.0 };
    let strategy = decision.strategyMode;

    // Find existing entry
    let existing = performances.find(func(sp : TradingTypes.StrategyPerformance) : Bool {
      strategyEqual(sp.strategyMode, strategy)
    });

    let updated : TradingTypes.StrategyPerformance = switch (existing) {
      case (?sp) {
        let newTotal = sp.totalTrades + 1;
        let newWins  = if (isWin) sp.wins + 1 else sp.wins;
        let newLosses = if (not isWin) sp.losses + 1 else sp.losses;
        let newWinRate = if (newTotal > 0) newWins.toFloat() / newTotal.toFloat() * 100.0 else 0.0;
        // Rolling average confidence
        let newAvgConf = (sp.avgConfidence * sp.totalTrades.toFloat() + decision.confidence) / newTotal.toFloat();
        {
          strategyMode = sp.strategyMode;
          totalTrades = newTotal;
          wins = newWins;
          losses = newLosses;
          winRate = newWinRate;
          totalPnl = sp.totalPnl + pnl;
          avgConfidence = newAvgConf;
          lastUpdated = now;
        };
      };
      case null {
        {
          strategyMode = strategy;
          totalTrades = 1;
          wins = if (isWin) 1 else 0;
          losses = if (not isWin) 1 else 0;
          winRate = if (isWin) 100.0 else 0.0;
          totalPnl = pnl;
          avgConfidence = decision.confidence;
          lastUpdated = now;
        };
      };
    };

    // Rebuild array, replacing or appending
    let list = List.fromArray<TradingTypes.StrategyPerformance>(performances);
    let found = list.findIndex(func(sp : TradingTypes.StrategyPerformance) : Bool {
      strategyEqual(sp.strategyMode, strategy)
    });
    switch (found) {
      case (?idx) {
        list.put(idx, updated);
      };
      case null {
        list.add(updated);
      };
    };
    list.toArray();
  };

  // ---------------------------------------------------------------------------
  // updateFromTrade
  // ---------------------------------------------------------------------------

  public func updateFromTrade(
    state : TrainingTypes.AITrainingState,
    trade : TradingTypes.Trade,
    decision : TradingTypes.TradeDecision,
    now : Int,
  ) : TrainingTypes.AITrainingState {
    let newCount = state.practiceTradesCount + 1;

    // Recompute win rate from all strategy performances + this trade
    let newPerfs = updateStrategyPerformance(state.strategyPerformances, trade, decision, now);

    // Aggregate total wins across all strategies
    let totalWins = newPerfs.foldLeft<TradingTypes.StrategyPerformance, { wins : Nat; total : Nat }>(
      { wins = 0; total = 0 },
      func(acc : { wins : Nat; total : Nat }, sp : TradingTypes.StrategyPerformance) {
        { wins = acc.wins + sp.wins; total = acc.total + sp.totalTrades };
      },
    );
    let newWinRate = if (totalWins.total > 0)
      totalWins.wins.toFloat() / totalWins.total.toFloat() * 100.0
    else 0.0;

    // Rolling average confidence
    let newAvgConf = if (newCount > 0)
      (state.avgConfidenceScore * state.practiceTradesCount.toFloat() + decision.confidence) / newCount.toFloat()
    else decision.confidence;

    let newProgress = computeLearningProgressFromValues(newCount, newWinRate, state.confidenceCalibration);

    {
      state with
      practiceTradesCount = newCount;
      overallWinRate = newWinRate;
      avgConfidenceScore = newAvgConf;
      strategyPerformances = newPerfs;
      lastTrainingUpdate = now;
      learningProgress = newProgress;
    };
  };

  // ---------------------------------------------------------------------------
  // recalibrateConfidence
  // ---------------------------------------------------------------------------

  public func recalibrateConfidence(
    state : TrainingTypes.AITrainingState,
    recentDecisions : [TradingTypes.AIDecisionLog],
  ) : Float {
    if (recentDecisions.size() == 0) return state.confidenceCalibration;

    // Compare average predicted confidence vs actual win rate on executed trades
    let executed = recentDecisions.filter(func(d : TradingTypes.AIDecisionLog) : Bool {
      d.executionStatus == #Executed
    });
    if (executed.size() == 0) return state.confidenceCalibration;

    let n = executed.size().toFloat();
    let avgPredConf = executed.foldLeft(0.0, func(acc : Float, d : TradingTypes.AIDecisionLog) : Float {
      acc + d.decision.confidence;
    }) / n;

    // actualWinRate: fraction of executed trades where action != Hold/Skip
    // We approximate win by confidence > 50 (we don't have trade outcome here)
    // Use strategyPerformances win rate as the actual
    let actualWinRate = if (state.practiceTradesCount > 0) state.overallWinRate else 50.0;
    let predictedWinRate = avgPredConf; // confidence treated as win probability

    // If predicted >> actual: reduce calibration; if predicted << actual: increase
    let diff = (predictedWinRate - actualWinRate) / 100.0; // [-1, 1]
    let adjustment = -diff * 0.1; // dampen adjustment by 10x
    let newCal = clamp(state.confidenceCalibration + adjustment, 0.7, 1.3);
    newCal;
  };

  // ---------------------------------------------------------------------------
  // computeLearningProgress helpers
  // ---------------------------------------------------------------------------

  func computeLearningProgressFromValues(
    tradeCount : Nat,
    winRate : Float,
    calibration : Float,
  ) : Float {
    // Volume milestones (max 40 pts)
    let volumePts : Float =
      if (tradeCount >= 1000) 40.0
      else if (tradeCount >= 500) 30.0
      else if (tradeCount >= 100) 20.0
      else if (tradeCount >= 10)  10.0
      else 0.0;

    // Win rate bonus (max 30 pts)
    let winRatePts : Float =
      if (winRate >= 65.0) 30.0
      else if (winRate >= 60.0) 20.0
      else if (winRate >= 55.0) 15.0
      else if (winRate >= 50.0) 8.0
      else 0.0;

    // Calibration accuracy bonus (max 30 pts)
    // Best calibration is near 1.0; penalise deviation
    let calDev = if (calibration > 1.0) calibration - 1.0 else 1.0 - calibration;
    let calPts : Float = clamp(30.0 - calDev * 100.0, 0.0, 30.0);

    clamp(volumePts + winRatePts + calPts, 0.0, 100.0);
  };

  public func computeLearningProgress(
    state : TrainingTypes.AITrainingState,
  ) : Float {
    computeLearningProgressFromValues(
      state.practiceTradesCount,
      state.overallWinRate,
      state.confidenceCalibration,
    );
  };

  // ---------------------------------------------------------------------------
  // resetState
  // ---------------------------------------------------------------------------

  public func resetState(now : Int) : TrainingTypes.AITrainingState {
    {
      totalSessions = 0;
      practiceTradesCount = 0;
      overallWinRate = 0.0;
      avgConfidenceScore = 0.0;
      strategyPerformances = [];
      lastTrainingUpdate = now;
      confidenceCalibration = 1.0;
      learningProgress = 0.0;
      marketMemory = [];
      noTradeLog = [];
      correlationData = [];
      confidenceThreshold = 0.6;
      overtradingCount = 0;
      consecutiveLosses = 0;
    };
  };

  // ---------------------------------------------------------------------------
  // Market memory updates
  // ---------------------------------------------------------------------------

  // Update strategy performance broken down by market regime
  public func updateStrategyPerformanceByRegime(
    state       : TrainingTypes.AITrainingState,
    stratMode   : TradingTypes.StrategyMode,
    regime      : MarketTypes.MarketCondition,
    won         : Bool,
    pnl         : Float,
    holdTimeSecs : Int,
  ) : TrainingTypes.AITrainingState {
    let existing = state.marketMemory;
    let found = existing.findIndex(
      func(m : AnalyticsTypes.StrategyPerformanceByRegime) : Bool {
        strategyEqual(m.strategyMode, stratMode) and regimeEqual(m.marketCondition, regime)
      }
    );
    let updated : AnalyticsTypes.StrategyPerformanceByRegime = switch (found) {
      case (?idx) {
        let m = existing[idx];
        let total = m.winCount + m.lossCount + 1;
        let totalF = total.toFloat();
        {
          strategyMode     = m.strategyMode;
          marketCondition  = m.marketCondition;
          winCount         = if (won) m.winCount + 1 else m.winCount;
          lossCount        = if (not won) m.lossCount + 1 else m.lossCount;
          totalPnl         = m.totalPnl + pnl;
          avgPnl           = (m.totalPnl + pnl) / totalF;
          avgHoldTimeSeconds = ((m.avgHoldTimeSeconds * (total - 1).toInt()) + holdTimeSecs) / total.toInt();
        };
      };
      case null {
        {
          strategyMode       = stratMode;
          marketCondition    = regime;
          winCount           = if (won) 1 else 0;
          lossCount          = if (not won) 1 else 0;
          totalPnl           = pnl;
          avgPnl             = pnl;
          avgHoldTimeSeconds = holdTimeSecs;
        };
      };
    };

    let list = List.fromArray<AnalyticsTypes.StrategyPerformanceByRegime>(existing);
    switch (found) {
      case (?idx) { list.put(idx, updated) };
      case null   { list.add(updated) };
    };
    { state with marketMemory = list.toArray() };
  };

  // Win rate * 100 for a given strategy+regime pair; 50 if no data
  public func computeMarketMemoryScore(
    memory    : [AnalyticsTypes.StrategyPerformanceByRegime],
    stratMode : TradingTypes.StrategyMode,
    condition : MarketTypes.MarketCondition,
  ) : Float {
    switch (memory.find(
      func(m : AnalyticsTypes.StrategyPerformanceByRegime) : Bool {
        strategyEqual(m.strategyMode, stratMode) and regimeEqual(m.marketCondition, condition)
      }
    )) {
      case (?m) {
        let total = m.winCount + m.lossCount;
        if (total > 0) m.winCount.toFloat() / total.toFloat() * 100.0 else 50.0;
      };
      case null 50.0;
    };
  };

  // For each regime, find the best-performing strategy
  public func getTopSetupsByRegime(
    memory : [AnalyticsTypes.StrategyPerformanceByRegime],
  ) : [{ regime : MarketTypes.MarketCondition; bestStrategy : TradingTypes.StrategyMode; winRate : Float }] {
    let regimes : [MarketTypes.MarketCondition] = [
      #StrongBullish, #Bullish, #Neutral, #Ranging,
      #WeakBearish, #StrongBearish, #HighVolatility,
      #ManipulationRisk, #LowLiquidityDanger,
    ];
    regimes.filterMap(func(r : MarketTypes.MarketCondition) : ?{ regime : MarketTypes.MarketCondition; bestStrategy : TradingTypes.StrategyMode; winRate : Float } {
      let forRegime = memory.filter(func(m : AnalyticsTypes.StrategyPerformanceByRegime) : Bool {
        regimeEqual(m.marketCondition, r)
      });
      if (forRegime.size() == 0) return null;
      let best = forRegime.foldLeft(
        forRegime[0],
        func(acc : AnalyticsTypes.StrategyPerformanceByRegime, m : AnalyticsTypes.StrategyPerformanceByRegime) : AnalyticsTypes.StrategyPerformanceByRegime {
          let accTotal = acc.winCount + acc.lossCount;
          let mTotal   = m.winCount + m.lossCount;
          let accWR = if (accTotal > 0) acc.winCount.toFloat() / accTotal.toFloat() else 0.0;
          let mWR   = if (mTotal   > 0) m.winCount.toFloat()   / mTotal.toFloat()   else 0.0;
          if (mWR > accWR) m else acc;
        },
      );
      let total = best.winCount + best.lossCount;
      let wr = if (total > 0) best.winCount.toFloat() / total.toFloat() * 100.0 else 0.0;
      ?{ regime = r; bestStrategy = best.strategyMode; winRate = wr };
    });
  };

  // Append a NoTradeDecision to the no-trade log; rotate oldest when > 500
  public func appendNoTradeDecision(
    state    : TrainingTypes.AITrainingState,
    decision : ConfidenceTypes.NoTradeDecision,
  ) : TrainingTypes.AITrainingState {
    let existing = state.noTradeLog;
    let newLog = if (existing.size() >= 500) {
      // Drop oldest (first 100) and append
      existing.sliceToArray(100, existing.size().toInt()).concat([decision]);
    } else {
      existing.concat([decision]);
    };
    { state with noTradeLog = newLog };
  };

  // Nat-to-Float: provided by mo:core/Nat
};

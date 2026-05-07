import Float "mo:core/Float";
import Array "mo:core/Array";
import List "mo:core/List";
import MarketTypes "../types/market";
import TradingTypes "../types/trading";
import ArenaTypes "../types/arena";
import Indicators "indicators";
import AIEngine "ai_engine";

// Strategy competition arena — runs 6 agents through identical candle history
module {

  // ---------------------------------------------------------------------------
  // Arena agent definitions
  // ---------------------------------------------------------------------------

  public let aggressiveMomentum : ArenaTypes.ArenaAgent = {
    agentId           = "aggressive-momentum";
    name              = "Aggressive Momentum";
    description       = "High-risk momentum-chasing strategy";
    riskMultiplier    = 1.8;
    preferredTimeframe = "1h";
    strategyFocus     = #TrendFollowing;
  };

  public let conservativeRisk : ArenaTypes.ArenaAgent = {
    agentId           = "conservative-risk";
    name              = "Conservative Risk";
    description       = "Low-risk capital preservation strategy";
    riskMultiplier    = 0.8;
    preferredTimeframe = "4h";
    strategyFocus     = #MeanReversion;
  };

  public let scalping : ArenaTypes.ArenaAgent = {
    agentId           = "scalping";
    name              = "Scalping";
    description       = "High-frequency short-duration trades";
    riskMultiplier    = 1.0;
    preferredTimeframe = "1m";
    strategyFocus     = #Scalping;
  };

  public let swingTrading : ArenaTypes.ArenaAgent = {
    agentId           = "swing-trading";
    name              = "Swing Trading";
    description       = "Medium-term swing setups";
    riskMultiplier    = 1.0;
    preferredTimeframe = "4h";
    strategyFocus     = #Scalping; // maps to Scalping as closest swing proxy
  };

  public let meanReversion : ArenaTypes.ArenaAgent = {
    agentId           = "mean-reversion";
    name              = "Mean Reversion";
    description       = "Buys oversold, sells overbought";
    riskMultiplier    = 1.0;
    preferredTimeframe = "1h";
    strategyFocus     = #MeanReversion;
  };

  public let trendFollowing : ArenaTypes.ArenaAgent = {
    agentId           = "trend-following";
    name              = "Trend Following";
    description       = "Rides confirmed macro trends";
    riskMultiplier    = 1.2;
    preferredTimeframe = "1d";
    strategyFocus     = #TrendFollowing;
  };

  public let allAgents : [ArenaTypes.ArenaAgent] = [
    aggressiveMomentum,
    conservativeRisk,
    scalping,
    swingTrading,
    meanReversion,
    trendFollowing,
  ];

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  func floatSqrt(x : Float) : Float { Float.sqrt(x) };

  // Simple pseudo-random deterministic jitter using timestamp mod
  func slippage(price : Float, ts : Int) : Float {
    // 0.05% to 0.15% based on low bits of timestamp
    let factor : Float = 0.0005 + (((ts % 10).toFloat()) / 10.0) * 0.001;
    price * factor;
  };

  func fee(value : Float) : Float { value * 0.001 };

  // Compute Sharpe from daily equity returns
  func computeSharpe(curve : [{ value : Float }]) : Float {
    let n = curve.size();
    if (n < 2) return 0.0;
    let returns = Array.tabulate(n - 1, func(i) {
      let prev = curve[i].value;
      let curr = curve[i + 1].value;
      if (prev > 0.0) (curr - prev) / prev else 0.0;
    });
    let nF = returns.size().toFloat();
    if (nF == 0.0) return 0.0;
    let mean = returns.foldLeft(0.0, func(a : Float, r : Float) : Float { a + r }) / nF;
    let variance = returns.foldLeft(0.0, func(a : Float, r : Float) : Float {
      let d = r - mean; a + d * d;
    }) / nF;
    let std = floatSqrt(variance);
    if (std == 0.0) return 0.0;
    // Annualise
    mean / std * floatSqrt(252.0);
  };

  // Compute max drawdown from equity curve
  func computeMaxDrawdown(curve : [{ value : Float }]) : Float {
    var peak = 0.0;
    var maxDD = 0.0;
    for (pt in curve.values()) {
      if (pt.value > peak) peak := pt.value;
      if (peak > 0.0) {
        let dd = (peak - pt.value) / peak * 100.0;
        if (dd > maxDD) maxDD := dd;
      };
    };
    maxDD;
  };

  // Compute regime for a window of candles
  func _regimeForWindow(window : [MarketTypes.Candle]) : MarketTypes.MarketCondition {
    if (window.size() == 0) return #Neutral;
    let ind = Indicators.computeAll(window);
    let last = window[window.size() - 1];
    let market : MarketTypes.MarketData = {
      symbol = "";
      price = last.close;
      change24h = 0.0;
      volume24h = last.volume;
      marketCap = 0.0;
      lastUpdated = last.timestamp;
    };
    AIEngine.classifyMarketCondition(ind, market);
  };

  // ---------------------------------------------------------------------------
  // Single agent simulation
  // ---------------------------------------------------------------------------

  public func runArenaSimulation(
    candles        : [MarketTypes.Candle],
    agent          : ArenaTypes.ArenaAgent,
    initialCapital : Float,
  ) : ArenaTypes.ArenaResult {
    var cash = initialCapital;
    let openTrades = List.empty<TradingTypes.Trade>();
    let closedTrades = List.empty<TradingTypes.Trade>();
    let equityCurve = List.empty<{ value : Float }>(); 
    let regimeMap = List.empty<(Int, MarketTypes.MarketCondition)>();

    equityCurve.add({ value = initialCapital });

    let windowSize : Nat = 26;
    let n = candles.size();
    var tradeIdx : Nat = 0;

    var totalHoldTime : Int = 0;

    var i = windowSize;
    while (i < n) {
      let fromIdx : Int = i.toInt() - windowSize.toInt() + 1;
      let window = candles.sliceToArray(fromIdx, i.toInt() + 1);
      let candle = candles[i];
      let ind = Indicators.computeAll(window);
      let market : MarketTypes.MarketData = {
        symbol     = "ARENA";
        price      = candle.close;
        change24h  = 0.0;
        volume24h  = candle.volume;
        marketCap  = 0.0;
        lastUpdated = candle.timestamp;
      };
      let condition = AIEngine.classifyMarketCondition(ind, market);
      regimeMap.add((candle.timestamp, condition));

      // Use agent's strategy focus but allow defensive mode to propagate
      let strategy : TradingTypes.StrategyMode = switch (condition) {
        case (#ManipulationRisk or #LowLiquidityDanger or #HighVolatility) #Defensive;
        case _ agent.strategyFocus;
      };

      // Check stop/target on open position
      switch (openTrades.find(func(t : TradingTypes.Trade) : Bool { t.status == #Open })) {
        case (?openTrade) {
          var shouldClose = false;
          var closeStatus : TradingTypes.TradeStatus = #Closed;
          if (candle.low <= openTrade.stopLoss) {
            shouldClose := true;
            closeStatus := #StopLossHit;
          };
          switch (openTrade.takeProfit) {
            case (?tp) {
              if (candle.high >= tp) { shouldClose := true; closeStatus := #TakeProfitHit };
            };
            case null {};
          };
          if (shouldClose) {
            let exitP = switch (closeStatus) {
              case (#StopLossHit)   openTrade.stopLoss;
              case (#TakeProfitHit) switch (openTrade.takeProfit) { case (?tp) tp; case null candle.close };
              case _                candle.close;
            };
            let slip = slippage(exitP, candle.timestamp);
            let effectiveExit = exitP - slip;
            let pnl = (effectiveExit - openTrade.entryPrice) * openTrade.quantity;
            let pnlPct = if (openTrade.entryPrice > 0.0)
              (effectiveExit - openTrade.entryPrice) / openTrade.entryPrice * 100.0 else 0.0;
            let tradeValue = openTrade.entryPrice * openTrade.quantity;
            cash += tradeValue + pnl - fee(tradeValue);
            totalHoldTime += candle.timestamp - openTrade.openTime;
            let closed : TradingTypes.Trade = {
              openTrade with
              exitPrice  = ?effectiveExit;
              closeTime  = candle.timestamp;
              status     = closeStatus;
              pnl        = ?pnl;
              pnlPercent = ?pnlPct;
            };
            // Replace in openTrades
            openTrades.mapInPlace(func(t : TradingTypes.Trade) : TradingTypes.Trade {
              if (t.id == openTrade.id) closed else t;
            });
            closedTrades.add(closed);
          };
        };
        case null {};
      };

      // Maybe open a new position
      let hasOpen = openTrades.any(func(t : TradingTypes.Trade) : Bool { t.status == #Open });
      if (not hasOpen and strategy != #Defensive and not AIEngine.shouldSkipTrading(condition, 0.0)) {
        let did = agent.agentId # "-d" # tradeIdx.toText();
        let decision = AIEngine.generateDecision(
          "ARENA", window, market, condition, strategy, did, candle.timestamp,
        );
        let confidenceThreshold : Float = 50.0;
        if (decision.action == #Buy and decision.confidence > confidenceThreshold and cash > 0.0) {
          let baseSize = agent.riskMultiplier * 0.02; // base 2% * multiplier
          let positionValue = cash * baseSize;
          let slip = slippage(candle.close, candle.timestamp);
          let effectiveEntry = candle.close + slip;
          let qty = if (effectiveEntry > 0.0) positionValue / effectiveEntry else 0.0;
          if (qty > 0.0) {
            cash -= positionValue + fee(positionValue);
            let tid = agent.agentId # "-t" # tradeIdx.toText();
            tradeIdx += 1;
            // trade counted via closedTrades.size()
            openTrades.add({
              id         = tid;
              symbol     = "ARENA";
              action     = #Buy;
              entryPrice = effectiveEntry;
              exitPrice  = null;
              quantity   = qty;
              status     = #Open;
              openTime   = candle.timestamp;
              closeTime  = 0;
              pnl        = null;
              pnlPercent = null;
              decisionId = did;
              stopLoss   = decision.stopLoss;
              takeProfit = decision.targetPrice;
            });
          };
        };
      };

      equityCurve.add({ value = cash });
      i += 1;
    };

    // Force-close remaining open trades at last candle
    if (n > 0) {
      let lc = candles[n - 1];
      openTrades.mapInPlace(func(t : TradingTypes.Trade) : TradingTypes.Trade {
        if (t.status == #Open) {
          let slip = slippage(lc.close, lc.timestamp);
          let exitP = lc.close - slip;
          let pnl = (exitP - t.entryPrice) * t.quantity;
          let pnlPct = if (t.entryPrice > 0.0) (exitP - t.entryPrice) / t.entryPrice * 100.0 else 0.0;
          let tradeValue = t.entryPrice * t.quantity;
          cash += tradeValue + pnl - fee(tradeValue);
          totalHoldTime += lc.timestamp - t.openTime;
          let closed : TradingTypes.Trade = {
            t with
            exitPrice  = ?exitP;
            closeTime  = lc.timestamp;
            status     = #Closed;
            pnl        = ?pnl;
            pnlPercent = ?pnlPct;
          };
          closedTrades.add(closed);
          closed;
        } else t;
      });
    };

    let allClosed = closedTrades.toArray();
    let totalClosedCount = allClosed.size();
    var wins : Nat = 0;
    for (t in allClosed.values()) {
      switch (t.pnl) { case (?p) { if (p > 0.0) wins += 1 }; case null {} };
    };
    let winRate = if (totalClosedCount > 0) wins.toFloat() / totalClosedCount.toFloat() * 100.0 else 0.0;
    let avgHold = if (totalClosedCount > 0) totalHoldTime / totalClosedCount.toInt() else 0;

    let curve = equityCurve.toArray();
    let sharpe = computeSharpe(curve);
    let maxDD  = computeMaxDrawdown(curve);

    let finalBalance   = cash;
    let totalReturnPct = if (initialCapital > 0.0) (finalBalance - initialCapital) / initialCapital * 100.0 else 0.0;

    // Performance by regime
    let regimeArr = regimeMap.toArray();
    let regimeBreakdowns = computeRegimeBreakdowns(allClosed, regimeArr);

    {
      agentId             = agent.agentId;
      finalBalance;
      totalReturnPct;
      sharpeRatio         = sharpe;
      maxDrawdownPct      = maxDD;
      winRate;
      tradeCount          = totalClosedCount;
      avgHoldTime         = avgHold;
      performanceByRegime = regimeBreakdowns;
    };
  };

  // ---------------------------------------------------------------------------
  // Regime breakdown computation
  // ---------------------------------------------------------------------------

  func computeRegimeBreakdowns(
    trades   : [TradingTypes.Trade],
    regimes  : [(Int, MarketTypes.MarketCondition)],
  ) : [ArenaTypes.RegimeBreakdown] {
    // For each trade find the closest regime timestamp
    let regimeList = List.empty<(MarketTypes.MarketCondition, Float, Bool)>();
    for (t in trades.values()) {
      switch (findNearestRegime(regimes, t.openTime)) {
        case (?regime) {
          let pnl = switch (t.pnl) { case (?p) p; case null 0.0 };
          let won = pnl > 0.0;
          regimeList.add((regime, pnl, won));
        };
        case null {};
      };
    };

    // Aggregate by regime
    let allRegimes : [MarketTypes.MarketCondition] = [
      #StrongBullish, #Bullish, #Neutral, #Ranging,
      #WeakBearish, #StrongBearish, #HighVolatility,
      #ManipulationRisk, #LowLiquidityDanger,
    ];

    allRegimes.filterMap(func(r : MarketTypes.MarketCondition) : ?ArenaTypes.RegimeBreakdown {
      let matching = regimeList.filter(func(item : (MarketTypes.MarketCondition, Float, Bool)) : Bool {
        regimeEqual(item.0, r)
      });
      let mc = matching.size();
      if (mc == 0) return null;
      let totalPnl = matching.foldLeft(0.0, func(acc : Float, item : (MarketTypes.MarketCondition, Float, Bool)) : Float { acc + item.1 });
      var wins : Nat = 0;
      matching.forEach(func(item : (MarketTypes.MarketCondition, Float, Bool)) { if (item.2) wins += 1 });
      let winRate = if (mc > 0) wins.toFloat() / mc.toFloat() * 100.0 else 0.0;
      ?{
        regime     = r;
        returnPct  = totalPnl;
        winRate;
      };
    });
  };

  func findNearestRegime(
    regimes : [(Int, MarketTypes.MarketCondition)],
    ts      : Int,
  ) : ?MarketTypes.MarketCondition {
    var best : ?(Int, MarketTypes.MarketCondition) = null;
    var bestDist : Int = 9_999_999_999_999_999_999;
    for ((t, r) in regimes.values()) {
      let dist = if (ts >= t) ts - t else t - ts;
      if (dist < bestDist) {
        bestDist := dist;
        best := ?(t, r);
      };
    };
    switch (best) { case (?(_, r)) ?r; case null null };
  };

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

  // ---------------------------------------------------------------------------
  // Run full arena: all 6 agents through identical candles
  // ---------------------------------------------------------------------------

  public func runArena(
    sessionId      : Text,
    startDate      : Text,
    endDate        : Text,
    symbol         : Text,
    candles        : [MarketTypes.Candle],
    initialCapital : Float,
    now            : Int,
  ) : ArenaTypes.ArenaSession {
    let results = allAgents.map(func(agent : ArenaTypes.ArenaAgent) : ArenaTypes.ArenaResult {
      runArenaSimulation(candles, agent, initialCapital);
    });
    {
      sessionId;
      startDate;
      endDate;
      symbol;
      initialCapital;
      results;
      completedAt = now;
    };
  };
};

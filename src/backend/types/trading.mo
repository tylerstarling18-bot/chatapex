// Trading domain types
module {
  public type StrategyMode = {
    #TrendFollowing;
    #MeanReversion;
    #Scalping;
    #Defensive;
    #Observation;
  };

  public type TradeAction = {
    #Buy;
    #Sell;
    #Hold;
    #Skip;
  };

  public type TradeStatus = {
    #Open;
    #Closed;
    #StopLossHit;
    #TakeProfitHit;
    #Cancelled;
  };

  public type TradeDecision = {
    id : Text;
    symbol : Text;
    action : TradeAction;
    confidence : Float;
    entryPrice : Float;
    targetPrice : ?Float;
    stopLoss : Float;
    riskReward : Float;
    reasoning : Text;
    indicators : {
      rsi : Float;
      macd : Float;
      macdSignal : Float;
      bollingerUpper : Float;
      bollingerMid : Float;
      bollingerLower : Float;
      ema20 : Float;
      ema50 : Float;
      atr : Float;
      momentum : Float;
      trendStrength : Float;
    };
    marketCondition : {
      #StrongBullish;
      #Bullish;
      #Neutral;
      #Ranging;
      #WeakBearish;
      #StrongBearish;
      #HighVolatility;
      #ManipulationRisk;
      #LowLiquidityDanger;
    };
    timestamp : Int;
    strategyMode : StrategyMode;
  };

  public type Trade = {
    id : Text;
    symbol : Text;
    action : TradeAction;
    entryPrice : Float;
    exitPrice : ?Float;
    quantity : Float;
    status : TradeStatus;
    openTime : Int;
    closeTime : Int;
    pnl : ?Float;
    pnlPercent : ?Float;
    decisionId : Text;
    stopLoss : Float;
    takeProfit : ?Float;
  };

  public type Position = {
    symbol : Text;
    quantity : Float;
    averageEntryPrice : Float;
    currentPrice : Float;
    unrealizedPnl : Float;
    unrealizedPnlPercent : Float;
    openTime : Int;
    stopLoss : Float;
    takeProfit : ?Float;
  };

  public type Portfolio = {
    totalValue : Float;
    cashBalance : Float;
    investedValue : Float;
    totalPnl : Float;
    totalPnlPercent : Float;
    dayPnl : Float;
    dayPnlPercent : Float;
    winRate : Float;
    totalTrades : Nat;
    winningTrades : Nat;
    positions : [Position];
  };

  public type AIDecisionLog = {
    decision : TradeDecision;
    executionStatus : {
      #Pending;
      #Executed;
      #Skipped;
      #Failed;
    };
    executedTradeId : ?Text;
    skipReason : ?Text;
    confidenceFactors : {
      trendAlignment : Float;
      momentum : Float;
      volatilityQuality : Float;
      liquidity : Float;
      historicalSetupPerformance : Float;
      marketStructure : Float;
      regimeConfidence : Float;
      total : Float;
    };
    multiTimeframeSignals : [{
      timeframe : Text;
      trend : { #Bullish; #Bearish; #Neutral };
      strength : Float;
      rsi : Float;
      macdSignal : { #Bullish; #Bearish; #Cross };
      emaAlignment : Bool;
    }];
    // --- enriched fields ---
    decisionCycleId : Nat;
    marketSnapshot : {
      price         : Float;
      volume24h     : Float;
      volatilityPct : Float;
      btcDominance  : Float;
    };
    indicatorValues : {
      rsi              : Float;
      macd             : Float;
      ema20            : Float;
      ema50            : Float;
      atr              : Float;
      bollingerBandwidth : Float;
    };
    alternativesConsidered : [(Text, Float)];  // (label, confidence)
    noTradeReason : ?Text;
    executionDetails : ?{
      slippagePct       : Float;
      feePct            : Float;
      spreadPct         : Float;
      executionDelayMs  : Nat;
    };
  };

  public type StrategyPerformance = {
    strategyMode : StrategyMode;
    totalTrades : Nat;
    wins : Nat;
    losses : Nat;
    winRate : Float;
    totalPnl : Float;
    avgConfidence : Float;
    lastUpdated : Int;
  };
};

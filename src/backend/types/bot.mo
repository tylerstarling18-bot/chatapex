// Bot lifecycle and state types
module {

  public type TradingMode = {
    #Autonomous;
    #SignalOnly;
    #Manual;
  };

  public type SimulationFidelity = {
    slippagePct    : Float;  // base slippage percent (e.g. 0.0005)
    feeMakerPct    : Float;  // maker fee percent
    feeTakerPct    : Float;  // taker fee percent
    spreadPct      : Float;  // half-spread percent
  };

  // (profitPct, closeFraction) — e.g. (0.02, 0.25) = close 25% at +2%
  public type PartialExitLevel = (Float, Float);

  public type BotConfig = {
    refreshIntervalSecs  : Nat;         // how often frontend polls runMarketCycle
    decisionIntervalSecs : Nat;         // how often frontend polls runDecisionCycle
    tradingMode          : TradingMode;
    volatilityPositionSizing : Bool;
    simulationFidelity   : SimulationFidelity;
    partialExitLevels    : [PartialExitLevel];
    startingBalance      : Float;        // default 10000 USDT
  };

  public type BotStatus = {
    #Running;
    #Paused;
    #Stopped;
    #EmergencyStopped;
  };

  public type BotState = {
    status           : BotStatus;
    startedAt        : ?Nat64;
    lastDecisionAt   : ?Nat64;
    lastDataFetchAt  : ?Nat64;
    uptimeSeconds    : Nat64;
    decisionCycleCount  : Nat;
    tradesExecutedCount : Nat;
    dataFeedHealthy  : Bool;
  };

  // Lightweight item in the live activity feed
  public type ActivityItem = {
    timestamp  : Nat64;
    asset      : Text;
    action     : Text;
    confidence : Float;
    reasoning  : Text;
    executed   : Bool;
  };

  // Stats for the decision cycle
  public type DecisionCycleStats = {
    totalCycles    : Nat;
    tradesThisSession : Nat;
    avgConfidence  : Float;
    noTradeRate    : Float;
    winRate        : Float;
    cyclesPerHour  : Float;
  };

  // Data-feed health status
  public type DataFeedStatus = {
    healthy    : Bool;
    lastFetchAt : ?Nat64;
    assetCount : Nat;
    staleSince : ?Nat64;
  };

  // Simulation cost analytics
  public type SimulationStats = {
    totalSlippageCost : Float;
    totalFeeCost      : Float;
    totalSpreadCost   : Float;
    avgSlippagePct    : Float;
    avgFeePct         : Float;
  };
};

import Float "mo:core/Float";
import Time "mo:core/Time";
import Nat64 "mo:core/Nat64";
import BotTypes "../types/bot";
import TradingTypes "../types/trading";
import MarketTypes "../types/market";
import EquityTypes "../types/equity";
import Int "mo:core/Int";

// Bot lifecycle logic: config defaults, state transitions, equity recording
module {

  // Default config
  public func defaultConfig() : BotTypes.BotConfig {
    {
      refreshIntervalSecs  = 60;
      decisionIntervalSecs = 60;
      tradingMode          = #Autonomous;
      volatilityPositionSizing = true;
      simulationFidelity = {
        slippagePct  = 0.0005;
        feeMakerPct  = 0.0002;
        feeTakerPct  = 0.001;
        spreadPct    = 0.001;
      };
      partialExitLevels = [(0.02, 0.25), (0.05, 0.25)];
      startingBalance   = 10_000.0;
    };
  };

  // Stopped state
  public func stoppedState() : BotTypes.BotState {
    {
      status              = #Stopped;
      startedAt           = null;
      lastDecisionAt      = null;
      lastDataFetchAt     = null;
      uptimeSeconds       = 0;
      decisionCycleCount  = 0;
      tradesExecutedCount = 0;
      dataFeedHealthy     = false;
    };
  };

  // Now as Nat64
  func nowNat64() : Nat64 {
    let t : Int = Time.now();
    if (t < 0) { 0 } else { (Int.abs(t) / 1_000_000_000).toNat64() };
  };

  // Compute uptime seconds given startedAt
  public func computeUptime(startedAt : ?Nat64) : Nat64 {
    switch (startedAt) {
      case null 0;
      case (?s) {
        let now = nowNat64();
        if (now > s) { now - s } else { 0 };
      };
    };
  };

  // Transition to Running
  public func startTransition(state : BotTypes.BotState) : BotTypes.BotState {
    let t = nowNat64();
    { state with
      status          = #Running;
      startedAt       = ?t;
      dataFeedHealthy = false;   // will be set true after first successful fetch
    };
  };

  // Transition to Paused
  public func pauseTransition(state : BotTypes.BotState) : BotTypes.BotState {
    { state with status = #Paused; uptimeSeconds = computeUptime(state.startedAt) };
  };

  // Transition to Running from Paused
  public func resumeTransition(state : BotTypes.BotState) : BotTypes.BotState {
    { state with status = #Running };
  };

  // Transition to EmergencyStopped
  public func emergencyStopTransition(state : BotTypes.BotState) : BotTypes.BotState {
    { state with status = #EmergencyStopped; uptimeSeconds = computeUptime(state.startedAt) };
  };

  // Full reset state
  public func resetTransition() : BotTypes.BotState {
    stoppedState();
  };

  // Build an equity snapshot from current portfolio state
  public func buildEquitySnapshot(
    portfolio   : TradingTypes.Portfolio,
    dailyRealizedPnL : Float,
    startingBalance  : Float,
  ) : EquityTypes.EquitySnapshot {
    let now = nowNat64();
    let totalPnLPct = if (startingBalance > 0.0) {
      (portfolio.totalPnl / startingBalance) * 100.0;
    } else 0.0;
    {
      timestamp        = now;
      equity           = portfolio.totalValue;
      cash             = portfolio.cashBalance;
      positionValue    = portfolio.investedValue;
      unrealizedPnL    = portfolio.totalValue - portfolio.cashBalance - portfolio.investedValue;
      realizedPnLToday = dailyRealizedPnL;
      dailyPnLPct      = portfolio.dayPnlPercent;
      totalPnLPct;
    };
  };

  // Build a ConfidencePoint from decision data
  public func buildConfidencePoint(
    asset      : Text,
    confidence : Float,
    action     : TradingTypes.TradeAction,
    condition  : MarketTypes.MarketCondition,
  ) : EquityTypes.ConfidencePoint {
    let now = nowNat64();
    let actionText = switch (action) {
      case (#Buy)  "BUY";
      case (#Sell) "SELL";
      case (#Hold) "HOLD";
      case (#Skip) "SKIP";
    };
    let regimeText = switch (condition) {
      case (#StrongBullish)     "StrongBullish";
      case (#Bullish)           "Bullish";
      case (#Neutral)           "Neutral";
      case (#Ranging)           "Ranging";
      case (#WeakBearish)       "WeakBearish";
      case (#StrongBearish)     "StrongBearish";
      case (#HighVolatility)    "HighVolatility";
      case (#ManipulationRisk)  "ManipulationRisk";
      case (#LowLiquidityDanger) "LowLiquidityDanger";
    };
    { timestamp = now; asset; confidence; action = actionText; regime = regimeText };
  };

  // Validate config values
  public func validateConfig(cfg : BotTypes.BotConfig) : ?Text {
    if (cfg.startingBalance <= 0.0) return ?"startingBalance must be positive";
    if (cfg.refreshIntervalSecs == 0) return ?"refreshIntervalSecs must be > 0";
    if (cfg.decisionIntervalSecs == 0) return ?"decisionIntervalSecs must be > 0";
    if (cfg.simulationFidelity.slippagePct < 0.0 or cfg.simulationFidelity.slippagePct > 0.1)
      return ?"slippagePct out of range [0, 0.1]";
    null;
  };

  // Check if data feed is stale (> 120 seconds since last fetch)
  public func isDataStale(lastFetchAt : ?Nat64) : Bool {
    switch (lastFetchAt) {
      case null true;
      case (?t) {
        let now = nowNat64();
        now > t + 120;
      };
    };
  };

  // Compute simulation stats from trade list
  public func computeSimulationStats(
    totalSlippage : Float,
    totalFees     : Float,
    totalSpread   : Float,
    tradeCount    : Nat,
  ) : BotTypes.SimulationStats {
    let n = if (tradeCount > 0) tradeCount.toFloat() else 1.0;
    {
      totalSlippageCost = totalSlippage;
      totalFeeCost      = totalFees;
      totalSpreadCost   = totalSpread;
      avgSlippagePct    = totalSlippage / n;
      avgFeePct         = totalFees / n;
    };
  };

};

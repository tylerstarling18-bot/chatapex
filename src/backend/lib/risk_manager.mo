import List "mo:core/List";
import TradingTypes "../types/trading";
import RiskTypes "../types/risk";
import Nat "mo:core/Nat";
import Float "mo:core/Float";

// Risk evaluation and enforcement logic
module {

  // Check if a proposed trade violates any risk settings
  // Returns an error message if blocked, null if the trade is allowed
  public func validateTrade(
    settings : RiskTypes.RiskSettings,
    portfolio : TradingTypes.Portfolio,
    decision : TradingTypes.TradeDecision,
    dailyLossPercent : Float,
    consecutiveLosses : Nat,
  ) : ?Text {
    // Block: emergency stop is manually engaged
    if (settings.emergencyStopEnabled) {
      return ?("Emergency stop is active. Trading is halted.");
    };
    // Block: daily loss limit reached
    if (dailyLossPercent >= settings.maxDailyLossPercent) {
      return ?("Daily loss limit of " # settings.maxDailyLossPercent.toText() # "% has been reached.");
    };
    // Block: too many consecutive losses
    if (consecutiveLosses >= settings.maxConsecutiveLosses) {
      return ?("Auto-paused after " # consecutiveLosses.toText() # " consecutive losses.");
    };
    // Block: low confidence in conservative mode
    if (settings.conservativeMode and decision.confidence < 50.0) {
      return ?("Conservative mode: confidence " # decision.confidence.toText() # "% is below 50% threshold.");
    };
    // Block: dangerous market conditions
    switch (decision.marketCondition) {
      case (#ManipulationRisk) {
        return ?("Trade blocked: manipulation risk detected in market conditions.");
      };
      case (#LowLiquidityDanger) {
        return ?("Trade blocked: low liquidity danger detected.");
      };
      case (_) {};
    };
    // Block: symbol already has open position (correlated exposure check)
    let hasOpenPosition = portfolio.positions.any(
      func(p : TradingTypes.Position) : Bool { p.symbol == decision.symbol }
    );
    if (hasOpenPosition) {
      return ?("Already have an open position in " # decision.symbol # ". Avoid correlated exposure.");
    };
    null;
  };

  // Compute current overall risk score 0-100 (higher = more danger)
  public func computeRiskScore(
    portfolio : TradingTypes.Portfolio,
    settings : RiskTypes.RiskSettings,
    dailyLossPercent : Float,
    consecutiveLosses : Nat,
    marketVolatility : Float,
  ) : Float {
    // Component weights: dailyLoss 30%, consecutive losses 25%, concentration 20%, volatility 25%
    let dailyLossScore = if (settings.maxDailyLossPercent > 0.0) {
      Float.min(1.0, dailyLossPercent / settings.maxDailyLossPercent) * 30.0;
    } else { 0.0 };

    let maxLosses = settings.maxConsecutiveLosses.toFloat();
    let consLossScore = if (maxLosses > 0.0) {
      Float.min(1.0, consecutiveLosses.toFloat() / maxLosses) * 25.0;
    } else { 0.0 };

    // Concentration: positions count vs. a 5-position healthy max
    let posCount = portfolio.positions.size().toFloat();
    let concentrationScore = Float.min(1.0, posCount / 5.0) * 20.0;

    // Volatility: normalize to 0-100% of a 10% volatility ceiling
    let volatilityScore = Float.min(1.0, marketVolatility / 10.0) * 25.0;

    Float.min(100.0, dailyLossScore + consLossScore + concentrationScore + volatilityScore);
  };

  // Check if daily loss limit has been breached
  public func isDailyLossLimitBreached(
    settings : RiskTypes.RiskSettings,
    dailyLossPercent : Float,
  ) : Bool {
    dailyLossPercent >= settings.maxDailyLossPercent;
  };

  // Check if consecutive loss limit has been breached
  public func isConsecutiveLossLimitBreached(
    settings : RiskTypes.RiskSettings,
    consecutiveLosses : Nat,
  ) : Bool {
    consecutiveLosses >= settings.maxConsecutiveLosses;
  };

  // Build a new risk event record
  public func buildRiskEvent(
    eventType : RiskTypes.RiskEventType,
    message : Text,
    severity : RiskTypes.RiskSeverity,
    eventId : Text,
    now : Int,
  ) : RiskTypes.RiskEvent {
    { id = eventId; eventType; message; timestamp = now; severity };
  };

  // Compute position size in units respecting max position % rule
  public func computePositionSize(
    portfolioValue : Float,
    entryPrice : Float,
    maxPositionPercent : Float,
  ) : Float {
    if (entryPrice <= 0.0) { return 0.0 };
    (portfolioValue * maxPositionPercent / 100.0) / entryPrice;
  };
};

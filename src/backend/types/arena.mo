// Strategy competition arena types
import MarketTypes "market";
import TradingTypes "trading";

module {

  // Definition of a competing AI agent
  public type ArenaAgent = {
    agentId : Text;
    name : Text;
    description : Text;
    riskMultiplier : Float;
    preferredTimeframe : Text;
    strategyFocus : TradingTypes.StrategyMode;
  };

  // Per-regime breakdown inside an arena result
  public type RegimeBreakdown = {
    regime : MarketTypes.MarketCondition;
    returnPct : Float;
    winRate : Float;
  };

  // Final result for one agent after an arena run
  public type ArenaResult = {
    agentId : Text;
    finalBalance : Float;
    totalReturnPct : Float;
    sharpeRatio : Float;
    maxDrawdownPct : Float;
    winRate : Float;
    tradeCount : Nat;
    avgHoldTime : Int;
    performanceByRegime : [RegimeBreakdown];
  };

  // Full arena session record
  public type ArenaSession = {
    sessionId : Text;
    startDate : Text;
    endDate : Text;
    symbol : Text;
    initialCapital : Float;
    results : [ArenaResult];
    completedAt : Int;
  };
};

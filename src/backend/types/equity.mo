// Equity curve and confidence timeline types
module {

  public type EquitySnapshot = {
    timestamp        : Nat64;
    equity           : Float;
    cash             : Float;
    positionValue    : Float;
    unrealizedPnL    : Float;
    realizedPnLToday : Float;
    dailyPnLPct      : Float;
    totalPnLPct      : Float;
  };

  public type ConfidencePoint = {
    timestamp  : Nat64;
    asset      : Text;
    confidence : Float;
    action     : Text;  // "BUY" | "SELL" | "HOLD" | "SKIP"
    regime     : Text;  // text repr of MarketCondition
  };
};

// Confidence and trade quality types
import MarketTypes "market";
import CommonTypes "common";
import TradingTypes "trading";

module {

  // Decomposed confidence score factors (each 0-100)
  public type ConfidenceFactors = {
    trendAlignment : Float;
    momentum : Float;
    volatilityQuality : Float;
    liquidity : Float;
    historicalSetupPerformance : Float;
    marketStructure : Float;
    regimeConfidence : Float;
    total : Float;
  };

  // Reason the AI decided NOT to enter a trade
  public type NoTradeReason = {
    #LowConfidence;
    #RegimeMismatch;
    #ExistingPosition;
    #OvertradingFlag;
    #VolatilityTooHigh;
    #LiquidityTooLow;
    #DrawdownProtection;
    #CorrelationLimit;
  };

  // Record of a skipped trade opportunity
  public type NoTradeDecision = {
    symbol : CommonTypes.Symbol;
    timestamp : CommonTypes.Timestamp;
    reason : NoTradeReason;
    confidenceAtTime : Float;
    thresholdAtTime : Float;
    marketRegime : MarketTypes.MarketCondition;
  };

  // Tags labelling the quality/outcome of a trade
  public type TradeTag = {
    #TextbookWin;
    #TightStop;
    #GoodDiscipline;
    #PrematureExit;
    #GoodScaling;
    #OvertradeLoss;
    #RegimeMismatch;
  };

  // Snapshot of conditions at trade entry + realistic cost model
  public type TradeSnapshot = {
    tradeId : CommonTypes.TradeId;
    confidenceFactors : ConfidenceFactors;
    marketRegimeAtEntry : MarketTypes.MarketCondition;
    volatilityRatio : Float;
    indicatorsAtEntry : MarketTypes.TechnicalIndicators;
    aiReasoningText : Text;
    simulatedSlippage : Float;
    simulatedSpread : Float;
    simulatedFees : Float;
    simulatedLatencyMs : Nat;
    netImpactPct : Float;
    tags : [TradeTag];
  };
};

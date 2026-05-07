// AI training domain types
import AnalyticsTypes "analytics";
import ConfidenceTypes "confidence";

module {
  public type AITrainingState = {
    // ── existing fields (preserved) ──────────────────────────────────────────
    totalSessions : Nat;
    practiceTradesCount : Nat;
    overallWinRate : Float;
    avgConfidenceScore : Float;
    strategyPerformances : [{
      strategyMode : {
        #TrendFollowing;
        #MeanReversion;
        #Scalping;
        #Defensive;
        #Observation;
      };
      totalTrades : Nat;
      wins : Nat;
      losses : Nat;
      winRate : Float;
      totalPnl : Float;
      avgConfidence : Float;
      lastUpdated : Int;
    }];
    lastTrainingUpdate : Int;
    confidenceCalibration : Float;
    learningProgress : Float;
    // ── new fields ────────────────────────────────────────────────────────────
    marketMemory : [AnalyticsTypes.StrategyPerformanceByRegime];
    noTradeLog : [ConfidenceTypes.NoTradeDecision]; // max 500 entries, managed by lib
    correlationData : [AnalyticsTypes.CorrelationData];
    confidenceThreshold : Float;
    overtradingCount : Nat;
    consecutiveLosses : Nat;
  };
};

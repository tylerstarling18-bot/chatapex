import List "mo:core/List";
import Time "mo:core/Time";
import AccessControl "mo:caffeineai-authorization/access-control";
import TrainingTypes "../types/training";
import TradingTypes "../types/trading";
import TrainingLib "../lib/training";
import AnalyticsTypes "../types/analytics";

mixin (
  accessControlState : AccessControl.AccessControlState,
  trainingState : { var value : TrainingTypes.AITrainingState },
  strategyPerformances : List.List<TradingTypes.StrategyPerformance>,
) {
  // Return current AI training state and learning metrics
  public query ({ caller }) func getAITrainingState() : async TrainingTypes.AITrainingState {
    trainingState.value;
  };

  // Return per-strategy performance stats
  public query ({ caller }) func getStrategyPerformances() : async [TradingTypes.StrategyPerformance] {
    strategyPerformances.toArray();
  };

  // Reset all AI training data and metrics to defaults
  public shared ({ caller }) func resetTrainingData() : async Bool {
    let now = Time.now();
    trainingState.value := TrainingLib.resetState(now);
    strategyPerformances.clear();
    true;
  };

  // Return market memory (strategy performance by regime)
  public query ({ caller }) func getMarketMemory() : async [AnalyticsTypes.StrategyPerformanceByRegime] {
    trainingState.value.marketMemory;
  };

  // Return the top setups per regime
  public query ({ caller }) func getTopSetups() : async [AnalyticsTypes.StrategyPerformanceByRegime] {
    trainingState.value.marketMemory;
  };

  // Called internally by the paper trading system when a trade closes.
  // Updates the training state with the new outcome.
  public func applyTradeToTraining(
    trade : TradingTypes.Trade,
    decision : TradingTypes.TradeDecision,
  ) : () {
    let now = Time.now();
    let newState = TrainingLib.updateFromTrade(trainingState.value, trade, decision, now);
    trainingState.value := newState;

    // Sync strategy performances list
    let newPerfs = TrainingLib.updateStrategyPerformance(
      strategyPerformances.toArray(),
      trade,
      decision,
      now,
    );
    strategyPerformances.clear();
    for (sp in newPerfs.values()) {
      strategyPerformances.add(sp);
    };
  };
};

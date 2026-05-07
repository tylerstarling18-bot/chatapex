// Analytics and performance breakdown types
import MarketTypes "market";
import TradingTypes "trading";

module {

  // Strategy performance broken down by market regime
  public type StrategyPerformanceByRegime = {
    strategyMode : TradingTypes.StrategyMode;
    marketCondition : MarketTypes.MarketCondition;
    winCount : Nat;
    lossCount : Nat;
    totalPnl : Float;
    avgPnl : Float;
    avgHoldTimeSeconds : Int;
  };

  // BTC correlation for an asset
  public type CorrelationData = {
    symbol : Text;
    btcCorrelation : Float;
    lastUpdated : Int;
  };
};

// Market data domain types
module {
  public type MarketData = {
    symbol : Text;
    price : Float;
    change24h : Float;
    volume24h : Float;
    marketCap : Float;
    lastUpdated : Int;
  };

  public type Candle = {
    open : Float;
    high : Float;
    low : Float;
    close : Float;
    volume : Float;
    timestamp : Int;
  };

  public type MarketCondition = {
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

  public type TechnicalIndicators = {
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

  public type MarketSnapshot = {
    timestamp : Int;
    markets : [MarketData];
    totalMarketCap : Float;
    btcDominance : Float;
    fearGreedIndex : ?Float;
  };
};

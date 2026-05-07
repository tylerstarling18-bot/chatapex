// Multi-timeframe analysis types
import Types "market";

module {

  // Per-timeframe data bundle for a single symbol
  public type TimeframeData = {
    candles : [Types.Candle];
    indicators : Types.TechnicalIndicators;
    lastFetched : Int;
  };

  // Full multi-timeframe snapshot for a symbol
  public type MultiTimeframeData = {
    symbol : Text;
    tf1m : TimeframeData;
    tf5m : TimeframeData;
    tf15m : TimeframeData;
    tf1h : TimeframeData;
    tf4h : TimeframeData;
    tf1d : TimeframeData;
    lastFetched : Int;
  };

  // MACD signal direction for a single timeframe
  public type MacdDirection = {
    #Bullish;
    #Bearish;
    #Cross;
  };

  // Trend direction for a single timeframe
  public type TrendDirection = {
    #Bullish;
    #Bearish;
    #Neutral;
  };

  // Directional bias (medium/long term)
  public type DirectionBias = {
    #Up;
    #Down;
    #Sideways;
  };

  // Signal summary for one timeframe
  public type TimeframeSignal = {
    timeframe : Text;
    trend : TrendDirection;
    strength : Float;
    rsi : Float;
    macdSignal : MacdDirection;
    emaAlignment : Bool;
  };

  // Composite multi-timeframe analysis result
  public type MultiTimeframeAnalysis = {
    symbol : Text;
    shortTermMomentum : Float; // 0.0 - 1.0
    mediumTermTrend : DirectionBias;
    longTermDirection : DirectionBias;
    alignmentScore : Float; // 0.0 - 1.0
    signals : [TimeframeSignal];
    timestamp : Int;
  };
};

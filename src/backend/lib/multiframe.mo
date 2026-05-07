import Float "mo:core/Float";
import MarketTypes "../types/market";
import MultiframeTypes "../types/multiframe";
import Indicators "indicators";

// Multi-timeframe market analysis
module {

  // Build TimeframeData from candles
  func buildTimeframeData(candles : [MarketTypes.Candle], now : Int) : MultiframeTypes.TimeframeData {
    {
      candles;
      indicators = Indicators.computeAll(candles);
      lastFetched = now;
    };
  };

  // Determine trend direction from indicators
  func trendDirection(ind : MarketTypes.TechnicalIndicators) : MultiframeTypes.TrendDirection {
    if (ind.ema20 > ind.ema50 and ind.macd > ind.macdSignal) #Bullish
    else if (ind.ema20 < ind.ema50 and ind.macd < ind.macdSignal) #Bearish
    else #Neutral;
  };

  // Determine MACD signal direction
  func macdDir(ind : MarketTypes.TechnicalIndicators) : MultiframeTypes.MacdDirection {
    if (ind.macd > ind.macdSignal and ind.macd > 0.0) #Bullish
    else if (ind.macd < ind.macdSignal and ind.macd < 0.0) #Bearish
    else #Cross;
  };

  // Determine direction bias from higher timeframe indicators
  func directionBias(ind : MarketTypes.TechnicalIndicators) : MultiframeTypes.DirectionBias {
    if (ind.ema20 > ind.ema50 and ind.trendStrength > 40.0) #Up
    else if (ind.ema20 < ind.ema50 and ind.trendStrength > 40.0) #Down
    else #Sideways;
  };

  // Build signal for a single timeframe
  func buildSignal(timeframeName : Text, ind : MarketTypes.TechnicalIndicators) : MultiframeTypes.TimeframeSignal {
    {
      timeframe    = timeframeName;
      trend        = trendDirection(ind);
      strength     = ind.trendStrength;
      rsi          = ind.rsi;
      macdSignal   = macdDir(ind);
      emaAlignment = ind.ema20 > ind.ema50;
    };
  };

  // Assemble a MultiTimeframeData snapshot from per-timeframe candle arrays
  public func fetchAndCacheMultiTimeframe(
    symbol : Text,
    candles1m  : [MarketTypes.Candle],
    candles5m  : [MarketTypes.Candle],
    candles15m : [MarketTypes.Candle],
    candles1h  : [MarketTypes.Candle],
    candles4h  : [MarketTypes.Candle],
    candles1d  : [MarketTypes.Candle],
    now : Int,
  ) : MultiframeTypes.MultiTimeframeData {
    {
      symbol;
      tf1m  = buildTimeframeData(candles1m,  now);
      tf5m  = buildTimeframeData(candles5m,  now);
      tf15m = buildTimeframeData(candles15m, now);
      tf1h  = buildTimeframeData(candles1h,  now);
      tf4h  = buildTimeframeData(candles4h,  now);
      tf1d  = buildTimeframeData(candles1d,  now);
      lastFetched = now;
    };
  };

  // Analyze multi-timeframe data into a composite analysis
  public func analyzeMultiTimeframe(
    mtd : MultiframeTypes.MultiTimeframeData,
  ) : MultiframeTypes.MultiTimeframeAnalysis {
    let ind1m  = mtd.tf1m.indicators;
    let ind5m  = mtd.tf5m.indicators;
    let _ind15m = mtd.tf15m.indicators;
    let ind1h  = mtd.tf1h.indicators;
    let ind4h  = mtd.tf4h.indicators;
    let _ind1d  = mtd.tf1d.indicators;

    // Short-term momentum from 1m/5m RSI and MACD direction
    // RSI > 50 = positive momentum, MACD > signal = positive
    let rsiBullish1m = if (ind1m.rsi > 50.0) 1.0 else 0.0;
    let rsiBullish5m = if (ind5m.rsi > 50.0) 1.0 else 0.0;
    let macdBull1m   = if (ind1m.macd > ind1m.macdSignal) 1.0 else 0.0;
    let macdBull5m   = if (ind5m.macd > ind5m.macdSignal) 1.0 else 0.0;
    let shortTermMomentum = (rsiBullish1m + rsiBullish5m + macdBull1m + macdBull5m) / 4.0;

    // Medium term trend from 15m/1h EMA direction
    let mediumTermTrend = directionBias(ind1h);

    // Long term from 4h/1d
    let longTermDirection = directionBias(ind4h);

    // Alignment: count timeframes bullish
    let signals = getTimeframeSignals(mtd);
    var bullishCount : Float = 0.0;
    for (sig in signals.values()) {
      switch (sig.trend) {
        case (#Bullish) { bullishCount += 1.0 };
        case (#Bearish) {};
        case (#Neutral) { bullishCount += 0.5 };
      };
    };
    let total = signals.size();
    let alignmentScore = if (total > 0) {
      let bullishFrac = bullishCount / total.toFloat();
      // Score = max deviation from 50%, mapped to 0-1
      let deviation = Float.abs(bullishFrac - 0.5) * 2.0;
      deviation;
    } else 0.0;

    {
      symbol       = mtd.symbol;
      shortTermMomentum;
      mediumTermTrend;
      longTermDirection;
      alignmentScore;
      signals;
      timestamp    = mtd.lastFetched;
    };
  };

  // Return one TimeframeSignal per timeframe
  public func getTimeframeSignals(
    mtd : MultiframeTypes.MultiTimeframeData,
  ) : [MultiframeTypes.TimeframeSignal] {
    [
      buildSignal("1m",  mtd.tf1m.indicators),
      buildSignal("5m",  mtd.tf5m.indicators),
      buildSignal("15m", mtd.tf15m.indicators),
      buildSignal("1h",  mtd.tf1h.indicators),
      buildSignal("4h",  mtd.tf4h.indicators),
      buildSignal("1d",  mtd.tf1d.indicators),
    ];
  };
};

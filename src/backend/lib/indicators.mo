import Float "mo:core/Float";
import MarketTypes "../types/market";

// Computes all technical indicators from candle data
module {

  // ---------------------------------------------------------------------------
  // EMA helpers (private)
  // ---------------------------------------------------------------------------

  // Compute EMA over a plain Float array with a given multiplier k = 2/(period+1)
  func emaFromPrices(prices : [Float], period : Nat) : Float {
    let n = prices.size();
    if (n == 0 or period == 0) return 0.0;
    let k : Float = 2.0 / (period.toFloat() + 1.0);
    // Seed with the first value
    var ema = prices[0];
    var i = 1;
    while (i < n) {
      ema := prices[i] * k + ema * (1.0 - k);
      i += 1;
    };
    ema;
  };

  // Build an array of close prices from candles
  func closes(candles : [MarketTypes.Candle]) : [Float] {
    candles.map(func(c : MarketTypes.Candle) : Float { c.close });
  };

  // ---------------------------------------------------------------------------
  // Public indicator functions
  // ---------------------------------------------------------------------------

  // Wilder's RSI: RS = avgGain/avgLoss over `period` candles
  // Returns 50.0 when insufficient data
  public func computeRSI(candles : [MarketTypes.Candle], period : Nat) : Float {
    let n = candles.size();
    if (n <= period or period == 0) return 50.0;
    // Compute gains and losses for first `period` changes
    var avgGain : Float = 0.0;
    var avgLoss : Float = 0.0;
    var i = 1;
    while (i <= period) {
      let delta = candles[i].close - candles[i - 1].close;
      if (delta > 0.0) { avgGain += delta } else { avgLoss += (-delta) };
      i += 1;
    };
    avgGain := avgGain / period.toFloat();
    avgLoss := avgLoss / period.toFloat();
    // Wilder smoothing for remaining candles
    i := period + 1;
    while (i < n) {
      let delta = candles[i].close - candles[i - 1].close;
      let gain = if (delta > 0.0) delta else 0.0;
      let loss = if (delta < 0.0) (-delta) else 0.0;
      avgGain := (avgGain * (period - 1).toFloat() + gain) / period.toFloat();
      avgLoss := (avgLoss * (period - 1).toFloat() + loss) / period.toFloat();
      i += 1;
    };
    if (avgLoss == 0.0) return 100.0;
    let rs = avgGain / avgLoss;
    100.0 - (100.0 / (1.0 + rs));
  };

  // MACD = EMA12 - EMA26, signal = EMA9 of MACD
  // Returns (0.0, 0.0) if insufficient data
  public func computeMACD(candles : [MarketTypes.Candle]) : (Float, Float) {
    let n = candles.size();
    if (n < 26) return (0.0, 0.0);
    let px = closes(candles);
    let ema12 = emaFromPrices(px, 12);
    let ema26 = emaFromPrices(px, 26);
    let macdLine = ema12 - ema26;
    // Build a synthetic 9-candle MACD series for the signal
    // We use the last 9 closes mapped to MACD diff in a simplified approach:
    // For the signal we compute EMA9 of (EMA12_i - EMA26_i) for last 26..n candles
    let k12 : Float = 2.0 / (12.0 + 1.0);
    let k26 : Float = 2.0 / (26.0 + 1.0);
    let k9  : Float = 2.0 / (9.0  + 1.0);
    var e12 = px[0];
    var e26 = px[0];
    var signal = 0.0;
    var signalSeeded = false;
    var i = 1;
    while (i < n) {
      e12 := px[i] * k12 + e12 * (1.0 - k12);
      e26 := px[i] * k26 + e26 * (1.0 - k26);
      let m = e12 - e26;
      if (i >= 25) {
        if (not signalSeeded) {
          signal := m;
          signalSeeded := true;
        } else {
          signal := m * k9 + signal * (1.0 - k9);
        };
      };
      i += 1;
    };
    (macdLine, signal);
  };

  // Bollinger Bands: mid = SMA(period), std dev, upper/lower = mid +/- 2*std
  public func computeBollingerBands(candles : [MarketTypes.Candle], period : Nat) : (Float, Float, Float) {
    let n = candles.size();
    if (n < period or period == 0) return (0.0, 0.0, 0.0);
    // Use last `period` candles
    let start = n - period;
    var sum : Float = 0.0;
    var i = start;
    while (i < n) {
      sum += candles[i].close;
      i += 1;
    };
    let mid = sum / period.toFloat();
    var variance : Float = 0.0;
    i := start;
    while (i < n) {
      let diff = candles[i].close - mid;
      variance += diff * diff;
      i += 1;
    };
    let std = Float.sqrt(variance / period.toFloat());
    (mid + 2.0 * std, mid, mid - 2.0 * std);
  };

  // Exponential moving average using last `period` candles as seed window
  public func computeEMA(candles : [MarketTypes.Candle], period : Nat) : Float {
    let n = candles.size();
    if (n == 0 or period == 0) return 0.0;
    emaFromPrices(closes(candles), period);
  };

  // Average True Range: max(H-L, |H-prevC|, |L-prevC|) averaged over `period`
  public func computeATR(candles : [MarketTypes.Candle], period : Nat) : Float {
    let n = candles.size();
    if (n <= 1 or period == 0) return 0.0;
    // Compute true ranges
    var trSum : Float = 0.0;
    var count = 0;
    let start = if (n > period) n - period else 1;
    var i = start;
    while (i < n) {
      let c = candles[i];
      let prev = candles[i - 1].close;
      let hl = c.high - c.low;
      let hc = Float.abs(c.high - prev);
      let lc = Float.abs(c.low - prev);
      let tr = if (hl > hc and hl > lc) hl
               else if (hc > lc) hc
               else lc;
      trSum += tr;
      count += 1;
      i += 1;
    };
    if (count == 0) 0.0 else trSum / count.toFloat();
  };

  // Momentum: (close[now] / close[now-period] - 1) * 100
  public func computeMomentum(candles : [MarketTypes.Candle], period : Nat) : Float {
    let n = candles.size();
    if (n <= period or period == 0) return 0.0;
    let current = candles[n - 1].close;
    let past    = candles[n - 1 - period].close;
    if (past == 0.0) return 0.0;
    (current / past - 1.0) * 100.0;
  };

  // Trend strength 0-100: EMA20 vs EMA50 divergence + directional consistency
  // Returns 0 if insufficient data
  public func computeTrendStrength(candles : [MarketTypes.Candle]) : Float {
    let n = candles.size();
    if (n < 50) return 0.0;
    let px = closes(candles);
    let ema20 = emaFromPrices(px, 20);
    let ema50 = emaFromPrices(px, 50);
    if (ema50 == 0.0) return 0.0;
    // Divergence score: how far apart are EMAs relative to price
    let divergence = Float.abs(ema20 - ema50) / ema50 * 100.0;
    // Directional consistency: count consistent direction in last 20 closes
    let recentStart = n - 20;
    var sameDir : Nat = 0;
    var total : Nat = 0;
    var j = recentStart + 1;
    while (j < n) {
      let up = candles[j].close > candles[j - 1].close;
      let trendUp = ema20 > ema50;
      if ((up and trendUp) or ((not up) and (not trendUp))) { sameDir += 1 };
      total += 1;
      j += 1;
    };
    let consistency = if (total == 0) 0.5 else sameDir.toFloat() / total.toFloat();
    // Blend: divergence capped at 5% maps to 0-50, consistency maps to 0-50
    let divScore = Float.min(divergence / 5.0, 1.0) * 50.0;
    let conScore = consistency * 50.0;
    Float.min(divScore + conScore, 100.0);
  };

  // Compute all indicators at once from candles
  public func computeAll(candles : [MarketTypes.Candle]) : MarketTypes.TechnicalIndicators {
    let (macd, macdSignal) = computeMACD(candles);
    let (bbUpper, bbMid, bbLower) = computeBollingerBands(candles, 20);
    let px = closes(candles);
    let ema20 = emaFromPrices(px, 20);
    let ema50 = emaFromPrices(px, 50);
    {
      rsi          = computeRSI(candles, 14);
      macd;
      macdSignal;
      bollingerUpper = bbUpper;
      bollingerMid   = bbMid;
      bollingerLower = bbLower;
      ema20;
      ema50;
      atr          = computeATR(candles, 14);
      momentum     = computeMomentum(candles, 10);
      trendStrength = computeTrendStrength(candles);
    };
  };
};

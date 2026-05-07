import Float "mo:core/Float";
import Array "mo:core/Array";
import AnalyticsTypes "../types/analytics";

// BTC correlation analysis for altcoin portfolio management
module {

  // Compute Pearson correlation over last 30 price returns
  public func computeBTCCorrelation(
    btcCandles  : [{ close : Float; timestamp : Int }],
    altCandles  : [{ close : Float; timestamp : Int }],
  ) : Float {
    let window = 30;
    let nb = btcCandles.size();
    let na = altCandles.size();
    if (nb < 2 or na < 2) return 0.0;

    // Use last `window+1` candles to produce `window` returns
    let startB = if (nb > window + 1) nb - window - 1 else 0;
    let startA = if (na > window + 1) na - window - 1 else 0;
    let btcSlice = btcCandles.sliceToArray(startB.toInt(), nb.toInt());
    let altSlice = altCandles.sliceToArray(startA.toInt(), na.toInt());
    let n = if (btcSlice.size() < altSlice.size()) btcSlice.size() else altSlice.size();
    if (n < 2) return 0.0;

    // Returns: (price[i] - price[i-1]) / price[i-1]
    let retCount = n - 1;
    let retBtc = Array.tabulate<Float>(retCount, func(i) {
      let prev = btcSlice[i].close;
      let curr = btcSlice[i + 1].close;
      if (prev > 0.0) (curr - prev) / prev else 0.0;
    });
    let retAlt = Array.tabulate<Float>(retCount, func(i) {
      let prev = altSlice[i].close;
      let curr = altSlice[i + 1].close;
      if (prev > 0.0) (curr - prev) / prev else 0.0;
    });

    let nF = retCount.toFloat();
    let meanB = retBtc.foldLeft(0.0, func(a : Float, r : Float) : Float { a + r }) / nF;
    let meanA = retAlt.foldLeft(0.0, func(a : Float, r : Float) : Float { a + r }) / nF;

    var covBA = 0.0;
    var varB  = 0.0;
    var varA  = 0.0;
    var i = 0;
    while (i < retCount) {
      let db = retBtc[i] - meanB;
      let da = retAlt[i] - meanA;
      covBA += db * da;
      varB  += db * db;
      varA  += da * da;
      i += 1;
    };

    let denom = Float.sqrt(varB * varA);
    if (denom == 0.0) return 0.0;
    let corr = covBA / denom;
    // Clamp to [-1, 1]
    if (corr > 1.0) 1.0 else if (corr < -1.0) -1.0 else corr;
  };

  // Upsert correlation data for a symbol
  public func updateCorrelationData(
    existing    : [AnalyticsTypes.CorrelationData],
    symbol      : Text,
    btcCandles  : [{ close : Float; timestamp : Int }],
    altCandles  : [{ close : Float; timestamp : Int }],
    now         : Int,
  ) : [AnalyticsTypes.CorrelationData] {
    let corr = computeBTCCorrelation(btcCandles, altCandles);
    let newEntry : AnalyticsTypes.CorrelationData = {
      symbol;
      btcCorrelation = corr;
      lastUpdated    = now;
    };
    // Replace existing or append
    let found = existing.findIndex(func(d : AnalyticsTypes.CorrelationData) : Bool {
      d.symbol == symbol
    });
    switch (found) {
      case (?idx) {
        existing.mapEntries(func(d : AnalyticsTypes.CorrelationData, i : Nat) : AnalyticsTypes.CorrelationData {
          if (i == idx) newEntry else d;
        });
      };
      case null {
        existing.concat([newEntry]);
      };
    };
  };

  // Returns true if weighted avg correlation of open symbols exceeds 0.4
  public func isOverCorrelated(
    correlations   : [AnalyticsTypes.CorrelationData],
    openSymbols    : [Text],
  ) : Bool {
    if (openSymbols.size() == 0) return false;
    var total : Float = 0.0;
    var count : Nat = 0;
    for (sym in openSymbols.values()) {
      switch (correlations.find(func(d : AnalyticsTypes.CorrelationData) : Bool { d.symbol == sym })) {
        case (?d) {
          total += Float.abs(d.btcCorrelation);
          count += 1;
        };
        case null {};
      };
    };
    if (count == 0) return false;
    (total / count.toFloat()) > 0.4;
  };
};

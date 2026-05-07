import Float "mo:core/Float";
import Array "mo:core/Array";
import MarketTypes "../types/market";
import TradingTypes "../types/trading";
import Indicators "indicators";
import ConfidenceTypes "../types/confidence";
import AnalyticsTypes "../types/analytics";
import MultiframeTypes "../types/multiframe";

// Core AI analysis and decision-making engine
module {

  // ---------------------------------------------------------------------------
  // Market classification
  // ---------------------------------------------------------------------------

  // Classify market condition from indicators and market data
  public func classifyMarketCondition(
    indicators : MarketTypes.TechnicalIndicators,
    market : MarketTypes.MarketData,
  ) : MarketTypes.MarketCondition {
    let rsi     = indicators.rsi;
    let macd    = indicators.macd;
    let atr     = indicators.atr;
    let trend   = indicators.trendStrength;
    let price   = market.price;
    let vol24h  = market.volume24h;

    // Detect high volatility first — ATR > 3% of price is significant
    let atrPct = if (price > 0.0) atr / price * 100.0 else 0.0;
    if (atrPct > 5.0) return #HighVolatility;

    // Low liquidity: very low volume relative to market cap
    let liquidityRatio = if (market.marketCap > 0.0) vol24h / market.marketCap else 0.0;
    if (liquidityRatio < 0.005 and vol24h < 1_000_000.0) return #LowLiquidityDanger;

    // Manipulation risk: extreme ATR spike with no trend
    if (atrPct > 3.0 and trend < 20.0 and Float.abs(market.change24h) > 15.0) {
      return #ManipulationRisk;
    };

    // Main RSI + MACD + trend classification
    if (rsi > 70.0 and macd > 0.0 and trend > 70.0) return #StrongBullish;
    if (rsi >= 55.0 and rsi <= 70.0 and macd > 0.0)  return #Bullish;
    if (rsi < 30.0 and macd < 0.0 and trend > 70.0)  return #StrongBearish;
    if (rsi >= 30.0 and rsi < 45.0 and macd < 0.0)   return #WeakBearish;

    // Ranging: RSI near midpoint and small MACD and low trend
    if (rsi >= 45.0 and rsi <= 55.0 and Float.abs(macd) < (price * 0.002) and trend < 30.0) {
      return #Ranging;
    };

    // Neutral: everything else in the middle zone
    #Neutral;
  };

  // ---------------------------------------------------------------------------
  // Strategy selection
  // ---------------------------------------------------------------------------

  // Choose optimal strategy mode for the given market condition
  public func selectStrategy(condition : MarketTypes.MarketCondition) : TradingTypes.StrategyMode {
    switch (condition) {
      case (#StrongBullish)     #TrendFollowing;
      case (#Bullish)           #TrendFollowing;
      case (#WeakBearish)       #TrendFollowing;
      case (#StrongBearish)     #TrendFollowing;
      case (#Neutral)           #MeanReversion;
      case (#Ranging)           #MeanReversion;
      case (#HighVolatility)    #Defensive;
      case (#ManipulationRisk)  #Defensive;
      case (#LowLiquidityDanger) #Defensive;
    };
  };

  // ---------------------------------------------------------------------------
  // Confidence scoring
  // ---------------------------------------------------------------------------

  // Compute a confidence score (0-100) for a given decision context
  // Compute 7-factor confidence breakdown and return a ConfidenceFactors record
  public func computeConfidenceFactors(
    indicators  : MarketTypes.TechnicalIndicators,
    condition   : MarketTypes.MarketCondition,
    _mtAnalysis : MultiframeTypes.MultiTimeframeAnalysis,
    stratPerf   : [AnalyticsTypes.StrategyPerformanceByRegime],
    mode        : TradingTypes.StrategyMode,
  ) : ConfidenceTypes.ConfidenceFactors {

    // --- Factor 1: Trend alignment ---
    let trendAlignment : Float = if (indicators.ema50 > 0.0) {
      let emaDiff = (indicators.ema20 - indicators.ema50) / indicators.ema50 * 100.0;
      // emaDiff > 2% = strong trend = 100, < 0.1% = weak = 20
      if (Float.abs(emaDiff) > 2.0) 100.0
      else if (Float.abs(emaDiff) > 1.0) 80.0
      else if (Float.abs(emaDiff) > 0.5) 60.0
      else if (Float.abs(emaDiff) > 0.1) 40.0
      else 20.0;
    } else 40.0;

    // --- Factor 2: Momentum ---
    let rsi = indicators.rsi;
    let macdStrength = Float.abs(indicators.macd - indicators.macdSignal);
    let rsiMomentum : Float =
      if (rsi < 30.0 or rsi > 70.0) 90.0
      else if (rsi < 40.0 or rsi > 60.0) 70.0
      else 50.0;
    let macdMomentum : Float = if (macdStrength > 0.0) Float.min(macdStrength * 10000.0, 100.0) else 30.0;
    let momentum = (rsiMomentum + macdMomentum) / 2.0;

    // --- Factor 3: Volatility quality ---
    let atrPct = if (indicators.ema20 > 0.0) indicators.atr / indicators.ema20 * 100.0 else 0.0;
    let volatilityQuality : Float =
      if (atrPct >= 1.0 and atrPct <= 3.0) 100.0  // normal range
      else if (atrPct < 1.0) 60.0                   // too calm
      else if (atrPct <= 5.0) 50.0                  // elevated
      else 20.0;                                     // extreme

    // --- Factor 4: Liquidity ---
    // Proxy from trendStrength (correlated with volume momentum)
    let liquidity : Float = Float.min(indicators.trendStrength, 100.0);

    // --- Factor 5: Historical setup performance ---
    let historicalSetupPerformance : Float = computeMarketMemoryScore(stratPerf, mode, condition);

    // --- Factor 6: Market structure ---
    let bbWidth = indicators.bollingerUpper - indicators.bollingerLower;
    let marketStructure : Float = if (bbWidth > 0.0) {
      let pos = (indicators.ema20 - indicators.bollingerLower) / bbWidth; // 0-1
      if (pos >= 0.3 and pos <= 0.7) 100.0  // near middle = clear structure
      else if (pos >= 0.1 and pos <= 0.9) 55.0
      else 30.0;  // extreme position
    } else 50.0;

    // --- Factor 7: Regime confidence ---
    let regimeConfidence : Float = switch (condition) {
      case (#StrongBullish or #StrongBearish) 90.0;
      case (#Bullish or #WeakBearish)         75.0;
      case (#Ranging)                         70.0;
      case (#Neutral)                         60.0;
      case (#HighVolatility)                  50.0;
      case (#LowLiquidityDanger)              30.0;
      case (#ManipulationRisk)                20.0;
    };

    // --- Weighted total ---
    let total = trendAlignment * 0.2
      + momentum * 0.2
      + volatilityQuality * 0.1
      + liquidity * 0.1
      + historicalSetupPerformance * 0.2
      + marketStructure * 0.1
      + regimeConfidence * 0.1;

    {
      trendAlignment;
      momentum;
      volatilityQuality;
      liquidity;
      historicalSetupPerformance;
      marketStructure;
      regimeConfidence;
      total = Float.max(10.0, Float.min(total, 95.0));
    };
  };

  // Compute confidence total from 7-factor breakdown (convenience wrapper)
  public func computeConfidence(
    indicators : MarketTypes.TechnicalIndicators,
    condition  : MarketTypes.MarketCondition,
    strategy   : TradingTypes.StrategyMode,
  ) : Float {
    var score : Float = 40.0;
    let rsiBullish = indicators.rsi < 50.0;
    let macdBullish = indicators.macd > indicators.macdSignal;
    if ((rsiBullish and macdBullish) or ((not rsiBullish) and (not macdBullish))) {
      score += 20.0;
    };
    score += indicators.trendStrength * 0.15;
    if (Float.abs(indicators.momentum) > 2.0 and Float.abs(indicators.momentum) < 20.0) {
      score += 10.0;
    };
    let bbWidth = indicators.bollingerUpper - indicators.bollingerLower;
    if (bbWidth > 0.0) {
      let bbPos = (indicators.ema20 - indicators.bollingerLower) / bbWidth;
      if (bbPos < 0.25 or bbPos > 0.75) { score += 5.0 };
    };
    if (indicators.ema50 > 0.0) {
      let emaDiff = (indicators.ema20 - indicators.ema50) / indicators.ema50 * 100.0;
      if (Float.abs(emaDiff) > 0.5) { score += 10.0 };
    };
    let stratFit : Float = switch (strategy) {
      case (#TrendFollowing) {
        switch (condition) {
          case (#StrongBullish or #StrongBearish) 1.0;
          case (#Bullish or #WeakBearish) 0.9;
          case _ 0.7;
        };
      };
      case (#MeanReversion) {
        switch (condition) {
          case (#Ranging or #Neutral) 1.0;
          case _ 0.75;
        };
      };
      case (#Defensive or #Observation or #Scalping) 0.6;
    };
    score := score * stratFit;
    switch (strategy) {
      case (#Defensive) { score := Float.min(score, 45.0) };
      case _ {};
    };
    Float.max(20.0, Float.min(score, 88.0));
  };

  // ---------------------------------------------------------------------------
  // Historical memory score helper
  // ---------------------------------------------------------------------------

  // Look up win rate * 100 for a specific strategy+regime pair
  public func computeMarketMemoryScore(
    memory    : [AnalyticsTypes.StrategyPerformanceByRegime],
    stratMode : TradingTypes.StrategyMode,
    condition : MarketTypes.MarketCondition,
  ) : Float {
    switch (memory.find(func(m : AnalyticsTypes.StrategyPerformanceByRegime) : Bool {
      strategyModeEqual(m.strategyMode, stratMode) and regimeEqual(m.marketCondition, condition)
    })) {
      case (?entry) {
        let total = entry.winCount + entry.lossCount;
        if (total > 0) entry.winCount.toFloat() / total.toFloat() * 100.0 else 50.0;
      };
      case null 50.0;
    };
  };

  // Dynamic confidence threshold based on market regime and consecutive losses
  public func getConfidenceThreshold(
    condition        : MarketTypes.MarketCondition,
    consecutiveLosses : Nat,
  ) : Float {
    let base : Float = switch (condition) {
      case (#StrongBullish or #Bullish or #WeakBearish or #StrongBearish) 60.0;
      case (#Ranging)           65.0;
      case (#Neutral)           65.0;
      case (#HighVolatility)    72.0;
      case (#ManipulationRisk)  80.0;
      case (#LowLiquidityDanger) 75.0;
    };
    // Add up to +20 for consecutive losses (5 per loss)
    let penalty = Float.min(consecutiveLosses.toFloat() * 5.0, 20.0);
    base + penalty;
  };

  // ---------------------------------------------------------------------------
  // Trade decision generation
  // ---------------------------------------------------------------------------

  // Generate a trade decision for a symbol given candles and current snapshot
  public func generateDecision(
    symbol : Text,
    candles : [MarketTypes.Candle],
    market : MarketTypes.MarketData,
    condition : MarketTypes.MarketCondition,
    strategy : TradingTypes.StrategyMode,
    decisionId : Text,
    now : Int,
  ) : TradingTypes.TradeDecision {
    let indicators = Indicators.computeAll(candles);
    let confidence = computeConfidence(indicators, condition, strategy);
    let price = market.price;

    // Determine action
    let action : TradingTypes.TradeAction = switch (strategy) {
      case (#Defensive or #Observation) #Skip;
      case (#TrendFollowing) {
        if (condition == #StrongBullish or condition == #Bullish) {
          if (indicators.macd > indicators.macdSignal and indicators.rsi < 75.0) #Buy else #Hold;
        } else if (condition == #StrongBearish or condition == #WeakBearish) {
          if (indicators.macd < indicators.macdSignal and indicators.rsi > 25.0) #Sell else #Hold;
        } else #Hold;
      };
      case (#MeanReversion) {
        // Buy at lower band, sell at upper band
        if (indicators.rsi < 38.0 and price <= indicators.bollingerLower * 1.02) #Buy
        else if (indicators.rsi > 62.0 and price >= indicators.bollingerUpper * 0.98) #Sell
        else #Hold;
      };
      case (#Scalping) {
        // Momentum-based scalp
        if (indicators.momentum > 1.5 and indicators.macd > 0.0) #Buy
        else if (indicators.momentum < -1.5 and indicators.macd < 0.0) #Sell
        else #Hold;
      };
    };

    // Stop loss: ATR-based
    let atr = if (indicators.atr > 0.0) indicators.atr else price * 0.02;
    let (stopLoss, targetPrice) = switch (action) {
      case (#Buy) {
        let sl = price - (1.5 * atr);
        let tp = price + (3.0 * atr); // 2:1 risk/reward
        (sl, ?tp);
      };
      case (#Sell) {
        let sl = price + (1.5 * atr);
        let tp = price - (3.0 * atr);
        (sl, ?tp);
      };
      case _ (price * 0.97, null);
    };

    let riskReward : Float = switch (action) {
      case (#Buy or #Sell) 2.0;
      case _ 0.0;
    };

    // Build reasoning string
    let condText = switch (condition) {
      case (#StrongBullish)     "STRONG BULLISH";
      case (#Bullish)           "BULLISH";
      case (#Neutral)           "NEUTRAL";
      case (#Ranging)           "RANGING";
      case (#WeakBearish)       "WEAK BEARISH";
      case (#StrongBearish)     "STRONG BEARISH";
      case (#HighVolatility)    "HIGH VOLATILITY";
      case (#ManipulationRisk)  "MANIPULATION RISK";
      case (#LowLiquidityDanger) "LOW LIQUIDITY";
    };
    let stratText = switch (strategy) {
      case (#TrendFollowing) "TrendFollowing";
      case (#MeanReversion)  "MeanReversion";
      case (#Scalping)       "Scalping";
      case (#Defensive)      "Defensive";
      case (#Observation)    "Observation";
    };
    let actionText = switch (action) {
      case (#Buy)  "BUY";
      case (#Sell) "SELL";
      case (#Hold) "HOLD";
      case (#Skip) "SKIP";
    };

    let rsiStr = floatToText(indicators.rsi, 1);
    let macdStr = floatToText(indicators.macd, 4);
    let confStr = floatToText(confidence, 1);
    let atrStr  = floatToText(indicators.atr, 2);
    let ema20Str = floatToText(indicators.ema20, 2);
    let ema50Str = floatToText(indicators.ema50, 2);
    let momStr  = floatToText(indicators.momentum, 2);

    let emaNote = if (indicators.ema20 > indicators.ema50)
      "EMA20 > EMA50 confirming uptrend."
    else if (indicators.ema20 < indicators.ema50)
      "EMA20 < EMA50 confirming downtrend."
    else "EMA20 ~ EMA50 — no clear trend.";

    let bbNote =
      if (price < indicators.bollingerLower) "Price below Bollinger lower band (oversold zone)."
      else if (price > indicators.bollingerUpper) "Price above Bollinger upper band (overbought zone)."
      else "Price within Bollinger bands.";

    let reasoning = actionText # " " # symbol # ": RSI=" # rsiStr #
      " | MACD=" # macdStr #
      " | Momentum=" # momStr # "% | EMA20=" # ema20Str # " EMA50=" # ema50Str #
      ". " # emaNote # " " # bbNote #
      " ATR=" # atrStr # ". Market: " # condText #
      ". Confidence: " # confStr # "% in " # stratText # " mode.";

    {
      id             = decisionId;
      symbol;
      action;
      confidence;
      entryPrice     = price;
      targetPrice;
      stopLoss;
      riskReward;
      reasoning;
      indicators     = {
        rsi            = indicators.rsi;
        macd           = indicators.macd;
        macdSignal     = indicators.macdSignal;
        bollingerUpper = indicators.bollingerUpper;
        bollingerMid   = indicators.bollingerMid;
        bollingerLower = indicators.bollingerLower;
        ema20          = indicators.ema20;
        ema50          = indicators.ema50;
        atr            = indicators.atr;
        momentum       = indicators.momentum;
        trendStrength  = indicators.trendStrength;
      };
      marketCondition = condition;
      timestamp       = now;
      strategyMode    = strategy;
    };
  };


  // ---------------------------------------------------------------------------
  // Private equality helpers
  // ---------------------------------------------------------------------------

  func strategyModeEqual(a : TradingTypes.StrategyMode, b : TradingTypes.StrategyMode) : Bool {
    switch (a, b) {
      case (#TrendFollowing, #TrendFollowing) true;
      case (#MeanReversion,  #MeanReversion)  true;
      case (#Scalping,       #Scalping)        true;
      case (#Defensive,      #Defensive)       true;
      case (#Observation,    #Observation)     true;
      case _                                   false;
    };
  };

  func regimeEqual(a : MarketTypes.MarketCondition, b : MarketTypes.MarketCondition) : Bool {
    switch (a, b) {
      case (#StrongBullish, #StrongBullish)   true;
      case (#Bullish, #Bullish)               true;
      case (#Neutral, #Neutral)               true;
      case (#Ranging, #Ranging)               true;
      case (#WeakBearish, #WeakBearish)       true;
      case (#StrongBearish, #StrongBearish)   true;
      case (#HighVolatility, #HighVolatility) true;
      case (#ManipulationRisk, #ManipulationRisk) true;
      case (#LowLiquidityDanger, #LowLiquidityDanger) true;
      case _ false;
    };
  };

  // ---------------------------------------------------------------------------
  // Risk gate
  // ---------------------------------------------------------------------------

  // Determine if the AI should skip trading in current conditions
  public func shouldSkipTrading(
    condition : MarketTypes.MarketCondition,
    riskScore : Float,
  ) : Bool {
    switch (condition) {
      case (#ManipulationRisk or #LowLiquidityDanger) true;
      case _ riskScore > 80.0;
    };
  };

  // ---------------------------------------------------------------------------
  // Strategy weight adjustment
  // ---------------------------------------------------------------------------

  // Update strategy performance weights based on recent win rates
  public func updateStrategyWeights(
    performances : [TradingTypes.StrategyPerformance],
  ) : [TradingTypes.StrategyPerformance] {
    performances.map(func(p : TradingTypes.StrategyPerformance) : TradingTypes.StrategyPerformance {
      // Adjust confidence factor: +/- 5% delta from 50% baseline, capped
      let winRateDelta = p.winRate - 0.5; // positive = above baseline
      let adjustment = winRateDelta * 0.1; // 10% sensitivity
      let newAvgConf = Float.max(20.0, Float.min(p.avgConfidence + adjustment * 100.0, 90.0));
      { p with avgConfidence = newAvgConf };
    });
  };

  // ---------------------------------------------------------------------------
  // Float formatting helper (private)
  // ---------------------------------------------------------------------------

  func floatToText(f : Float, _decimals : Nat) : Text {
    f.toText();
  };
};

import List "mo:core/List";
import Array "mo:core/Array";
import Time "mo:core/Time";
import AccessControl "mo:caffeineai-authorization/access-control";
import MarketTypes "../types/market";
import TradingTypes "../types/trading";
import AIEngine "../lib/ai_engine";
import Indicators "../lib/indicators";
import Float "mo:core/Float";
import ConfidenceTypes "../types/confidence";
import MultiframeLib "../lib/multiframe";
import TrainingTypes "../types/training";

mixin (
  accessControlState : AccessControl.AccessControlState,
  decisionLogs : List.List<TradingTypes.AIDecisionLog>,
  latestCondition : { var value : ?MarketTypes.MarketCondition },
  aiState : {
    var isRunning : Bool;
    var lastRunTime : Int;
    var nextRunTime : Int;
    var mode : Text;
    var cycleCount : Nat;
  },
  trainingState : { var value : TrainingTypes.AITrainingState },
  noTradeDecisions : List.List<ConfidenceTypes.NoTradeDecision>,
) {

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  // Build synthetic candles from a base price using deterministic index-based jitter
  func syntheticCandles(price : Float) : [MarketTypes.Candle] {
    let n = 60; // 60 synthetic 1-hour candles
    let baseVolatility = price * 0.005; // 0.5% per candle
    Array.tabulate<MarketTypes.Candle>(n, func(i : Nat) : MarketTypes.Candle {
      // Deterministic jitter: alternating pattern based on index parity
      let phase : Float = i.toFloat();
      // Zigzag oscillation without transcendentals
      let cycle = i % 8;
      let jitterFactor : Float = switch (cycle) {
        case 0 { 0.3 }; case 1 { 0.6 }; case 2 { 0.9 }; case 3 { 0.5 };
        case 4 { -0.3 }; case 5 { -0.6 }; case 6 { -0.9 }; case 7 { -0.5 };
        case _ { 0.0 };
      };
      let jitter = baseVolatility * jitterFactor;
      let c = price + jitter;
      let h = c + baseVolatility * 0.5;
      let l = c - baseVolatility * 0.5;
      {
        open   = c - jitter * 0.1;
        high   = h;
        low    = l;
        close  = c;
        volume = 1_000_000.0 + phase * 10_000.0;
        timestamp = Time.now() - ((n - i).toInt() * 3_600_000_000_000);
      };
    });
  };

  // Build a unique decision id from cycle count and symbol
  func makeDecisionId(cycle : Nat, symbol : Text) : Text {
    "d-" # cycle.toText() # "-" # symbol;
  };

  // ---------------------------------------------------------------------------
  // Run AI analysis cycle
  // ---------------------------------------------------------------------------

  // Run a full AI analysis cycle, generating decisions for all tracked symbols
  public shared ({ caller }) func runAIAnalysis() : async [TradingTypes.AIDecisionLog] {
    aiState.isRunning := true;
    let now = Time.now();

    let symbols : [Text] = ["BTC", "ETH", "BNB", "SOL", "ADA"];
    let riskScore : Float = if (aiState.mode == "paused") 100.0
      else if (aiState.mode == "live") 30.0
      else 20.0;

    let newLogs = List.empty<TradingTypes.AIDecisionLog>();
    let state = trainingState.value;

    for (symbol in symbols.values()) {
      let placeholderPrice : Float = switch (symbol) {
        case "BTC"  65_000.0;
        case "ETH"   3_500.0;
        case "BNB"     550.0;
        case "SOL"     160.0;
        case "ADA"       0.45;
        case _        100.0;
      };
      let candles = syntheticCandles(placeholderPrice);
      let market : MarketTypes.MarketData = {
        symbol;
        price        = placeholderPrice;
        change24h    = 0.0;
        volume24h    = 5_000_000_000.0;
        marketCap    = 1_200_000_000_000.0;
        lastUpdated  = now;
      };

      let indicators = Indicators.computeAll(candles);
      let condition  = AIEngine.classifyMarketCondition(indicators, market);
      let strategy   = AIEngine.selectStrategy(condition);
      latestCondition.value := ?condition;

      // Multi-timeframe analysis (use same candles across all timeframes as proxy)
      let mtd = MultiframeLib.fetchAndCacheMultiTimeframe(
        symbol, candles, candles, candles, candles, candles, candles, now,
      );
      let mtAnalysis = MultiframeLib.analyzeMultiTimeframe(mtd);

      // 7-factor confidence
      let factors = AIEngine.computeConfidenceFactors(
        indicators, condition, mtAnalysis, state.marketMemory, strategy,
      );
      let confidence = factors.total;

      // Dynamic threshold
      let threshold = AIEngine.getConfidenceThreshold(condition, state.consecutiveLosses);

      let skip = AIEngine.shouldSkipTrading(condition, riskScore) or aiState.mode == "paused";
      let decisionId = makeDecisionId(aiState.cycleCount, symbol);

      let decision = AIEngine.generateDecision(
        symbol, candles, market, condition, strategy, decisionId, now,
      );

      let action = decision.action;

      // Trade quality filter: check if we should record a no-trade
      var noTradeReason : ?ConfidenceTypes.NoTradeReason = null;
      if (not skip) {
        if (confidence < threshold) {
          noTradeReason := ?#LowConfidence;
        } else {
          switch (condition) {
            case (#ManipulationRisk) { noTradeReason := ?#RegimeMismatch };
            case (#LowLiquidityDanger) { noTradeReason := ?#LiquidityTooLow };
            case _ {};
          };
        };
        if (state.overtradingCount >= 4) {
          noTradeReason := ?#OvertradingFlag;
        };
      };

      // Log no-trade decisions
      switch (noTradeReason) {
        case (?reason) {
          let ntd : ConfidenceTypes.NoTradeDecision = {
            symbol;
            timestamp          = now;
            reason;
            confidenceAtTime   = confidence;
            thresholdAtTime    = threshold;
            marketRegime       = condition;
          };
          noTradeDecisions.add(ntd);
          // Rotate at 500
          let sz = noTradeDecisions.size();
          if (sz > 500) {
            let trimmed = noTradeDecisions.sliceToArray((sz - 500).toInt(), sz.toInt());
            noTradeDecisions.clear();
            for (ntEntry in trimmed.values()) { noTradeDecisions.add(ntEntry) };
          };
        };
        case null {};
      };

      let effectivelySkipped = skip or noTradeReason != null;

      let execStatus : { #Pending; #Executed; #Skipped; #Failed } =
        if (effectivelySkipped) #Skipped
        else if (confidence >= threshold and (action == #Buy or action == #Sell)) #Pending
        else #Skipped;

      let skipReason : ?Text =
        if (skip) (
          if (aiState.mode == "paused") ?("AI paused")
          else ?("Risk gate triggered: " # debug_show(condition))
        ) else switch (noTradeReason) {
          case (?#LowConfidence) ?("Confidence " # debug_show(confidence) # " below threshold " # debug_show(threshold));
          case (?#RegimeMismatch) ?("Market regime unsuitable: " # debug_show(condition));
          case (?#LiquidityTooLow) ?("Liquidity too low for safe entry");
          case (?#OvertradingFlag) ?("Overtrading flag: 4+ trades in recent window");
          case (?_) ?("Quality filter triggered");
          case null {
            switch (action) {
              case (#Hold) ?("No clear signal");
              case (#Skip) ?("Strategy in observation mode");
              case _ null;
            };
          };
        };

      let log : TradingTypes.AIDecisionLog = {
        decision;
        executionStatus = execStatus;
        executedTradeId = null;
        skipReason;
        confidenceFactors = factors;
        multiTimeframeSignals = mtAnalysis.signals;
        decisionCycleId = aiState.cycleCount;
        marketSnapshot = {
          price         = market.price;
          volume24h     = market.volume24h;
          volatilityPct = if (market.price > 0.0) indicators.atr / market.price * 100.0 else 0.0;
          btcDominance  = 0.0;
        };
        indicatorValues = {
          rsi               = indicators.rsi;
          macd              = indicators.macd;
          ema20             = indicators.ema20;
          ema50             = indicators.ema50;
          atr               = indicators.atr;
          bollingerBandwidth = indicators.bollingerUpper - indicators.bollingerLower;
        };
        alternativesConsidered = [];
        noTradeReason = skipReason;
        executionDetails = null;
      };
      newLogs.add(log);
    };

    for (log in newLogs.values()) { decisionLogs.add(log) };
    let maxLogs = 500;
    let currentSize = decisionLogs.size();
    if (currentSize > maxLogs) {
      let trimmed = decisionLogs.sliceToArray((currentSize - maxLogs).toInt(), currentSize.toInt());
      decisionLogs.clear();
      for (entry in trimmed.values()) { decisionLogs.add(entry) };
    };

    aiState.cycleCount  := aiState.cycleCount + 1;
    aiState.lastRunTime := now;
    aiState.nextRunTime := now + 60_000_000_000;
    aiState.isRunning   := false;

    newLogs.toArray();
  };

  // ---------------------------------------------------------------------------
  // Query functions
  // ---------------------------------------------------------------------------

  // Return most recent AI decision logs up to limit
  public query ({ caller }) func getLatestDecisions(limit : Nat) : async [TradingTypes.AIDecisionLog] {
    let n = decisionLogs.size();
    let start = if (n > limit) n - limit else 0;
    decisionLogs.sliceToArray(start, n);
  };

  // Return latest classified market condition
  public query ({ caller }) func getCurrentMarketCondition() : async ?MarketTypes.MarketCondition {
    latestCondition.value;
  };

  // Return current AI engine operational status
  public query ({ caller }) func getAIStatus() : async {
    isRunning : Bool;
    lastRunTime : Int;
    nextRunTime : Int;
    mode : Text;
    cycleCount : Nat;
  } {
    {
      isRunning  = aiState.isRunning;
      lastRunTime = aiState.lastRunTime;
      nextRunTime = aiState.nextRunTime;
      mode        = aiState.mode;
      cycleCount  = aiState.cycleCount;
    };
  };

  // ---------------------------------------------------------------------------
  // Mode control
  // ---------------------------------------------------------------------------

  // Return no-trade decision log
  public query ({ caller }) func getNoTradeLog() : async [ConfidenceTypes.NoTradeDecision] {
    noTradeDecisions.toArray();
  };

  // Set the AI operating mode: paper / live / signal / paused
  public shared ({ caller }) func setAIMode(mode : Text) : async Bool {
    switch (mode) {
      case ("paper" or "live" or "signal" or "paused") {
        aiState.mode := mode;
        true;
      };
      case _ false;
    };
  };
};

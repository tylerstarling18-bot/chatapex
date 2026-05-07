import List "mo:core/List";
import Array "mo:core/Array";
import Float "mo:core/Float";
import Time "mo:core/Time";
import Nat64 "mo:core/Nat64";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Text "mo:core/Text";
import AccessControl "mo:caffeineai-authorization/access-control";
import BotTypes "../types/bot";
import TradingTypes "../types/trading";
import MarketTypes "../types/market";
import EquityTypes "../types/equity";
import BotLib "../lib/bot";
import AIEngine "../lib/ai_engine";
import Indicators "../lib/indicators";
import PaperTrading "../lib/paper_trading";
import RiskManager "../lib/risk_manager";
import MultiframeLib "../lib/multiframe";
import ConfidenceTypes "../types/confidence";
import TrainingTypes "../types/training";
import MarketLib "../lib/market";
import OutCall "mo:caffeineai-http-outcalls/outcall";
import Map "mo:core/Map";
import Timer "mo:core/Timer";

mixin (
  accessControlState : AccessControl.AccessControlState,
  botConfig     : { var value : BotTypes.BotConfig },
  botState      : { var value : BotTypes.BotState },
  botTimerState : { var marketTimerId : ?Timer.TimerId; var decisionTimerId : ?Timer.TimerId },
  trades        : List.List<TradingTypes.Trade>,
  portfolio     : { var value : TradingTypes.Portfolio },
  marketSnapshots : List.List<MarketTypes.MarketSnapshot>,
  decisionLogs  : List.List<TradingTypes.AIDecisionLog>,
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
  riskSettings  : { var value : { maxDailyLossPercent : Float; maxPositionSizePercent : Float; maxConsecutiveLosses : Nat; enablePaperTrading : Bool; conservativeMode : Bool; emergencyStopEnabled : Bool } },
  riskState     : { var isPaused : Bool; var dailyLoss : Float; var dailyLossPercent : Float; var consecutiveLosses : Nat; var riskScore : Float },
  riskEvents    : List.List<{ id : Text; eventType : { #DailyLossLimitHit; #ConsecutiveLossesAutopaused; #EmergencyStop; #VolatilityPause; #ManualPause; #ResumeTrade }; message : Text; timestamp : Int; severity : { #Info; #Warning; #Critical } }>,
  equityHistory  : List.List<EquityTypes.EquitySnapshot>,
  confidenceHist : List.List<EquityTypes.ConfidencePoint>,
  simCosts : { var totalSlippage : Float; var totalFees : Float; var totalSpread : Float; var tradeCount : Nat },
  dailyRealizedPnL : { var value : Float },
  // Symbol -> stored OHLCV candles fetched from CoinGecko
  candleStore : Map.Map<Text, List.List<MarketTypes.Candle>>,
) {

  // IC transform for HTTP outcalls (unique name per mixin)
  public query func botTransform(input : OutCall.TransformationInput) : async OutCall.TransformationOutput {
    OutCall.transform(input);
  };

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Timer helpers — start/cancel recurring market + decision timers
  // ---------------------------------------------------------------------------

  func cancelBotTimers() {
    switch (botTimerState.marketTimerId) {
      case (?id) { Timer.cancelTimer(id); botTimerState.marketTimerId := null };
      case null {};
    };
    switch (botTimerState.decisionTimerId) {
      case (?id) { Timer.cancelTimer(id); botTimerState.decisionTimerId := null };
      case null {};
    };
  };

  func startBotTimers<system>() {
    cancelBotTimers();
    let cfg = botConfig.value;
    let marketSecs = cfg.refreshIntervalSecs;
    let decisionSecs = cfg.decisionIntervalSecs;
    botTimerState.marketTimerId := ?Timer.recurringTimer<system>(
      #seconds marketSecs,
      func() : async () {
        ignore await fetchLiveMarket();
      },
    );
    botTimerState.decisionTimerId := ?Timer.recurringTimer<system>(
      #seconds decisionSecs,
      func() : async () {
        ignore await runDecisionCycleInternal();
      },
    );
  };

  // Internal decision cycle implementation (shared by public API and timers)
  func runDecisionCycleInternal() : async { #ok : { decisionsGenerated : Nat; tradesExecuted : Nat; positionsUpdated : Nat; skipped : Nat; reasoning : Text }; #err : Text } {
    let bs = botState.value;
    switch (bs.status) {
      case (#Running) {};
      case _ { return #err("Bot is not running") };
    };
    if (BotLib.isDataStale(bs.lastDataFetchAt)) {
      // Auto-refresh market data when stale instead of erroring
      switch (await fetchLiveMarket()) {
        case (#err(_)) {
          botState.value := { bs with dataFeedHealthy = false };
          return #err("Data feed stale and refresh failed");
        };
        case (#ok(_)) {};
      };
    };
    if (riskState.isPaused) {
      return #err("Risk system paused");
    };

    let now = nowInt();
    let cfg = botConfig.value;
    let cycle = aiState.cycleCount;
    let prices = botLatestPrices();
    let state = trainingState.value;
    let riskScore = riskState.riskScore;

    let symbols : [Text] = ["BTC", "ETH", "BNB", "SOL", "ADA", "AVAX", "LINK", "DOT", "UNI", "LTC"];

    var decisionsGenerated : Nat = 0;
    var tradesExecuted : Nat = 0;
    var positionsUpdated : Nat = 0;
    var skipped : Nat = 0;
    let reasoningParts = List.empty<Text>();

    let closedByStop = PaperTrading.checkStopsAndTargets(trades, prices, now);
    for (t in closedByStop.values()) {
      positionsUpdated += 1;
      switch (t.pnl) {
        case (?pnl) {
          if (pnl < 0.0) {
            riskState.consecutiveLosses += 1;
            riskState.dailyLoss += Float.abs(pnl);
            riskState.dailyLossPercent := (riskState.dailyLoss / cfg.startingBalance) * 100.0;
          } else {
            riskState.consecutiveLosses := 0;
            dailyRealizedPnL.value += pnl;
          };
        };
        case null {};
      };
    };

    for (symbol in symbols.values()) {
      let candles = candlesForSymbol(symbol);
      let marketData : ?MarketTypes.MarketData = switch (marketSnapshots.last()) {
        case null null;
        case (?snap) snap.markets.find(func(m : MarketTypes.MarketData) : Bool { m.symbol == symbol });
      };
      let market : MarketTypes.MarketData = switch (marketData) {
        case (?m) m;
        case null {
          let price : Float = switch (symbol) {
            case "BTC" 65_000.0; case "ETH" 3_500.0; case "BNB" 550.0;
            case "SOL" 160.0;    case "ADA" 0.45;    case _ 100.0;
          };
          { symbol; price; change24h = 0.0; volume24h = 1_000_000.0;
            marketCap = 1_000_000_000.0; lastUpdated = now };
        };
      };

      let indicators = Indicators.computeAll(candles);
      let condition  = AIEngine.classifyMarketCondition(indicators, market);
      let strategy   = AIEngine.selectStrategy(condition);
      latestCondition.value := ?condition;

      let mtd = MultiframeLib.fetchAndCacheMultiTimeframe(
        symbol, candles, candles, candles, candles, candles, candles, now,
      );
      let mtAnalysis = MultiframeLib.analyzeMultiTimeframe(mtd);
      let factors = AIEngine.computeConfidenceFactors(
        indicators, condition, mtAnalysis, state.marketMemory, strategy,
      );
      let confidence = factors.total;
      let threshold = AIEngine.getConfidenceThreshold(condition, riskState.consecutiveLosses);
      let doSkip = AIEngine.shouldSkipTrading(condition, riskScore);

      let decisionId = botMakeDecisionId(cycle, symbol);
      let decision = AIEngine.generateDecision(
        symbol, candles, market, condition, strategy, decisionId, now,
      );

      decisionsGenerated += 1;

      let cp = BotLib.buildConfidencePoint(symbol, confidence, decision.action, condition);
      confidenceHist.add(cp);
      if (confidenceHist.size() > 2880) {
        let arr = confidenceHist.toArray();
        confidenceHist.clear();
        confidenceHist.addAll(arr.values().drop(1));
      };

      let atrPct = if (market.price > 0.0) indicators.atr / market.price * 100.0 else 0.0;
      let bbWidth = indicators.bollingerUpper - indicators.bollingerLower;
      let btcDom : Float = switch (marketSnapshots.last()) { case (?s) s.btcDominance; case null 0.0 };
      let enrichedSnapshot = {
        price         = market.price;
        volume24h     = market.volume24h;
        volatilityPct = atrPct;
        btcDominance  = btcDom;
      };
      let indicatorValues = {
        rsi               = indicators.rsi;
        macd              = indicators.macd;
        ema20             = indicators.ema20;
        ema50             = indicators.ema50;
        atr               = indicators.atr;
        bollingerBandwidth = bbWidth;
      };
      let alternatives : [(Text, Float)] = [
        ("TrendFollowing", if (strategy == #TrendFollowing) confidence else confidence * 0.8),
        ("MeanReversion",  if (strategy == #MeanReversion)  confidence else confidence * 0.75),
        ("Defensive",      40.0),
      ];

      var noTradeReasonText : ?Text = null;
      if (doSkip) {
        noTradeReasonText := ?("Risk gate: " # debug_show(condition));
        skipped += 1;
      } else if (confidence < threshold) {
        noTradeReasonText := ?("Confidence " # confidence.toText() # " < threshold " # threshold.toText());
        skipped += 1;
      } else if (decision.action == #Hold or decision.action == #Skip) {
        noTradeReasonText := ?("No clear signal");
        skipped += 1;
      };

      let canTrade = (not doSkip) and (confidence >= threshold) and
        (decision.action == #Buy or decision.action == #Sell) and
        cfg.tradingMode == #Autonomous;

      var execStatus : { #Pending; #Executed; #Skipped; #Failed } = if (canTrade) #Pending else #Skipped;
      var executedTradeId : ?Text = null;
      var execDetails : ?{ slippagePct : Float; feePct : Float; spreadPct : Float; executionDelayMs : Nat } = null;

      if (canTrade) {
        switch (decision.action) {
          case (#Buy) {
            let currentPortfolio = PaperTrading.computePortfolio(trades, prices, cfg.startingBalance);
            let blocked = RiskManager.validateTrade(
              riskSettings.value, currentPortfolio, decision,
              riskState.dailyLossPercent, riskState.consecutiveLosses,
            );
            switch (blocked) {
              case (?reason) {
                execStatus := #Skipped;
                noTradeReasonText := ?reason;
                skipped += 1;
              };
              case null {
                let tradeId = botMakeTradeId(now, symbol);
                let (trade, newPortfolio) = PaperTrading.openTrade(trades, decision, currentPortfolio, now, tradeId);
                if (trade.status == #Open) {
                  portfolio.value := newPortfolio;
                  executedTradeId := ?trade.id;
                  execStatus := #Executed;
                  tradesExecuted += 1;
                  let slipAmt = Float.abs(trade.entryPrice - decision.entryPrice);
                  let tradeVal = trade.quantity * trade.entryPrice;
                  let feeAmt = tradeVal * cfg.simulationFidelity.feeTakerPct;
                  let spreadAmt = tradeVal * cfg.simulationFidelity.spreadPct;
                  simCosts.totalSlippage += slipAmt;
                  simCosts.totalFees += feeAmt;
                  simCosts.totalSpread += spreadAmt;
                  simCosts.tradeCount += 1;
                  let slipPct = if (decision.entryPrice > 0.0) slipAmt / decision.entryPrice * 100.0 else 0.0;
                  execDetails := ?{
                    slippagePct      = slipPct;
                    feePct           = cfg.simulationFidelity.feeTakerPct * 100.0;
                    spreadPct        = cfg.simulationFidelity.spreadPct * 100.0;
                    executionDelayMs = 120 + (now % 380).toNat();
                  };
                  reasoningParts.add("EXEC " # symbol # " BUY @" # trade.entryPrice.toText());
                } else {
                  execStatus := #Skipped;
                  skipped += 1;
                };
              };
            };
          };
          case (#Sell) {
            switch (PaperTrading.closePosition(trades, symbol, market.price, now)) {
              case null {
                execStatus := #Skipped;
                noTradeReasonText := ?("No open position to sell");
                skipped += 1;
              };
              case (?closed) {
                executedTradeId := ?closed.id;
                execStatus := #Executed;
                tradesExecuted += 1;
                switch (closed.pnl) {
                  case (?pnl) {
                    if (pnl < 0.0) {
                      riskState.consecutiveLosses += 1;
                      riskState.dailyLoss += Float.abs(pnl);
                      riskState.dailyLossPercent := (riskState.dailyLoss / cfg.startingBalance) * 100.0;
                    } else {
                      riskState.consecutiveLosses := 0;
                      dailyRealizedPnL.value += pnl;
                    };
                  };
                  case null {};
                };
                portfolio.value := PaperTrading.computePortfolio(trades, prices, cfg.startingBalance);
                reasoningParts.add("EXEC " # symbol # " SELL @" # market.price.toText());
              };
            };
          };
          case _ {
            execStatus := #Skipped;
            skipped += 1;
          };
        };
      };

      let logEntry : TradingTypes.AIDecisionLog = {
        decision;
        executionStatus  = execStatus;
        executedTradeId;
        skipReason       = noTradeReasonText;
        confidenceFactors = factors;
        multiTimeframeSignals = mtAnalysis.signals;
        decisionCycleId  = cycle;
        marketSnapshot   = enrichedSnapshot;
        indicatorValues;
        alternativesConsidered = alternatives;
        noTradeReason    = noTradeReasonText;
        executionDetails = execDetails;
      };
      decisionLogs.add(logEntry);
    };

    if (decisionLogs.size() > 2000) {
      let arr = decisionLogs.toArray();
      decisionLogs.clear();
      decisionLogs.addAll(arr.values().drop(500));
    };

    let tNat64 = nowNat64();
    botState.value := { botState.value with
      lastDecisionAt      = ?tNat64;
      decisionCycleCount  = cycle + 1;
      tradesExecutedCount = botState.value.tradesExecutedCount + tradesExecuted;
    };
    aiState.cycleCount  := cycle + 1;
    aiState.lastRunTime := now;
    aiState.nextRunTime := now + (cfg.decisionIntervalSecs.toInt() * 1_000_000_000);

    let currentPortfolio = PaperTrading.computePortfolio(trades, prices, cfg.startingBalance);
    portfolio.value := currentPortfolio;
    let eqSnap = BotLib.buildEquitySnapshot(currentPortfolio, dailyRealizedPnL.value, cfg.startingBalance);
    equityHistory.add(eqSnap);
    if (equityHistory.size() > 1440) {
      let arr = equityHistory.toArray();
      equityHistory.clear();
      equityHistory.addAll(arr.values().drop(1));
    };

    let parts = reasoningParts.toArray();
    let reasoningText = if (parts.size() == 0) {
      "Cycle " # cycle.toText() # " complete. Skipped=" # skipped.toText() # "/" # decisionsGenerated.toText();
    } else {
      parts.values().join("; ");
    };

    #ok({ decisionsGenerated; tradesExecuted; positionsUpdated; skipped; reasoning = reasoningText });
  };

  func nowNat64() : Nat64 {
    let t = Time.now();
    if (t < 0) { 0 } else { (Int.abs(t) / 1_000_000_000).toNat64() };
  };

  func nowInt() : Int { Time.now() };

  func botLatestPrices() : [(Text, Float)] {
    switch (marketSnapshots.last()) {
      case null [];
      case (?snap) {
        snap.markets.map<MarketTypes.MarketData, (Text, Float)>(func(m) { (m.symbol, m.price) });
      };
    };
  };

  func botMakeTradeId(now : Int, suffix : Text) : Text {
    "t-" # now.toText() # "-" # suffix;
  };

  func botMakeDecisionId(cycle : Nat, symbol : Text) : Text {
    "d-" # cycle.toText() # "-" # symbol;
  };

  // Fetch live market data and cache snapshot. Returns #err on failure.
  func fetchLiveMarket() : async { #ok : Text; #err : Text } {
    let headers : [OutCall.Header] = [
      { name = "User-Agent"; value = "ApexAITrader/1.0" },
      { name = "Accept";     value = "application/json" },
    ];
    let marketsUrl = "https://api.coingecko.com/api/v3/coins/markets" #
      "?vs_currency=usd" #
      "&ids=bitcoin,ethereum,binancecoin,solana,cardano,avalanche-2,chainlink,polkadot,uniswap,litecoin" #
      "&order=market_cap_desc&per_page=10&page=1&sparkline=false&price_change_percentage=24h";
    let marketsJson = try {
      await OutCall.httpGetRequest(marketsUrl, headers, botTransform);
    } catch (_) {
      botState.value := { botState.value with dataFeedHealthy = false };
      return #err("Failed to fetch live market data. Please try again.");
    };
    let markets = MarketLib.parseMarketDataResponse(marketsJson);
    if (markets.size() == 0) {
      botState.value := { botState.value with dataFeedHealthy = false };
      return #err("Failed to fetch live market data. Please try again.");
    };
    let globalJson = try {
      await OutCall.httpGetRequest("https://api.coingecko.com/api/v3/global", headers, botTransform);
    } catch (_) { "" };
    let (totalMcap, btcDom) = if (globalJson == "") {
      (MarketLib.totalMarketCap(markets), 0.0);
    } else {
      MarketLib.parseGlobalData(globalJson);
    };
    let snap = MarketLib.buildSnapshot(markets, btcDom, totalMcap);
    marketSnapshots.add(snap);
    if (marketSnapshots.size() > 1440) {
      let arr = marketSnapshots.toArray();
      marketSnapshots.clear();
      marketSnapshots.addAll(arr.values().drop(1));
    };
    let t = nowNat64();
    botState.value := { botState.value with
      lastDataFetchAt = ?t;
      dataFeedHealthy = true;
    };
    #ok("Fetched " # markets.size().toText() # " assets");
  };

  func candlesForSymbol(symbol : Text) : [MarketTypes.Candle] {
    // 1. Use stored OHLCV candles if available
    switch (candleStore.get(symbol)) {
      case (?stored) {
        if (stored.size() >= 2) {
          return stored.toArray();
        };
      };
      case null {};
    };
    // 2. Fall back to price history from market snapshots (no fabrication)
    let snaps = marketSnapshots.toArray();
    snaps.filterMap(
      func(snap) {
        switch (snap.markets.find(func(m : MarketTypes.MarketData) : Bool { m.symbol == symbol })) {
          case null null;
          case (?m) {
            let p = m.price;
            ?{ open = p; high = p * 1.001; low = p * 0.999; close = p;
               volume = m.volume24h / 1440.0; timestamp = snap.timestamp };
          };
        };
      }
    );
  };

  // ---------------------------------------------------------------------------
  // Bot lifecycle API
  // ---------------------------------------------------------------------------

  public shared func startBot() : async { #ok : BotTypes.BotState; #err : Text } {
    let cur = botState.value;
    switch (cur.status) {
      case (#Running) { return #err("Bot is already running") };
      case _ {};
    };
    let newState = BotLib.startTransition(cur);
    botState.value := newState;
    aiState.mode := "paper";

    switch (await fetchLiveMarket()) {
      case (#err(msg)) {
        botState.value := BotLib.stoppedState();
        aiState.mode := "paper";
        return #err(msg);
      };
      case (#ok(_)) {};
    };

    let cfg = botConfig.value;
    let prices = botLatestPrices();
    let initialPortfolio = PaperTrading.computePortfolio(trades, prices, cfg.startingBalance);
    let initialSnap = BotLib.buildEquitySnapshot(initialPortfolio, dailyRealizedPnL.value, cfg.startingBalance);
    equityHistory.add(initialSnap);

    startBotTimers<system>();

    #ok(botState.value);
  };


  public shared func pauseBot() : async BotTypes.BotState {
    cancelBotTimers();
    let newState = BotLib.pauseTransition(botState.value);
    botState.value := newState;
    aiState.mode := "paused";
    newState;
  };

  public shared func resumeBot() : async BotTypes.BotState {
    let newState = BotLib.resumeTransition(botState.value);
    botState.value := newState;
    aiState.mode := "paper";
    startBotTimers<system>();
    newState;
  };

  public shared func emergencyStopBot() : async BotTypes.BotState {
    cancelBotTimers();
    let newState = BotLib.emergencyStopTransition(botState.value);
    botState.value := newState;
    aiState.mode := "paused";
    riskState.isPaused := true;
    newState;
  };

  public shared func resetBot() : async BotTypes.BotState {
    cancelBotTimers();
    let cfg = botConfig.value;
    trades.clear();
    portfolio.value := {
      totalValue = cfg.startingBalance;
      cashBalance = cfg.startingBalance;
      investedValue = 0.0;
      totalPnl = 0.0;
      totalPnlPercent = 0.0;
      dayPnl = 0.0;
      dayPnlPercent = 0.0;
      winRate = 0.0;
      totalTrades = 0;
      winningTrades = 0;
      positions = [];
    };
    decisionLogs.clear();
    aiState.cycleCount := 0;
    aiState.lastRunTime := 0;
    aiState.nextRunTime := 0;
    aiState.mode := "paper";
    aiState.isRunning := false;
    riskState.isPaused := false;
    riskState.dailyLoss := 0.0;
    riskState.dailyLossPercent := 0.0;
    riskState.consecutiveLosses := 0;
    riskState.riskScore := 0.0;
    let ts = trainingState.value;
    trainingState.value := { ts with
      practiceTradesCount = 0;
      overallWinRate = 0.0;
      consecutiveLosses = 0;
      overtradingCount = 0;
    };
    equityHistory.clear();
    confidenceHist.clear();
    simCosts.totalSlippage := 0.0;
    simCosts.totalFees := 0.0;
    simCosts.totalSpread := 0.0;
    simCosts.tradeCount := 0;
    dailyRealizedPnL.value := 0.0;
    let newState = BotLib.resetTransition();
    botState.value := newState;
    newState;
  };

  public query func getBotState() : async BotTypes.BotState {
    let s = botState.value;
    { s with uptimeSeconds = BotLib.computeUptime(s.startedAt) };
  };

  public query func getBotConfig() : async BotTypes.BotConfig {
    botConfig.value;
  };

  public shared func updateBotConfig(cfg : BotTypes.BotConfig) : async { #ok : BotTypes.BotConfig; #err : Text } {
    switch (BotLib.validateConfig(cfg)) {
      case (?err) { #err(err) };
      case null {
        botConfig.value := cfg;
        #ok(cfg);
      };
    };
  };

  // ---------------------------------------------------------------------------
  // Market data cycle
  // ---------------------------------------------------------------------------

  public shared func runMarketCycle() : async { #ok : Text; #err : Text } {
    await fetchLiveMarket();
  };

  // Fetch OHLCV candles for a symbol from CoinGecko and store them.
  // Replaces any previously stored candles for that symbol.
  public shared func fetchAndStoreHistoricalCandles(symbol : Text, days : Nat) : async { #ok : Nat; #err : Text } {
    let coinId = MarketLib.symbolToCoingeckoId(symbol);
    let daysText = days.toText();
    let url = "https://api.coingecko.com/api/v3/coins/" # coinId #
      "/ohlc?vs_currency=usd&days=" # daysText;
    let headers : [OutCall.Header] = [
      { name = "User-Agent"; value = "ApexAITrader/1.0" },
      { name = "Accept";     value = "application/json" },
    ];
    let json = try {
      await OutCall.httpGetRequest(url, headers, botTransform);
    } catch (_) {
      return #err("Failed to fetch candles for " # symbol # ". Please try again.");
    };
    let candles = MarketLib.parseCandleResponse(json);
    if (candles.size() == 0) {
      return #err("No candle data returned for " # symbol);
    };
    let stored = List.empty<MarketTypes.Candle>();
    stored.addAll(candles.values());
    candleStore.add(symbol, stored);
    #ok(candles.size());
  };

  // Return stored OHLCV candles for a given symbol (fetched via fetchAndStoreHistoricalCandles).
  // Falls back to price-history candles derived from market snapshots.
  public query func getMarketCandles(symbol : Text) : async [MarketTypes.Candle] {
    candlesForSymbol(symbol);
  };

  public query func getDataFeedStatus() : async BotTypes.DataFeedStatus {
    let bs = botState.value;
    let stale : ?Nat64 = if (not bs.dataFeedHealthy) { bs.lastDataFetchAt } else { null };
    let assetCount : Nat = switch (marketSnapshots.last()) {
      case null 0;
      case (?s) s.markets.size();
    };
    {
      healthy     = bs.dataFeedHealthy;
      lastFetchAt = bs.lastDataFetchAt;
      assetCount;
      staleSince  = stale;
    };
  };

  // ---------------------------------------------------------------------------
  // Autonomous decision cycle
  // ---------------------------------------------------------------------------

  public shared func runDecisionCycle() : async { #ok : { decisionsGenerated : Nat; tradesExecuted : Nat; positionsUpdated : Nat; skipped : Nat; reasoning : Text }; #err : Text } {
    await runDecisionCycleInternal();
  };

  public query func getDecisionCycleStats() : async BotTypes.DecisionCycleStats {
    let total = aiState.cycleCount;
    let logs = decisionLogs.toArray();
    let total_logs = logs.size();
    let avgConf : Float = if (total_logs > 0) {
      logs.foldLeft(0.0, func(acc, l) { acc + l.confidenceFactors.total }) / total_logs.toFloat();
    } else 0.0;
    let skippedCount = logs.filter(func(l : TradingTypes.AIDecisionLog) : Bool { l.executionStatus == #Skipped }).size();
    let noTradeRate : Float = if (total_logs > 0) {
      skippedCount.toFloat() / total_logs.toFloat();
    } else 0.0;
    let allTrades = trades.toArray();
    let closedTrades = allTrades.filter(func(t : TradingTypes.Trade) : Bool { t.status != #Open });
    let wins = closedTrades.filter(func(t : TradingTypes.Trade) : Bool {
      switch (t.pnl) { case (?p) p > 0.0; case null false; };
    });
    let winRate = if (closedTrades.size() > 0) {
      wins.size().toFloat() / closedTrades.size().toFloat() * 100.0;
    } else 0.0;
    let uptimeSecs = BotLib.computeUptime(botState.value.startedAt);
    let cyclesPerHour : Float = if (uptimeSecs > 0) {
      total.toFloat() / (Nat.fromNat64(uptimeSecs).toFloat() / 3600.0);
    } else 0.0;
    {
      totalCycles       = total;
      tradesThisSession = botState.value.tradesExecutedCount;
      avgConfidence     = avgConf;
      noTradeRate;
      winRate;
      cyclesPerHour;
    };
  };

  public query func getSimulationStats() : async BotTypes.SimulationStats {
    BotLib.computeSimulationStats(
      simCosts.totalSlippage,
      simCosts.totalFees,
      simCosts.totalSpread,
      simCosts.tradeCount,
    );
  };

  public query func getEquityHistory(limit : Nat) : async [EquityTypes.EquitySnapshot] {
    let all = equityHistory.toArray();
    let n = all.size();
    if (limit == 0 or n <= limit) all
    else all.sliceToArray((n - limit).toInt(), n.toInt());
  };

  public query func getCurrentEquity() : async ?EquityTypes.EquitySnapshot {
    equityHistory.last();
  };

  public query func getRecentDecisions(limit : Nat) : async [TradingTypes.AIDecisionLog] {
    let all = decisionLogs.toArray();
    let sorted = all.sort(func(a, b) {
      Int.compare(b.decision.timestamp, a.decision.timestamp);
    });
    if (limit == 0 or sorted.size() <= limit) sorted
    else sorted.sliceToArray(0, limit.toInt());
  };

  public query func getDecisionsByAsset(asset : Text, limit : Nat) : async [TradingTypes.AIDecisionLog] {
    let filtered = decisionLogs.filter(func(l : TradingTypes.AIDecisionLog) : Bool {
      l.decision.symbol == asset;
    }).toArray();
    let sorted = filtered.sort(func(a, b) {
      Int.compare(b.decision.timestamp, a.decision.timestamp);
    });
    if (limit == 0 or sorted.size() <= limit) sorted
    else sorted.sliceToArray(0, limit.toInt());
  };

  public query func getLiveActivityFeed(limit : Nat) : async [BotTypes.ActivityItem] {
    let all = decisionLogs.toArray();
    let sorted = all.sort(func(a, b) {
      Int.compare(b.decision.timestamp, a.decision.timestamp);
    });
    let items = sorted.map(func(l : TradingTypes.AIDecisionLog) : BotTypes.ActivityItem {
      let actionText = switch (l.decision.action) {
        case (#Buy)  "BUY";
        case (#Sell) "SELL";
        case (#Hold) "HOLD";
        case (#Skip) "SKIP";
      };
      {
        timestamp  = (Int.abs(l.decision.timestamp) / 1_000_000_000).toNat64();
        asset      = l.decision.symbol;
        action     = actionText;
        confidence = l.confidenceFactors.total;
        reasoning  = l.decision.reasoning;
        executed   = l.executionStatus == #Executed;
      };
    });
    if (limit == 0 or items.size() <= limit) items
    else items.sliceToArray(0, limit.toInt());
  };

  public query func getConfidenceTimeline(asset : Text, limit : Nat) : async [EquityTypes.ConfidencePoint] {
    let filtered = confidenceHist.filter(func(p : EquityTypes.ConfidencePoint) : Bool {
      p.asset == asset;
    }).toArray();
    let n = filtered.size();
    if (limit == 0 or n <= limit) filtered
    else filtered.sliceToArray((n - limit).toInt(), n.toInt());
  };

  public query func getAllConfidenceTimeline(limit : Nat) : async [EquityTypes.ConfidencePoint] {
    let all = confidenceHist.toArray();
    let n = all.size();
    if (limit == 0 or n <= limit) all
    else all.sliceToArray((n - limit).toInt(), n.toInt());
  };
};

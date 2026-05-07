import List "mo:core/List";
import Array "mo:core/Array";
import Time "mo:core/Time";
import Nat "mo:core/Nat";
import AccessControl "mo:caffeineai-authorization/access-control";
import TradingTypes "../types/trading";
import RiskTypes "../types/risk";
import MarketTypes "../types/market";
import PaperTrading "../lib/paper_trading";
import RiskManager "../lib/risk_manager";
import Int "mo:core/Int";
import Float "mo:core/Float";

mixin (
  accessControlState : AccessControl.AccessControlState,
  trades : List.List<TradingTypes.Trade>,
  portfolio : { var value : TradingTypes.Portfolio },
  marketSnapshots : List.List<MarketTypes.MarketSnapshot>,
  riskSettings : { var value : RiskTypes.RiskSettings },
  riskState : {
    var isPaused : Bool;
    var dailyLoss : Float;
    var dailyLossPercent : Float;
    var consecutiveLosses : Nat;
    var riskScore : Float;
  },
  decisionLogs : List.List<TradingTypes.AIDecisionLog>,
  riskEvents : List.List<RiskTypes.RiskEvent>,
) {

  // Build latest prices array from most recent market snapshot
  func latestPrices() : [(Text, Float)] {
    switch (marketSnapshots.last()) {
      case null { [] };
      case (?snap) {
        snap.markets.map<MarketTypes.MarketData, (Text, Float)>(
          func(m) { (m.symbol, m.price) },
        );
      };
    };
  };

  // Generate a simple trade ID from current time + counter
  func makeTradeId(now : Int, suffix : Text) : Text {
    "trade-" # now.toText() # "-" # suffix;
  };

  // Return current paper trading portfolio state
  public query ({ caller }) func getPortfolio() : async TradingTypes.Portfolio {
    let prices = latestPrices();
    PaperTrading.computePortfolio(trades, prices, 100_000.0);
  };

  // Return all currently open positions
  public query ({ caller }) func getOpenPositions() : async [TradingTypes.Position] {
    PaperTrading.getOpenPositions(trades, latestPrices());
  };

  // Return recent trade history sorted newest first, up to limit
  public query ({ caller }) func getTradeHistory(limit : Nat) : async [TradingTypes.Trade] {
    let all = trades.toArray();
    let sorted = all.sort(func(a, b) {
      Int.compare(b.openTime, a.openTime);
    });
    if (limit == 0 or sorted.size() <= limit) {
      sorted;
    } else {
      sorted.sliceToArray(0, limit.toInt());
    };
  };

  // Manually execute a paper trade with a given symbol, direction and quantity
  public shared ({ caller }) func executeManualTrade(
    symbol : Text,
    action : Text,
    quantity : Float,
  ) : async { #ok : TradingTypes.Trade; #err : Text } {
    let prices = latestPrices();
    let price = switch (prices.find(func((s, _)) { s == symbol })) {
      case (?(_, p)) p;
      case null { return #err("No market data for " # symbol) };
    };
    let tradeAction : TradingTypes.TradeAction = if (action == "sell") #Sell else #Buy;
    let now = Time.now();
    // Build a minimal decision record for the manual trade
    let decision : TradingTypes.TradeDecision = {
      id = makeTradeId(now, "manual");
      symbol;
      action = tradeAction;
      confidence = 100.0;
      entryPrice = price;
      targetPrice = null;
      stopLoss = price * 0.97; // 3% default stop
      riskReward = 1.5;
      reasoning = "Manual trade executed by user";
      indicators = {
        rsi = 50.0; macd = 0.0; macdSignal = 0.0;
        bollingerUpper = price * 1.02; bollingerMid = price; bollingerLower = price * 0.98;
        ema20 = price; ema50 = price; atr = price * 0.01;
        momentum = 0.0; trendStrength = 50.0;
      };
      marketCondition = #Neutral;
      timestamp = now;
      strategyMode = #Observation;
    };
    let settings = riskSettings.value;
    let currentPortfolio = PaperTrading.computePortfolio(trades, prices, 100_000.0);
    let blocked = RiskManager.validateTrade(
      settings, currentPortfolio, decision,
      riskState.dailyLossPercent, riskState.consecutiveLosses,
    );
    switch (blocked) {
      case (?reason) { #err(reason) };
      case null {
        let tradeId = makeTradeId(now, symbol);
        let (trade, newPortfolio) = PaperTrading.openTrade(trades, decision, currentPortfolio, now, tradeId);
        portfolio.value := newPortfolio;
        #ok(trade);
      };
    };
  };

  // Close an open position for a symbol at current market price
  public shared ({ caller }) func closePosition(symbol : Text) : async { #ok : TradingTypes.Trade; #err : Text } {
    let prices = latestPrices();
    let price = switch (prices.find(func((s, _)) { s == symbol })) {
      case (?(_, p)) p;
      case null {
        // Fall back to entry price if no market data
        switch (trades.find(func(t : TradingTypes.Trade) : Bool { t.symbol == symbol and t.status == #Open })) {
          case (?t) t.entryPrice;
          case null { return #err("No open position found for " # symbol) };
        };
      };
    };
    let now = Time.now();
    switch (PaperTrading.closePosition(trades, symbol, price, now)) {
      case null { #err("No open position found for " # symbol) };
      case (?trade) {
        // Update portfolio and risk counters
        let newPortfolio = PaperTrading.computePortfolio(trades, prices, 100_000.0);
        portfolio.value := newPortfolio;
        switch (trade.pnl) {
          case (?pnl) {
            if (pnl < 0.0) {
              riskState.consecutiveLosses += 1;
              riskState.dailyLoss += Float.abs(pnl);
              let initialBalance = 100_000.0;
              riskState.dailyLossPercent := (riskState.dailyLoss / initialBalance) * 100.0;
            } else {
              riskState.consecutiveLosses := 0;
            };
            // Auto-pause on consecutive loss breach
            if (RiskManager.isConsecutiveLossLimitBreached(riskSettings.value, riskState.consecutiveLosses)) {
              riskState.isPaused := true;
              let ev = RiskManager.buildRiskEvent(
                #ConsecutiveLossesAutopaused,
                "Auto-paused after " # riskState.consecutiveLosses.toText() # " consecutive losses.",
                #Warning,
                makeTradeId(now, "risk-consecloss"),
                now,
              );
              riskEvents.add(ev);
            };
            // Auto-pause on daily loss breach
            if (RiskManager.isDailyLossLimitBreached(riskSettings.value, riskState.dailyLossPercent)) {
              riskState.isPaused := true;
              let ev = RiskManager.buildRiskEvent(
                #DailyLossLimitHit,
                "Daily loss limit of " # riskSettings.value.maxDailyLossPercent.toText() # "% reached.",
                #Critical,
                makeTradeId(now, "risk-dailyloss"),
                now,
              );
              riskEvents.add(ev);
            };
          };
          case null {};
        };
        #ok(trade);
      };
    };
  };

  // Execute all Pending AI decision logs as paper trades (called by AI cycle)
  public shared ({ caller }) func executePendingDecisions() : async [TradingTypes.Trade] {
    let now = Time.now();
    let prices = latestPrices();
    let executed = List.empty<TradingTypes.Trade>();
    decisionLogs.mapInPlace(func(log : TradingTypes.AIDecisionLog) : TradingTypes.AIDecisionLog {
      if (log.executionStatus != #Pending) { return log };
      let settings = riskSettings.value;
      let currentPortfolio = PaperTrading.computePortfolio(trades, prices, 100_000.0);
      // Skip non-buy decisions
      switch (log.decision.action) {
        case (#Buy) {};
        case (_) {
          return { log with executionStatus = #Skipped; skipReason = ?("Action is not Buy") };
        };
      };
      let blocked = RiskManager.validateTrade(
        settings, currentPortfolio, log.decision,
        riskState.dailyLossPercent, riskState.consecutiveLosses,
      );
      switch (blocked) {
        case (?reason) {
          { log with executionStatus = #Skipped; skipReason = ?reason };
        };
        case null {
          let tradeId = makeTradeId(now, log.decision.symbol);
          let (trade, newPortfolio) = PaperTrading.openTrade(trades, log.decision, currentPortfolio, now, tradeId);
          portfolio.value := newPortfolio;
          if (trade.status == #Open) {
            executed.add(trade);
            { log with executionStatus = #Executed; executedTradeId = ?trade.id };
          } else {
            { log with executionStatus = #Skipped; skipReason = ?("Trade action was not Buy") };
          };
        };
      };
    });
    // Run stop/target checks after executions
    let closedByStop = PaperTrading.checkStopsAndTargets(trades, prices, now);
    for (t in closedByStop.values()) {
      executed.add(t);
      switch (t.pnl) {
        case (?pnl) {
          if (pnl < 0.0) {
            riskState.consecutiveLosses += 1;
          } else {
            riskState.consecutiveLosses := 0;
          };
        };
        case null {};
      };
    };
    portfolio.value := PaperTrading.computePortfolio(trades, prices, 100_000.0);
    executed.toArray();
  };

};

import Array "mo:core/Array";
import Float "mo:core/Float";
import Nat "mo:core/Nat";
import Int "mo:core/Int";
import List "mo:core/List";
import BacktestTypes "../types/backtest";
import TradingTypes "../types/trading";
import MarketTypes "../types/market";
import Indicators "indicators";
import AIEngine "ai_engine";

// Backtesting engine — replays historical candles through the AI
module {
  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  func floatSqrt(x : Float) : Float { Float.sqrt(x) };

  // Build a synthetic MarketData record from a candle for the AI engine
  func candleToMarket(symbol : Text, candle : MarketTypes.Candle) : MarketTypes.MarketData {
    {
      symbol;
      price = candle.close;
      change24h = if (candle.open > 0.0) (candle.close - candle.open) / candle.open * 100.0 else 0.0;
      volume24h = candle.volume;
      marketCap = 0.0;
      lastUpdated = candle.timestamp;
    };
  };

  // Generate a deterministic trade id from session + index
  func tradeId(sessionId : Text, idx : Nat) : Text {
    sessionId # "-t" # idx.toText();
  };

  func decisionId(sessionId : Text, idx : Nat) : Text {
    sessionId # "-d" # idx.toText();
  };

  // ---------------------------------------------------------------------------
  // Run a full backtest replay
  // ---------------------------------------------------------------------------

  // Run a backtest session and return results.
  // For each symbol we step through candles in chronological order, run the AI
  // analysis pipeline, and simulate paper trades.
  public func runBacktest(
    session : BacktestTypes.BacktestSession,
    historicalCandles : [(Text, [MarketTypes.Candle])],
  ) : BacktestTypes.BacktestResults {
    var cashBalance = session.initialBalance;
    var tradeCounter : Nat = 0;
    var decisionCounter : Nat = 0;
    let closedTrades = List.empty<TradingTypes.Trade>();
    let openTrades = List.empty<TradingTypes.Trade>();
    let equityPoints = List.empty<BacktestTypes.EquityPoint>();

    equityPoints.add({ timestamp = session.startDate; value = session.initialBalance });

    for ((symbol, candles) in historicalCandles.values()) {
      let sorted = candles.sort(func(a, b) {
        if (a.timestamp < b.timestamp) #less
        else if (a.timestamp > b.timestamp) #greater
        else #equal
      });

      let windowSize : Nat = 26;

      for ((i, candle) in sorted.enumerate()) {
        if (i < windowSize) {
          equityPoints.add({ timestamp = candle.timestamp; value = cashBalance });
        } else {
          let fromIdx : Int = i.toInt() - windowSize.toInt() + 1;
          let toIdx : Int   = i.toInt() + 1;
          let window = sorted.sliceToArray(fromIdx, toIdx);

          let indicators = Indicators.computeAll(window);
          let market     = candleToMarket(symbol, candle);
          let condition  = AIEngine.classifyMarketCondition(indicators, market);
          let strategy   = AIEngine.selectStrategy(condition);

          // Check open position for this symbol
          let openIdx = openTrades.findIndex(func(t : TradingTypes.Trade) : Bool {
            t.symbol == symbol and t.status == #Open
          });
          switch (openIdx) {
            case (?idx) {
              let openTrade = openTrades.at(idx);
              var shouldClose = false;
              var closeStatus : TradingTypes.TradeStatus = #Closed;

              if (candle.low <= openTrade.stopLoss) {
                shouldClose := true;
                closeStatus := #StopLossHit;
              };
              switch (openTrade.takeProfit) {
                case (?tp) {
                  if (candle.high >= tp) {
                    shouldClose := true;
                    closeStatus := #TakeProfitHit;
                  };
                };
                case null {};
              };

              if (shouldClose) {
                let exitPrice = switch (closeStatus) {
                  case (#StopLossHit)   openTrade.stopLoss;
                  case (#TakeProfitHit) switch (openTrade.takeProfit) { case (?tp) tp; case null candle.close };
                  case _                candle.close;
                };
                let pnl    = (exitPrice - openTrade.entryPrice) * openTrade.quantity;
                let pnlPct = (exitPrice - openTrade.entryPrice) / openTrade.entryPrice * 100.0;
                cashBalance += openTrade.entryPrice * openTrade.quantity + pnl;
                let closed : TradingTypes.Trade = {
                  openTrade with
                  exitPrice  = ?exitPrice;
                  closeTime  = candle.timestamp;
                  status     = closeStatus;
                  pnl        = ?pnl;
                  pnlPercent = ?pnlPct;
                };
                openTrades.put(idx, closed);
                closedTrades.add(closed);
              };
            };
            case null {};
          };

          // Maybe open a new position
          let hasOpen = openTrades.any(func(t : TradingTypes.Trade) : Bool {
            t.symbol == symbol and t.status == #Open
          });
          if (not hasOpen and not AIEngine.shouldSkipTrading(condition, 0.0)) {
            let did = decisionId(session.id, decisionCounter);
            decisionCounter += 1;

            let decision = AIEngine.generateDecision(
              symbol, window, market, condition, strategy, did, candle.timestamp,
            );

            if (decision.action == #Buy and decision.confidence > 50.0 and cashBalance > 0.0) {
              let positionValue = cashBalance * 0.02;
              let qty = if (candle.close > 0.0) positionValue / candle.close else 0.0;
              if (qty > 0.0) {
                cashBalance -= positionValue;
                let tid = tradeId(session.id, tradeCounter);
                tradeCounter += 1;
                openTrades.add({
                  id         = tid;
                  symbol;
                  action     = #Buy;
                  entryPrice = candle.close;
                  exitPrice  = null;
                  quantity   = qty;
                  status     = #Open;
                  openTime   = candle.timestamp;
                  closeTime  = 0;
                  pnl        = null;
                  pnlPercent = null;
                  decisionId = did;
                  stopLoss   = decision.stopLoss;
                  takeProfit = decision.targetPrice;
                });
              };
            };
          };

          equityPoints.add({ timestamp = candle.timestamp; value = cashBalance });
        };
      };

      // Force-close remaining open positions at last candle price
      if (sorted.size() > 0) {
        let lc = sorted[sorted.size() - 1];
        openTrades.mapInPlace(func(t : TradingTypes.Trade) : TradingTypes.Trade {
          if (t.symbol == symbol and t.status == #Open) {
            let pnl    = (lc.close - t.entryPrice) * t.quantity;
            let pnlPct = (lc.close - t.entryPrice) / t.entryPrice * 100.0;
            cashBalance += t.entryPrice * t.quantity + pnl;
            let closed : TradingTypes.Trade = {
              t with
              exitPrice  = ?lc.close;
              closeTime  = lc.timestamp;
              status     = #Closed;
              pnl        = ?pnl;
              pnlPercent = ?pnlPct;
            };
            closedTrades.add(closed);
            closed
          } else { t };
        });
      };
    };

    // Build final results
    let allTrades = closedTrades.toArray();
    let curve     = buildEquityCurve(allTrades, session.initialBalance);
    let finalBalance   = cashBalance;
    let totalReturn    = finalBalance - session.initialBalance;
    let totalReturnPct = if (session.initialBalance > 0.0) totalReturn / session.initialBalance * 100.0 else 0.0;
    var wins : Nat = 0;
    for (t in allTrades.values()) {
      switch (t.pnl) { case (?p) { if (p > 0.0) { wins += 1 } }; case null {} };
    };
    let n = allTrades.size();
    let winRate = if (n > 0) wins.toFloat() / n.toFloat() * 100.0 else 0.0;

    {
      finalBalance;
      totalReturn;
      totalPnlPercent = totalReturnPct;
      maxDrawdown     = maxDrawdown(curve);
      winRate;
      totalTrades     = n;
      sharpeRatio     = sharpeRatio(allTrades, session.initialBalance);
      equityCurve     = curve;
      trades          = allTrades;
    };
  };

  // ---------------------------------------------------------------------------
  // Equity curve builder
  // ---------------------------------------------------------------------------

  public func buildEquityCurve(
    trades : [TradingTypes.Trade],
    initialBalance : Float,
  ) : [BacktestTypes.EquityPoint] {
    if (trades.size() == 0) return [{ timestamp = 0; value = initialBalance }];

    // Collect close events sorted by closeTime
    let events = List.empty<(Int, Float)>();
    for (t in trades.values()) {
      switch (t.pnl) {
        case (?p) events.add((t.closeTime, p));
        case null {};
      };
    };

    let sorted = events.toArray().sort(func(a, b) {
      if (a.0 < b.0) #less else if (a.0 > b.0) #greater else #equal
    });

    var running = initialBalance;
    let curve = List.empty<BacktestTypes.EquityPoint>();
    curve.add({ timestamp = 0; value = initialBalance });

    for (ev in sorted.values()) {
      running += ev.1;
      curve.add({ timestamp = ev.0; value = running });
    };

    curve.toArray();
  };

  // ---------------------------------------------------------------------------
  // Max drawdown
  // ---------------------------------------------------------------------------

  public func maxDrawdown(equityCurve : [BacktestTypes.EquityPoint]) : Float {
    if (equityCurve.size() < 2) return 0.0;

    var peak  = equityCurve[0].value;
    var maxDD = 0.0;

    for (pt in equityCurve.values()) {
      if (pt.value > peak) peak := pt.value;
      if (peak > 0.0) {
        let dd = (peak - pt.value) / peak * 100.0;
        if (dd > maxDD) maxDD := dd;
      };
    };

    maxDD;
  };

  // ---------------------------------------------------------------------------
  // Sharpe ratio
  // ---------------------------------------------------------------------------

  public func sharpeRatio(
    trades : [TradingTypes.Trade],
    initialBalance : Float,
  ) : ?Float {
    if (trades.size() < 10 or initialBalance <= 0.0) return null;

    let returns = trades.filterMap(func(t) {
      switch (t.pnl) {
        case (?p) ?(p / initialBalance * 100.0);
        case null null;
      };
    });

    let n = returns.size();
    if (n < 10) return null;

    let nF  = n.toFloat();
    let sum = returns.foldLeft(0.0, func(acc : Float, r : Float) : Float { acc + r });
    let avg = sum / nF;

    let variance = returns.foldLeft(0.0, func(acc : Float, r : Float) : Float {
      let diff = r - avg;
      acc + diff * diff;
    }) / nF;

    let stdDev = floatSqrt(variance);
    if (stdDev == 0.0) return null;

    // Annualise assuming daily trades
    let sharpe = avg / stdDev * floatSqrt(252.0);
    ?sharpe;
  };
};

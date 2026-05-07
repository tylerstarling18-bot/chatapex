import List "mo:core/List";
import Array "mo:core/Array";
import Float "mo:core/Float";
import TradingTypes "../types/trading";
import ConfidenceTypes "../types/confidence";
import MarketTypes "../types/market";

// Paper trading execution and portfolio management logic
module {

  // Lookup price for a symbol from the prices array
  func lookupPrice(prices : [(Text, Float)], symbol : Text) : ?Float {
    switch (prices.find<(Text, Float)>(func((s, _)) { s == symbol })) {
      case (?(_, p)) ?p;
      case null null;
    };
  };

  // ---------------------------------------------------------------------------
  // Volatility and simulation helpers
  // ---------------------------------------------------------------------------

  // Compute volatility-adjusted position size from ATR/price ratio
  public func computeVolatilityPositionSize(atr : Float, price : Float, _baseSize : Float) : Float {
    if (price <= 0.0) return 0.02;
    let ratio = atr / price;
    if (ratio > 0.03) 0.005        // very high volatility -> 0.5%
    else if (ratio < 0.01) 0.02   // low volatility -> 2%
    else {
      // Lerp: ratio 0.03 -> size 0.005, ratio 0.01 -> size 0.02
      let t = (0.03 - ratio) / (0.03 - 0.01);
      0.005 + t * (0.02 - 0.005);
    };
  };

  // Deterministic slippage: 0.05-0.15% based on timestamp low bits
  public func simulateSlippage(price : Float, isBuy : Bool, ts : Int) : Float {
    let bps : Float = 0.0005 + ((ts % 10).toFloat() / 10.0) * 0.001;
    if (isBuy) price * bps else -(price * bps);
  };

  // Spread: 0.1% impact on entry
  public func simulateSpread(price : Float, isBuy : Bool) : Float {
    if (isBuy) price * 0.001 else -(price * 0.001);
  };

  // Fee: 0.1% of trade value
  public func simulateFee(tradeValue : Float) : Float {
    tradeValue * 0.001;
  };

  // ---------------------------------------------------------------------------
  // Open a new paper trade position
  // ---------------------------------------------------------------------------

  public func openTrade(
    trades    : List.List<TradingTypes.Trade>,
    decision  : TradingTypes.TradeDecision,
    portfolio : TradingTypes.Portfolio,
    now       : Int,
    tradeId   : Text,
  ) : (TradingTypes.Trade, TradingTypes.Portfolio) {
    switch (decision.action) {
      case (#Buy) {
        let rawPrice = decision.entryPrice;
        let atr = decision.indicators.atr;
        let sizeRatio = computeVolatilityPositionSize(atr, rawPrice, 0.02);
        let slipAmt   = simulateSlippage(rawPrice, true, now);
        let spreadAmt = simulateSpread(rawPrice, true);
        let entryPrice = rawPrice + slipAmt + spreadAmt;
        let quantity = if (entryPrice > 0.0) {
          (portfolio.cashBalance * sizeRatio) / entryPrice;
        } else { 0.0 };
        let tradeCost = quantity * entryPrice;
        let feeAmt    = simulateFee(tradeCost);
        let trade : TradingTypes.Trade = {
          id          = tradeId;
          symbol      = decision.symbol;
          action      = #Buy;
          entryPrice;
          exitPrice   = null;
          quantity;
          status      = #Open;
          openTime    = now;
          closeTime   = 0;
          pnl         = null;
          pnlPercent  = null;
          decisionId  = decision.id;
          stopLoss    = decision.stopLoss;
          takeProfit  = decision.targetPrice;
        };
        trades.add(trade);
        let newPortfolio : TradingTypes.Portfolio = {
          portfolio with
          cashBalance   = portfolio.cashBalance - tradeCost - feeAmt;
          investedValue = portfolio.investedValue + tradeCost;
          totalTrades   = portfolio.totalTrades + 1;
        };
        (trade, newPortfolio);
      };
      case (_) {
        let noopTrade : TradingTypes.Trade = {
          id          = tradeId;
          symbol      = decision.symbol;
          action      = decision.action;
          entryPrice  = decision.entryPrice;
          exitPrice   = null;
          quantity    = 0.0;
          status      = #Cancelled;
          openTime    = now;
          closeTime   = now;
          pnl         = null;
          pnlPercent  = null;
          decisionId  = decision.id;
          stopLoss    = decision.stopLoss;
          takeProfit  = decision.targetPrice;
        };
        (noopTrade, portfolio);
      };
    };
  };

  // ---------------------------------------------------------------------------
  // Build a TradeSnapshot capturing entry conditions and simulation costs
  // ---------------------------------------------------------------------------

  public func buildTradeSnapshot(
    trade      : TradingTypes.Trade,
    factors    : ConfidenceTypes.ConfidenceFactors,
    regime     : MarketTypes.MarketCondition,
    indicators : MarketTypes.TechnicalIndicators,
    reasoning  : Text,
    now        : Int,
  ) : ConfidenceTypes.TradeSnapshot {
    let rawPrice = trade.entryPrice;
    let slip     = simulateSlippage(rawPrice, true, now);
    let sprd     = simulateSpread(rawPrice, true);
    let tv       = rawPrice * trade.quantity;
    let feeAmt   = simulateFee(tv);
    let netImpact = if (rawPrice > 0.0 and trade.quantity > 0.0)
      (slip + sprd + feeAmt / trade.quantity) / rawPrice * 100.0
    else 0.0;
    let volRatio = if (rawPrice > 0.0) indicators.atr / rawPrice else 0.0;
    {
      tradeId             = trade.id;
      confidenceFactors   = factors;
      marketRegimeAtEntry = regime;
      volatilityRatio     = volRatio;
      indicatorsAtEntry   = indicators;
      aiReasoningText     = reasoning;
      simulatedSlippage   = slip;
      simulatedSpread     = sprd;
      simulatedFees       = feeAmt;
      simulatedLatencyMs  = 120;
      netImpactPct        = netImpact;
      tags                = [];
    };
  };

  // ---------------------------------------------------------------------------
  // Close a specific trade by ID at the given exit price
  // ---------------------------------------------------------------------------

  public func closeTrade(
    trades    : List.List<TradingTypes.Trade>,
    tradeId   : Text,
    exitPrice : Float,
    status    : TradingTypes.TradeStatus,
    now       : Int,
  ) : ?TradingTypes.Trade {
    var closedTrade : ?TradingTypes.Trade = null;
    trades.mapInPlace(func(t : TradingTypes.Trade) : TradingTypes.Trade {
      if (t.id == tradeId and t.status == #Open) {
        let pnl = (exitPrice - t.entryPrice) * t.quantity;
        let pnlPct = if (t.entryPrice > 0.0) {
          ((exitPrice - t.entryPrice) / t.entryPrice) * 100.0;
        } else { 0.0 };
        let closed : TradingTypes.Trade = {
          t with
          exitPrice  = ?exitPrice;
          status;
          closeTime  = now;
          pnl        = ?pnl;
          pnlPercent = ?pnlPct;
        };
        closedTrade := ?closed;
        closed;
      } else { t };
    });
    closedTrade;
  };

  // Close an open position for a symbol at current price
  public func closePosition(
    trades       : List.List<TradingTypes.Trade>,
    symbol       : Text,
    currentPrice : Float,
    now          : Int,
  ) : ?TradingTypes.Trade {
    var found : ?TradingTypes.Trade = null;
    trades.mapInPlace(func(t : TradingTypes.Trade) : TradingTypes.Trade {
      if (t.symbol == symbol and t.status == #Open and found == null) {
        let pnl = (currentPrice - t.entryPrice) * t.quantity;
        let pnlPct = if (t.entryPrice > 0.0) {
          ((currentPrice - t.entryPrice) / t.entryPrice) * 100.0;
        } else { 0.0 };
        let closed : TradingTypes.Trade = {
          t with
          exitPrice  = ?currentPrice;
          status     = #Closed;
          closeTime  = now;
          pnl        = ?pnl;
          pnlPercent = ?pnlPct;
        };
        found := ?closed;
        closed;
      } else { t };
    });
    found;
  };

  // Apply stop-loss and take-profit checks to all open positions
  public func checkStopsAndTargets(
    trades       : List.List<TradingTypes.Trade>,
    latestPrices : [(Text, Float)],
    now          : Int,
  ) : [TradingTypes.Trade] {
    let closed = List.empty<TradingTypes.Trade>();
    trades.mapInPlace(func(t : TradingTypes.Trade) : TradingTypes.Trade {
      if (t.status != #Open) { return t };
      switch (lookupPrice(latestPrices, t.symbol)) {
        case null { t };
        case (?price) {
          let hitStop   = price <= t.stopLoss;
          let hitTarget = switch (t.takeProfit) {
            case (?tp) price >= tp;
            case null false;
          };
          if (hitStop or hitTarget) {
            let newStatus : TradingTypes.TradeStatus = if (hitStop) #StopLossHit else #TakeProfitHit;
            let pnl    = (price - t.entryPrice) * t.quantity;
            let pnlPct = if (t.entryPrice > 0.0) {
              ((price - t.entryPrice) / t.entryPrice) * 100.0;
            } else { 0.0 };
            let updated : TradingTypes.Trade = {
              t with
              exitPrice  = ?price;
              status     = newStatus;
              closeTime  = now;
              pnl        = ?pnl;
              pnlPercent = ?pnlPct;
            };
            closed.add(updated);
            updated;
          } else { t };
        };
      };
    });
    closed.toArray();
  };

  // Recompute portfolio state from current trades and prices
  public func computePortfolio(
    trades         : List.List<TradingTypes.Trade>,
    latestPrices   : [(Text, Float)],
    initialBalance : Float,
  ) : TradingTypes.Portfolio {
    var cash = initialBalance;
    var totalWins : Nat = 0;
    var totalClosed : Nat = 0;
    var totalPnl = 0.0;
    var dayPnl = 0.0;
    let openTrades = List.empty<TradingTypes.Trade>();

    trades.forEach(func(t : TradingTypes.Trade) {
      switch (t.status) {
        case (#Open) {
          cash -= t.entryPrice * t.quantity;
          openTrades.add(t);
        };
        case (_) {
          cash += t.entryPrice * t.quantity;
          switch (t.pnl) {
            case (?p) {
              totalPnl += p;
              dayPnl += p;
              if (p > 0.0) { totalWins += 1 };
              totalClosed += 1;
            };
            case null {};
          };
        };
      };
    });

    let positions = getOpenPositions(trades, latestPrices);
    let investedValue = positions.foldLeft(
      0.0,
      func(acc, pos) { acc + pos.currentPrice * pos.quantity },
    );
    let totalValue = cash + investedValue;
    let totalPnlPercent = if (initialBalance > 0.0) {
      (totalPnl / initialBalance) * 100.0;
    } else { 0.0 };
    let dayPnlPercent = if (initialBalance > 0.0) {
      (dayPnl / initialBalance) * 100.0;
    } else { 0.0 };
    let winRate = if (totalClosed > 0) {
      (totalWins.toFloat() / totalClosed.toFloat()) * 100.0;
    } else { 0.0 };

    {
      totalValue;
      cashBalance   = cash;
      investedValue;
      totalPnl;
      totalPnlPercent;
      dayPnl;
      dayPnlPercent;
      winRate;
      totalTrades   = trades.size();
      winningTrades = totalWins;
      positions;
    };
  };

  // Get all open positions grouped by symbol
  public func getOpenPositions(
    trades       : List.List<TradingTypes.Trade>,
    latestPrices : [(Text, Float)],
  ) : [TradingTypes.Position] {
    trades.filter(func(t : TradingTypes.Trade) : Bool { t.status == #Open })
    .toArray()
    |> _.map<TradingTypes.Trade, TradingTypes.Position>(
      func(t) {
        let currentPrice = switch (lookupPrice(latestPrices, t.symbol)) {
          case (?p) p;
          case null t.entryPrice;
        };
        let unrealizedPnl = (currentPrice - t.entryPrice) * t.quantity;
        let unrealizedPnlPercent = if (t.entryPrice > 0.0) {
          ((currentPrice - t.entryPrice) / t.entryPrice) * 100.0;
        } else { 0.0 };
        {
          symbol               = t.symbol;
          quantity             = t.quantity;
          averageEntryPrice    = t.entryPrice;
          currentPrice;
          unrealizedPnl;
          unrealizedPnlPercent;
          openTime             = t.openTime;
          stopLoss             = t.stopLoss;
          takeProfit           = t.takeProfit;
        };
      },
    );
  };
};

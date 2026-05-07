// Multi-Agent Simulation Engine
// Runs multiple strategy agents in parallel with realistic market simulation

export type AgentStrategy =
  | "TrendFollowing"
  | "MeanReversion"
  | "Scalping"
  | "Defensive"
  | "Momentum";

export type SimTradeAction = "BUY" | "SELL" | "HOLD";

export interface OHLCV {
  timestamp: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface SimIndicators {
  rsi: number;
  macd: number;
  macdSignal: number;
  ema20: number;
  ema50: number;
  atr: number;
  bollingerUpper: number;
  bollingerMid: number;
  bollingerLower: number;
  momentum: number;
}

export interface SimTrade {
  id: string;
  agentId: string;
  symbol: string;
  action: SimTradeAction;
  entryPrice: number;
  exitPrice?: number;
  quantity: number;
  entryTime: number;
  exitTime?: number;
  pnl?: number;
  pnlPct?: number;
  stopLoss: number;
  takeProfit: number;
  status: "open" | "closed" | "stopped" | "target_hit" | "rejected";
  rejectReason?: string;
  indicators: SimIndicators;
  confidence: number;
}

export interface AgentState {
  id: string;
  strategy: AgentStrategy;
  balance: number;
  equity: number;
  positions: Map<string, SimTrade>;
  trades: SimTrade[];
  wins: number;
  losses: number;
  maxDrawdown: number;
  peakEquity: number;
  equityCurve: { time: number; value: number }[];
  rejectedTrades: SimTrade[];
}

export interface SimulationConfig {
  initialBalance: number;
  symbol: string;
  startIndex: number;
  endIndex: number;
  slippagePct: number;
  feePct: number;
  maxPositionSizePct: number;
}

export interface SimulationResult {
  agent: AgentState;
  totalReturn: number;
  winRate: number;
  sharpeRatio: number;
  maxDrawdown: number;
  totalTrades: number;
  rejectedCount: number;
}

// ─── Indicator Calculations ───────────────────────────────────────────────────

function ema(values: number[], period: number): number[] {
  const k = 2 / (period + 1);
  const result: number[] = [];
  let prev = values.slice(0, period).reduce((a, b) => a + b, 0) / period;
  for (let i = 0; i < period - 1; i++) result.push(prev);
  for (let i = period - 1; i < values.length; i++) {
    prev = values[i] * k + prev * (1 - k);
    result.push(prev);
  }
  return result;
}

function rsi(closes: number[], period = 14): number[] {
  const gains: number[] = [];
  const losses: number[] = [];
  for (let i = 1; i < closes.length; i++) {
    const diff = closes[i] - closes[i - 1];
    gains.push(diff > 0 ? diff : 0);
    losses.push(diff < 0 ? -diff : 0);
  }
  const result: number[] = new Array(period).fill(50);
  let avgGain = gains.slice(0, period).reduce((a, b) => a + b, 0) / period;
  let avgLoss = losses.slice(0, period).reduce((a, b) => a + b, 0) / period;
  for (let i = period; i < gains.length; i++) {
    avgGain = (avgGain * (period - 1) + gains[i]) / period;
    avgLoss = (avgLoss * (period - 1) + losses[i]) / period;
    const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
    result.push(100 - 100 / (1 + rs));
  }
  return result;
}

function atr(candles: OHLCV[], period = 14): number[] {
  const trs: number[] = [candles[0].high - candles[0].low];
  for (let i = 1; i < candles.length; i++) {
    const c = candles[i];
    const prev = candles[i - 1].close;
    trs.push(
      Math.max(c.high - c.low, Math.abs(c.high - prev), Math.abs(c.low - prev)),
    );
  }
  const result: number[] = new Array(period).fill(trs[0]);
  let avg = trs.slice(0, period).reduce((a, b) => a + b, 0) / period;
  for (let i = period; i < trs.length; i++) {
    avg = (avg * (period - 1) + trs[i]) / period;
    result.push(avg);
  }
  return result;
}

function bollingerBands(closes: number[], period = 20, stdDev = 2) {
  const mid: number[] = [];
  const upper: number[] = [];
  const lower: number[] = [];
  for (let i = 0; i < closes.length; i++) {
    if (i < period - 1) {
      mid.push(closes[i]);
      upper.push(closes[i]);
      lower.push(closes[i]);
      continue;
    }
    const slice = closes.slice(i - period + 1, i + 1);
    const mean = slice.reduce((a, b) => a + b, 0) / period;
    const variance = slice.reduce((a, b) => a + (b - mean) ** 2, 0) / period;
    const std = Math.sqrt(variance);
    mid.push(mean);
    upper.push(mean + stdDev * std);
    lower.push(mean - stdDev * std);
  }
  return { mid, upper, lower };
}

export function computeIndicators(candles: OHLCV[]): SimIndicators[] {
  const closes = candles.map((c) => c.close);
  const ema20s = ema(closes, 20);
  const ema50s = ema(closes, 50);
  const ema12s = ema(closes, 12);
  const ema26s = ema(closes, 26);
  const rsiVals = rsi(closes, 14);
  const atrVals = atr(candles, 14);
  const bb = bollingerBands(closes, 20);

  return candles.map((_, i) => {
    const macdLine = ema12s[i] - ema26s[i];
    const signalLine =
      i >= 9
        ? ema(
            closes.slice(0, i + 1).map((_, j) => ema12s[j] - ema26s[j]),
            9,
          ).slice(-1)[0]
        : 0;
    return {
      rsi: rsiVals[i] ?? 50,
      macd: macdLine,
      macdSignal: signalLine,
      ema20: ema20s[i],
      ema50: ema50s[i],
      atr: atrVals[i],
      bollingerUpper: bb.upper[i],
      bollingerMid: bb.mid[i],
      bollingerLower: bb.lower[i],
      momentum: i >= 10 ? (closes[i] / closes[i - 10] - 1) * 100 : 0,
    };
  });
}

// ─── Strategy Signal Generators ──────────────────────────────────────────────

interface Signal {
  action: SimTradeAction;
  confidence: number;
  reason: string;
}

function trendFollowingSignal(ind: SimIndicators): Signal {
  const bullish =
    ind.ema20 > ind.ema50 &&
    ind.rsi > 50 &&
    ind.rsi < 70 &&
    ind.macd > ind.macdSignal;
  const bearish =
    ind.ema20 < ind.ema50 &&
    ind.rsi < 50 &&
    ind.rsi > 30 &&
    ind.macd < ind.macdSignal;
  if (bullish) {
    const conf = Math.min(
      95,
      55 + (ind.rsi - 50) * 0.8 + (ind.momentum > 0 ? 5 : 0),
    );
    return {
      action: "BUY",
      confidence: conf,
      reason: "EMA cross + MACD bullish",
    };
  }
  if (bearish) {
    const conf = Math.min(95, 55 + (50 - ind.rsi) * 0.8);
    return {
      action: "SELL",
      confidence: conf,
      reason: "EMA cross + MACD bearish",
    };
  }
  return { action: "HOLD", confidence: 40, reason: "No trend signal" };
}

function meanReversionSignal(ind: SimIndicators): Signal {
  const oversold = ind.rsi < 30 && ind.bollingerLower > 0;
  const overbought = ind.rsi > 70;
  if (oversold) {
    const conf = Math.min(95, 60 + (30 - ind.rsi) * 1.2);
    return {
      action: "BUY",
      confidence: conf,
      reason: "RSI oversold + Bollinger bounce",
    };
  }
  if (overbought) {
    const conf = Math.min(95, 60 + (ind.rsi - 70) * 1.2);
    return {
      action: "SELL",
      confidence: conf,
      reason: "RSI overbought + Bollinger upper",
    };
  }
  return { action: "HOLD", confidence: 35, reason: "Price in mid-band" };
}

function scalpingSignal(ind: SimIndicators): Signal {
  const momentumBuy = ind.momentum > 1.5 && ind.rsi > 45 && ind.rsi < 65;
  const momentumSell = ind.momentum < -1.5 && ind.rsi > 35 && ind.rsi < 55;
  if (momentumBuy) {
    return { action: "BUY", confidence: 62, reason: "Short momentum burst" };
  }
  if (momentumSell) {
    return {
      action: "SELL",
      confidence: 62,
      reason: "Negative momentum scalp",
    };
  }
  return { action: "HOLD", confidence: 30, reason: "No scalp setup" };
}

function defensiveSignal(ind: SimIndicators): Signal {
  const safeEntry =
    ind.rsi > 40 && ind.rsi < 60 && ind.atr < ind.bollingerMid * 0.03;
  if (safeEntry && ind.macd > 0) {
    return { action: "BUY", confidence: 58, reason: "Low volatility buy" };
  }
  return {
    action: "HOLD",
    confidence: 50,
    reason: "Waiting for low-vol entry",
  };
}

function momentumSignal(ind: SimIndicators): Signal {
  const strongBull =
    ind.momentum > 3 && ind.macd > ind.macdSignal && ind.rsi < 75;
  const strongBear =
    ind.momentum < -3 && ind.macd < ind.macdSignal && ind.rsi > 25;
  if (strongBull) {
    const conf = Math.min(95, 65 + ind.momentum * 2);
    return {
      action: "BUY",
      confidence: conf,
      reason: "Strong positive momentum",
    };
  }
  if (strongBear) {
    const conf = Math.min(95, 65 + Math.abs(ind.momentum) * 2);
    return {
      action: "SELL",
      confidence: conf,
      reason: "Strong negative momentum",
    };
  }
  return { action: "HOLD", confidence: 38, reason: "Momentum below threshold" };
}

function getSignal(strategy: AgentStrategy, ind: SimIndicators): Signal {
  switch (strategy) {
    case "TrendFollowing":
      return trendFollowingSignal(ind);
    case "MeanReversion":
      return meanReversionSignal(ind);
    case "Scalping":
      return scalpingSignal(ind);
    case "Defensive":
      return defensiveSignal(ind);
    case "Momentum":
      return momentumSignal(ind);
  }
}

// ─── Simulation Engine ────────────────────────────────────────────────────────

function makeId(): string {
  return Math.random().toString(36).slice(2, 10);
}

function applySlippage(
  price: number,
  action: SimTradeAction,
  slippagePct: number,
): number {
  const slip = price * (slippagePct / 100);
  return action === "BUY" ? price + slip : price - slip;
}

export function runAgentSimulation(
  candles: OHLCV[],
  strategy: AgentStrategy,
  config: SimulationConfig,
): SimulationResult {
  const indicators = computeIndicators(candles);
  const agentId = `${strategy}-Agent`;

  const agent: AgentState = {
    id: agentId,
    strategy,
    balance: config.initialBalance,
    equity: config.initialBalance,
    positions: new Map(),
    trades: [],
    wins: 0,
    losses: 0,
    maxDrawdown: 0,
    peakEquity: config.initialBalance,
    equityCurve: [
      { time: candles[0]?.timestamp ?? 0, value: config.initialBalance },
    ],
    rejectedTrades: [],
  };

  const CONFIDENCE_THRESHOLD = strategy === "Defensive" ? 55 : 60;

  for (let i = 50; i < candles.length; i++) {
    const candle = candles[i];
    const ind = indicators[i];
    const price = candle.close;

    // Update open positions
    for (const [sym, pos] of agent.positions) {
      const currentPrice = price;
      // Check stop loss
      if (currentPrice <= pos.stopLoss) {
        const exitPrice = applySlippage(
          pos.stopLoss,
          "SELL",
          config.slippagePct,
        );
        const fee = exitPrice * pos.quantity * (config.feePct / 100);
        const pnl = (exitPrice - pos.entryPrice) * pos.quantity - fee;
        pos.exitPrice = exitPrice;
        pos.exitTime = candle.timestamp;
        pos.pnl = pnl;
        pos.pnlPct = (pnl / (pos.entryPrice * pos.quantity)) * 100;
        pos.status = "stopped";
        agent.balance += exitPrice * pos.quantity - fee;
        if (pnl < 0) agent.losses++;
        else agent.wins++;
        agent.trades.push({ ...pos });
        agent.positions.delete(sym);
        continue;
      }
      // Check take profit
      if (currentPrice >= pos.takeProfit) {
        const exitPrice = applySlippage(
          pos.takeProfit,
          "SELL",
          config.slippagePct,
        );
        const fee = exitPrice * pos.quantity * (config.feePct / 100);
        const pnl = (exitPrice - pos.entryPrice) * pos.quantity - fee;
        pos.exitPrice = exitPrice;
        pos.exitTime = candle.timestamp;
        pos.pnl = pnl;
        pos.pnlPct = (pnl / (pos.entryPrice * pos.quantity)) * 100;
        pos.status = "target_hit";
        agent.balance += exitPrice * pos.quantity - fee;
        agent.wins++;
        agent.trades.push({ ...pos });
        agent.positions.delete(sym);
        continue;
      }
      // Update unrealized equity
      const unrealized = (currentPrice - pos.entryPrice) * pos.quantity;
      agent.equity = agent.balance + unrealized;
    }

    // Update equity and drawdown
    agent.equity = agent.balance;
    for (const pos of agent.positions.values()) {
      agent.equity += (price - pos.entryPrice) * pos.quantity;
    }
    if (agent.equity > agent.peakEquity) agent.peakEquity = agent.equity;
    const drawdown =
      ((agent.peakEquity - agent.equity) / agent.peakEquity) * 100;
    if (drawdown > agent.maxDrawdown) agent.maxDrawdown = drawdown;
    agent.equityCurve.push({ time: candle.timestamp, value: agent.equity });

    // Generate signal
    const signal = getSignal(strategy, ind);
    if (signal.action === "HOLD" || signal.confidence < CONFIDENCE_THRESHOLD)
      continue;
    if (agent.positions.has(config.symbol)) continue; // one position at a time

    if (signal.action === "BUY") {
      const maxAlloc = agent.balance * (config.maxPositionSizePct / 100);
      const entryPrice = applySlippage(price, "BUY", config.slippagePct);
      const fee = entryPrice * (config.feePct / 100);
      const cost = entryPrice + fee;

      // Rejection checks
      if (maxAlloc < cost * 0.01) {
        agent.rejectedTrades.push({
          id: makeId(),
          agentId,
          symbol: config.symbol,
          action: "BUY",
          entryPrice: price,
          quantity: 0,
          entryTime: candle.timestamp,
          stopLoss: 0,
          takeProfit: 0,
          status: "rejected",
          rejectReason: "Insufficient balance",
          indicators: ind,
          confidence: signal.confidence,
        });
        continue;
      }

      const quantity = maxAlloc / cost;
      const stopLoss = entryPrice - ind.atr * 2;
      const takeProfit = entryPrice + ind.atr * 3;

      agent.balance -= entryPrice * quantity + fee * quantity;
      const trade: SimTrade = {
        id: makeId(),
        agentId,
        symbol: config.symbol,
        action: "BUY",
        entryPrice,
        quantity,
        entryTime: candle.timestamp,
        stopLoss,
        takeProfit,
        status: "open",
        indicators: ind,
        confidence: signal.confidence,
      };
      agent.positions.set(config.symbol, trade);
    }
  }

  // Close remaining open positions at last price
  const lastCandle = candles[candles.length - 1];
  for (const [sym, pos] of agent.positions) {
    const exitPrice = applySlippage(
      lastCandle.close,
      "SELL",
      config.slippagePct,
    );
    const fee = exitPrice * pos.quantity * (config.feePct / 100);
    const pnl = (exitPrice - pos.entryPrice) * pos.quantity - fee;
    pos.exitPrice = exitPrice;
    pos.exitTime = lastCandle.timestamp;
    pos.pnl = pnl;
    pos.pnlPct = (pnl / (pos.entryPrice * pos.quantity)) * 100;
    pos.status = "closed";
    agent.balance += exitPrice * pos.quantity - fee;
    if (pnl < 0) agent.losses++;
    else agent.wins++;
    agent.trades.push({ ...pos });
    agent.positions.delete(sym);
  }

  agent.equity = agent.balance;

  const totalTrades = agent.trades.length;
  const winRate = totalTrades > 0 ? agent.wins / totalTrades : 0;
  const totalReturn =
    ((agent.equity - config.initialBalance) / config.initialBalance) * 100;

  // Sharpe ratio approximation
  const returns = agent.trades
    .filter((t) => t.pnl !== undefined)
    .map((t) => t.pnlPct ?? 0);
  const avgReturn =
    returns.length > 0
      ? returns.reduce((a, b) => a + b, 0) / returns.length
      : 0;
  const stdReturn =
    returns.length > 1
      ? Math.sqrt(
          returns.reduce((a, b) => a + (b - avgReturn) ** 2, 0) /
            (returns.length - 1),
        )
      : 1;
  const sharpeRatio =
    stdReturn > 0 ? (avgReturn / stdReturn) * Math.sqrt(252) : 0;

  return {
    agent,
    totalReturn,
    winRate,
    sharpeRatio,
    maxDrawdown: agent.maxDrawdown,
    totalTrades,
    rejectedCount: agent.rejectedTrades.length,
  };
}

// Run all strategies and return sorted leaderboard
export function runMultiAgentSimulation(
  candles: OHLCV[],
  config: Omit<SimulationConfig, "symbol"> & { symbol: string },
): SimulationResult[] {
  const strategies: AgentStrategy[] = [
    "TrendFollowing",
    "MeanReversion",
    "Scalping",
    "Defensive",
    "Momentum",
  ];
  const results = strategies.map((s) => runAgentSimulation(candles, s, config));
  return results.sort((a, b) => b.totalReturn - a.totalReturn);
}

// Generate synthetic candles for demo/testing purposes
export function generateSyntheticCandles(
  _symbol: string,
  days = 180,
  startPrice = 45000,
): OHLCV[] {
  const candles: OHLCV[] = [];
  let price = startPrice;
  const now = Date.now();
  const msPerDay = 86_400_000;
  let trend = 0.0003; // slight upward drift

  for (let i = days; i >= 0; i--) {
    const t = now - i * msPerDay;
    const dailyVol = 0.025 + Math.random() * 0.02;
    const change = (Math.random() - 0.495) * dailyVol * 2 + trend;
    price = Math.max(price * (1 + change), startPrice * 0.3);

    // Occasional regime shifts
    if (Math.random() < 0.05) trend = (Math.random() - 0.5) * 0.001;

    const range = price * dailyVol;
    const open = price * (1 + (Math.random() - 0.5) * 0.005);
    const high = Math.max(open, price) + Math.random() * range * 0.5;
    const low = Math.min(open, price) - Math.random() * range * 0.5;
    const volume = 1e8 + Math.random() * 5e8;

    candles.push({
      timestamp: t,
      open,
      high,
      low,
      close: price,
      volume,
    });
  }
  return candles;
}

// Convert backend Candle format to OHLCV
export function backendCandlesToOHLCV(
  candles: Array<{
    timestamp: bigint;
    open: number;
    high: number;
    low: number;
    close: number;
    volume: number;
  }>,
): OHLCV[] {
  return candles.map((c) => ({
    timestamp: Number(c.timestamp) / 1_000_000, // ns to ms
    open: c.open,
    high: c.high,
    low: c.low,
    close: c.close,
    volume: c.volume,
  }));
}

import {
  Activity,
  Award,
  BarChart2,
  ChevronDown,
  ChevronUp,
  PlayCircle,
  RefreshCw,
  TrendingDown,
  TrendingUp,
  XCircle,
} from "lucide-react";
import { useCallback, useMemo, useRef, useState } from "react";
import {
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Button } from "../components/Button";
import { SectionHeader } from "../components/SectionHeader";
import { StatCard } from "../components/StatCard";
import { fmtPct, fmtUSD, pctColor } from "../lib/format";
import {
  type AgentStrategy,
  type OHLCV,
  type SimTrade,
  type SimulationResult,
  backendCandlesToOHLCV,
  generateSyntheticCandles,
  runMultiAgentSimulation,
} from "../lib/tradingEngine";

const SYMBOLS = ["BTC", "ETH", "SOL", "BNB", "ADA"];

const STRATEGY_COLORS: Record<AgentStrategy, string> = {
  TrendFollowing: "#7c3aed",
  MeanReversion: "#0ea5e9",
  Scalping: "#f59e0b",
  Defensive: "#10b981",
  Momentum: "#f43f5e",
};

const STRATEGY_DESC: Record<AgentStrategy, string> = {
  TrendFollowing: "EMA crossover + MACD alignment",
  MeanReversion: "RSI extremes + Bollinger band touch",
  Scalping: "Short momentum bursts, quick exits",
  Defensive: "Low-volatility selective entries",
  Momentum: "Strong momentum confirmation",
};

function RankBadge({ rank }: { rank: number }) {
  const styles = [
    "bg-yellow-500/20 text-yellow-300 border border-yellow-500/40",
    "bg-zinc-400/20 text-zinc-300 border border-zinc-500/40",
    "bg-orange-700/20 text-orange-400 border border-orange-600/40",
  ];
  const emojis = ["🥇", "🥈", "🥉"];
  const cls =
    rank <= 3
      ? styles[rank - 1]
      : "bg-zinc-800 text-zinc-500 border border-zinc-700";
  return (
    <span
      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs font-semibold ${cls}`}
    >
      {rank <= 3 ? emojis[rank - 1] : `#${rank}`}
    </span>
  );
}

function TradeRow({ trade, idx }: { trade: SimTrade; idx: number }) {
  const [expanded, setExpanded] = useState(false);
  const pnl = trade.pnl ?? 0;
  const isRejected = trade.status === "rejected";
  return (
    <>
      <tr
        className={`border-b border-zinc-800/40 text-xs cursor-pointer ${
          isRejected ? "opacity-60" : "hover:bg-zinc-800/20"
        }`}
        onClick={() => setExpanded((e) => !e)}
        onKeyDown={(e) =>
          (e.key === "Enter" || e.key === " ") && setExpanded((ex) => !ex)
        }
        tabIndex={0}
        data-ocid={`simulator.trade_log.item.${idx + 1}`}
      >
        <td className="py-2 px-3 text-zinc-500 font-mono">{idx + 1}</td>
        <td className="py-2 px-3">
          <span
            className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-xs font-medium ${
              isRejected
                ? "bg-zinc-700 text-zinc-500"
                : trade.action === "BUY"
                  ? "bg-emerald-500/20 text-emerald-400"
                  : "bg-red-500/20 text-red-400"
            }`}
          >
            {isRejected ? "REJECTED" : trade.action}
          </span>
        </td>
        <td className="py-2 px-3 text-zinc-300 font-mono">
          {fmtUSD(trade.entryPrice)}
        </td>
        <td className="py-2 px-3 text-zinc-400 font-mono">
          {trade.exitPrice != null ? fmtUSD(trade.exitPrice) : "open"}
        </td>
        <td className={`py-2 px-3 font-medium ${pctColor(pnl)}`}>
          {trade.pnl != null ? fmtUSD(trade.pnl) : isRejected ? "—" : "open"}
        </td>
        <td className="py-2 px-3 text-zinc-400">
          {trade.confidence.toFixed(0)}%
        </td>
        <td className="py-2 px-3 text-zinc-500">
          {expanded ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
        </td>
      </tr>
      {expanded && (
        <tr className="border-b border-zinc-800/40 bg-zinc-950">
          <td colSpan={7} className="px-3 py-2">
            <div className="grid grid-cols-3 gap-4 text-xs text-zinc-500">
              <div>
                <p className="text-zinc-600 mb-0.5">Indicators</p>
                <p>
                  RSI:{" "}
                  <span className="text-zinc-300">
                    {trade.indicators.rsi.toFixed(1)}
                  </span>
                </p>
                <p>
                  MACD:{" "}
                  <span className="text-zinc-300">
                    {trade.indicators.macd.toFixed(4)}
                  </span>
                </p>
                <p>
                  EMA20:{" "}
                  <span className="text-zinc-300">
                    {fmtUSD(trade.indicators.ema20)}
                  </span>
                </p>
              </div>
              <div>
                <p className="text-zinc-600 mb-0.5">Risk Levels</p>
                <p>
                  Stop Loss:{" "}
                  <span className="text-red-400">{fmtUSD(trade.stopLoss)}</span>
                </p>
                <p>
                  Take Profit:{" "}
                  <span className="text-emerald-400">
                    {fmtUSD(trade.takeProfit)}
                  </span>
                </p>
                <p>
                  ATR:{" "}
                  <span className="text-zinc-300">
                    {trade.indicators.atr.toFixed(2)}
                  </span>
                </p>
              </div>
              <div>
                <p className="text-zinc-600 mb-0.5">Trade Info</p>
                <p>
                  Status:{" "}
                  <span className="text-zinc-300 capitalize">
                    {trade.status.replace("_", " ")}
                  </span>
                </p>
                <p>
                  Qty:{" "}
                  <span className="text-zinc-300">
                    {trade.quantity.toFixed(6)}
                  </span>
                </p>
                {isRejected && (
                  <p>
                    Reason:{" "}
                    <span className="text-red-400">{trade.rejectReason}</span>
                  </p>
                )}
              </div>
            </div>
          </td>
        </tr>
      )}
    </>
  );
}

export function SimulatorPage() {
  const [symbol, setSymbol] = useState<string>("BTC");
  const [days, setDays] = useState<number>(180);
  const [initialBalance, setInitialBalance] = useState<number>(10000);
  const [isRunning, setIsRunning] = useState(false);
  const [results, setResults] = useState<SimulationResult[] | null>(null);
  const [selectedAgent, setSelectedAgent] = useState<string | null>(null);
  const [tradeTab, setTradeTab] = useState<"trades" | "rejected">("trades");
  const candles = useRef<OHLCV[]>([]);

  const runSimulation = useCallback(async () => {
    setIsRunning(true);
    setResults(null);
    setSelectedAgent(null);

    // Short async yield for UI update
    await new Promise((r) => setTimeout(r, 50));

    const startPrice =
      symbol === "BTC"
        ? 45000
        : symbol === "ETH"
          ? 2500
          : symbol === "SOL"
            ? 100
            : symbol === "BNB"
              ? 300
              : 0.5;
    const syntheticCandles = generateSyntheticCandles(symbol, days, startPrice);
    candles.current = syntheticCandles;

    const simResults = runMultiAgentSimulation(syntheticCandles, {
      symbol,
      initialBalance,
      startIndex: 0,
      endIndex: syntheticCandles.length - 1,
      slippagePct: 0.05,
      feePct: 0.1,
      maxPositionSizePct: 95,
    });

    setResults(simResults);
    setSelectedAgent(simResults[0]?.agent.id ?? null);
    setIsRunning(false);
  }, [symbol, days, initialBalance]);

  const selectedResult = useMemo(
    () => results?.find((r) => r.agent.id === selectedAgent) ?? null,
    [results, selectedAgent],
  );

  // Build combined equity curve for chart
  const equityChartData = useMemo(() => {
    if (!results) return [];
    const timeSet = new Set<number>();
    for (const r of results) {
      for (const pt of r.agent.equityCurve) timeSet.add(pt.time);
    }
    const times = [...timeSet].sort((a, b) => a - b);
    return times.map((t) => {
      const point: Record<string, number> = { t };
      for (const r of results) {
        const pt = r.agent.equityCurve.findLast((p) => p.time <= t);
        if (pt) point[r.agent.strategy] = pt.value;
      }
      return point;
    });
  }, [results]);

  const activeTrades =
    selectedResult?.agent.trades.filter((t) => t.status !== "rejected") ?? [];
  const rejectedTrades = selectedResult?.agent.rejectedTrades ?? [];

  return (
    <div className="p-6 space-y-6" data-ocid="simulator.page">
      <SectionHeader
        title="Multi-Agent Simulator"
        description="Run 5 AI strategy agents simultaneously and compare performance"
        actions={
          <Button
            onClick={runSimulation}
            loading={isRunning}
            data-ocid="simulator.run_button"
          >
            <PlayCircle size={14} />
            {isRunning ? "Simulating…" : "Run Simulation"}
          </Button>
        }
      />

      {/* Config */}
      <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
        <h3 className="text-sm font-semibold text-zinc-200 mb-3">
          Simulation Config
        </h3>
        <div className="flex flex-wrap gap-4 items-end">
          <div>
            <label
              htmlFor="simSymbol"
              className="text-xs text-zinc-500 block mb-1"
            >
              Symbol
            </label>
            <select
              id="simSymbol"
              value={symbol}
              onChange={(e) => setSymbol(e.target.value)}
              className="rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              data-ocid="simulator.symbol_select"
            >
              {SYMBOLS.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label
              htmlFor="simDays"
              className="text-xs text-zinc-500 block mb-1"
            >
              Days of History
            </label>
            <select
              id="simDays"
              value={days}
              onChange={(e) => setDays(Number(e.target.value))}
              className="rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              data-ocid="simulator.days_select"
            >
              {[30, 60, 90, 180, 365].map((d) => (
                <option key={d} value={d}>
                  {d} days
                </option>
              ))}
            </select>
          </div>
          <div>
            <label
              htmlFor="simBalance"
              className="text-xs text-zinc-500 block mb-1"
            >
              Initial Balance (USD)
            </label>
            <input
              id="simBalance"
              type="number"
              value={initialBalance}
              onChange={(e) => setInitialBalance(Number(e.target.value))}
              className="w-32 rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              data-ocid="simulator.balance_input"
            />
          </div>
          <Button
            onClick={runSimulation}
            loading={isRunning}
            variant="secondary"
            size="sm"
            data-ocid="simulator.run_button_2"
          >
            <RefreshCw size={12} />
            {isRunning ? "Running…" : "Re-run"}
          </Button>
        </div>
      </div>

      {!results && !isRunning && (
        <div
          className="flex flex-col items-center justify-center rounded-xl border border-zinc-800 bg-zinc-900 py-20 space-y-3"
          data-ocid="simulator.empty_state"
        >
          <BarChart2 size={40} className="text-zinc-700" />
          <p className="text-zinc-500 text-sm">
            Click "Run Simulation" to pit 5 AI strategies against each other
          </p>
          <Button
            onClick={runSimulation}
            loading={isRunning}
            data-ocid="simulator.start_button"
          >
            <PlayCircle size={14} /> Start Simulation
          </Button>
        </div>
      )}

      {isRunning && (
        <div className="flex flex-col items-center justify-center rounded-xl border border-zinc-800 bg-zinc-900 py-20 space-y-3">
          <div className="w-8 h-8 rounded-full border-2 border-violet-500 border-t-transparent animate-spin" />
          <p className="text-zinc-500 text-sm">
            Running 5-agent simulation on {days} days of {symbol} data…
          </p>
        </div>
      )}

      {results && (
        <>
          {/* Agent Leaderboard */}
          <div
            className="rounded-xl border border-zinc-800 bg-zinc-900 overflow-hidden"
            data-ocid="simulator.leaderboard"
          >
            <div className="px-4 py-3 border-b border-zinc-800 flex items-center gap-2">
              <Award size={16} className="text-yellow-400" />
              <h3 className="text-sm font-semibold text-zinc-200">
                Agent Leaderboard
              </h3>
              <span className="ml-auto text-xs text-zinc-600">
                {symbol} · {days}d · {fmtUSD(initialBalance)} start
              </span>
            </div>
            <table className="w-full text-xs">
              <thead>
                <tr className="text-zinc-600 border-b border-zinc-800">
                  <th className="text-left py-2 px-4">Rank</th>
                  <th className="text-left py-2 px-4">Strategy</th>
                  <th className="text-right py-2 px-4">Final Balance</th>
                  <th className="text-right py-2 px-4">Return</th>
                  <th className="text-right py-2 px-4">Win Rate</th>
                  <th className="text-right py-2 px-4">Sharpe</th>
                  <th className="text-right py-2 px-4">Drawdown</th>
                  <th className="text-right py-2 px-4">Trades</th>
                  <th className="text-right py-2 px-4">Rejected</th>
                </tr>
              </thead>
              <tbody>
                {results.map((r, i) => (
                  <tr
                    key={r.agent.id}
                    tabIndex={0}
                    onClick={() =>
                      setSelectedAgent(
                        selectedAgent === r.agent.id ? null : r.agent.id,
                      )
                    }
                    onKeyDown={(e) =>
                      e.key === "Enter" &&
                      setSelectedAgent(
                        selectedAgent === r.agent.id ? null : r.agent.id,
                      )
                    }
                    className={`border-b border-zinc-800/40 cursor-pointer transition-colors ${
                      selectedAgent === r.agent.id
                        ? "bg-violet-600/10"
                        : "hover:bg-zinc-800/20"
                    }`}
                    data-ocid={`simulator.leaderboard.item.${i + 1}`}
                  >
                    <td className="py-2.5 px-4">
                      <RankBadge rank={i + 1} />
                    </td>
                    <td className="py-2.5 px-4">
                      <div className="flex items-center gap-2">
                        <span
                          className="w-2.5 h-2.5 rounded-full shrink-0"
                          style={{
                            background: STRATEGY_COLORS[r.agent.strategy],
                          }}
                        />
                        <span className="font-semibold text-zinc-200">
                          {r.agent.strategy}
                        </span>
                      </div>
                      <p className="text-zinc-600 text-xs mt-0.5 pl-4.5">
                        {STRATEGY_DESC[r.agent.strategy]}
                      </p>
                    </td>
                    <td className="text-right py-2.5 px-4 text-zinc-200 font-mono">
                      {fmtUSD(r.agent.equity)}
                    </td>
                    <td
                      className={`text-right py-2.5 px-4 font-semibold ${pctColor(r.totalReturn)}`}
                    >
                      {fmtPct(r.totalReturn)}
                    </td>
                    <td className="text-right py-2.5 px-4 text-zinc-300">
                      {(r.winRate * 100).toFixed(1)}%
                    </td>
                    <td
                      className={`text-right py-2.5 px-4 ${r.sharpeRatio >= 1 ? "text-emerald-400" : r.sharpeRatio >= 0 ? "text-zinc-300" : "text-red-400"}`}
                    >
                      {r.sharpeRatio.toFixed(2)}
                    </td>
                    <td className="text-right py-2.5 px-4 text-red-400">
                      {fmtPct(-r.maxDrawdown)}
                    </td>
                    <td className="text-right py-2.5 px-4 text-zinc-400">
                      {r.totalTrades}
                    </td>
                    <td className="text-right py-2.5 px-4 text-orange-400">
                      {r.rejectedCount}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Summary stats */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <StatCard
              label="Best Return"
              value={
                <span className={pctColor(results[0]?.totalReturn ?? 0)}>
                  {fmtPct(results[0]?.totalReturn ?? 0)}
                </span>
              }
              sub={results[0]?.agent.strategy}
              icon={<TrendingUp size={16} />}
            />
            <StatCard
              label="Worst Return"
              value={
                <span
                  className={pctColor(
                    results[results.length - 1]?.totalReturn ?? 0,
                  )}
                >
                  {fmtPct(results[results.length - 1]?.totalReturn ?? 0)}
                </span>
              }
              sub={results[results.length - 1]?.agent.strategy}
              icon={<TrendingDown size={16} />}
            />
            <StatCard
              label="Best Sharpe"
              value={Math.max(...results.map((r) => r.sharpeRatio)).toFixed(2)}
              sub={
                results.reduce((a, b) =>
                  a.sharpeRatio > b.sharpeRatio ? a : b,
                ).agent.strategy
              }
            />
            <StatCard
              label="Lowest Drawdown"
              value={fmtPct(-Math.min(...results.map((r) => r.maxDrawdown)))}
              sub={
                results.reduce((a, b) =>
                  a.maxDrawdown < b.maxDrawdown ? a : b,
                ).agent.strategy
              }
            />
          </div>

          {/* Equity Curve Comparison */}
          {equityChartData.length > 1 && (
            <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
              <h3 className="text-sm font-semibold text-zinc-200 mb-3">
                Equity Curve Comparison
              </h3>
              <ResponsiveContainer width="100%" height={240}>
                <LineChart data={equityChartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
                  <XAxis dataKey="t" hide />
                  <YAxis
                    domain={["auto", "auto"]}
                    tick={{ fill: "#71717a", fontSize: 10 }}
                    tickFormatter={(v) => fmtUSD(v, 0)}
                  />
                  <Tooltip
                    contentStyle={{
                      background: "#18181b",
                      border: "1px solid #3f3f46",
                      borderRadius: 8,
                      fontSize: 10,
                    }}
                    formatter={(v: number, name: string) => [fmtUSD(v), name]}
                    labelFormatter={(v) => new Date(v).toLocaleDateString()}
                  />
                  <Legend
                    formatter={(v) => (
                      <span
                        style={{
                          color:
                            STRATEGY_COLORS[v as AgentStrategy] ?? "#a1a1aa",
                          fontSize: 11,
                        }}
                      >
                        {v}
                      </span>
                    )}
                  />
                  {results.map((r) => (
                    <Line
                      key={r.agent.strategy}
                      type="monotone"
                      dataKey={r.agent.strategy}
                      stroke={STRATEGY_COLORS[r.agent.strategy]}
                      strokeWidth={selectedAgent === r.agent.id ? 2.5 : 1.5}
                      dot={false}
                      opacity={
                        selectedAgent && selectedAgent !== r.agent.id ? 0.35 : 1
                      }
                    />
                  ))}
                </LineChart>
              </ResponsiveContainer>
            </div>
          )}

          {/* Selected Agent Details */}
          {selectedResult && (
            <div
              className="rounded-xl border border-zinc-800 bg-zinc-900"
              data-ocid="simulator.agent_detail"
            >
              <div className="px-4 py-3 border-b border-zinc-800 flex items-center gap-2">
                <span
                  className="w-3 h-3 rounded-full"
                  style={{
                    background: STRATEGY_COLORS[selectedResult.agent.strategy],
                  }}
                />
                <h3 className="text-sm font-semibold text-zinc-200">
                  {selectedResult.agent.strategy} — Trade Log
                </h3>
                <div className="ml-auto flex items-center gap-1">
                  <button
                    type="button"
                    onClick={() => setTradeTab("trades")}
                    className={`px-2.5 py-1 text-xs rounded-lg font-medium transition-colors ${
                      tradeTab === "trades"
                        ? "bg-violet-600 text-white"
                        : "bg-zinc-800 text-zinc-400 hover:text-zinc-200"
                    }`}
                    data-ocid="simulator.trade_log.tab"
                  >
                    <Activity size={10} className="inline mr-1" />
                    Trades ({activeTrades.length})
                  </button>
                  <button
                    type="button"
                    onClick={() => setTradeTab("rejected")}
                    className={`px-2.5 py-1 text-xs rounded-lg font-medium transition-colors ${
                      tradeTab === "rejected"
                        ? "bg-orange-600 text-white"
                        : "bg-zinc-800 text-zinc-400 hover:text-zinc-200"
                    }`}
                    data-ocid="simulator.rejection_log.tab"
                  >
                    <XCircle size={10} className="inline mr-1" />
                    Rejected ({rejectedTrades.length})
                  </button>
                </div>
              </div>

              {tradeTab === "trades" && (
                <div className="overflow-x-auto">
                  {activeTrades.length === 0 ? (
                    <p
                      className="text-sm text-zinc-600 py-8 text-center"
                      data-ocid="simulator.trade_log.empty_state"
                    >
                      No trades executed by this agent
                    </p>
                  ) : (
                    <table className="w-full text-xs">
                      <thead>
                        <tr className="text-zinc-600 border-b border-zinc-800">
                          <th className="text-left py-2 px-3">#</th>
                          <th className="text-left py-2 px-3">Action</th>
                          <th className="text-right py-2 px-3">Entry</th>
                          <th className="text-right py-2 px-3">Exit</th>
                          <th className="text-right py-2 px-3">PnL</th>
                          <th className="text-right py-2 px-3">Conf</th>
                          <th className="py-2 px-3" />
                        </tr>
                      </thead>
                      <tbody>
                        {activeTrades.map((t, i) => (
                          <TradeRow key={t.id} trade={t} idx={i} />
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              )}

              {tradeTab === "rejected" && (
                <div className="overflow-x-auto">
                  {rejectedTrades.length === 0 ? (
                    <p
                      className="text-sm text-zinc-600 py-8 text-center"
                      data-ocid="simulator.rejection_log.empty_state"
                    >
                      No rejected trades — all signals were accepted
                    </p>
                  ) : (
                    <table className="w-full text-xs">
                      <thead>
                        <tr className="text-zinc-600 border-b border-zinc-800">
                          <th className="text-left py-2 px-3">#</th>
                          <th className="text-left py-2 px-3">Type</th>
                          <th className="text-right py-2 px-3">Price</th>
                          <th className="text-right py-2 px-3">Confidence</th>
                          <th className="text-left py-2 px-3">Reason</th>
                          <th className="text-left py-2 px-3">Time</th>
                        </tr>
                      </thead>
                      <tbody>
                        {rejectedTrades.map((t, i) => (
                          <tr
                            key={t.id}
                            className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                            data-ocid={`simulator.rejection_log.item.${i + 1}`}
                          >
                            <td className="py-2 px-3 text-zinc-500">{i + 1}</td>
                            <td className="py-2 px-3">
                              <span className="px-1.5 py-0.5 rounded bg-zinc-700 text-zinc-400 text-xs">
                                REJECTED
                              </span>
                            </td>
                            <td className="py-2 px-3 text-right text-zinc-300 font-mono">
                              {fmtUSD(t.entryPrice)}
                            </td>
                            <td className="py-2 px-3 text-right text-zinc-400">
                              {t.confidence.toFixed(0)}%
                            </td>
                            <td className="py-2 px-3 text-red-400">
                              {t.rejectReason ?? "—"}
                            </td>
                            <td className="py-2 px-3 text-zinc-600">
                              {new Date(t.entryTime).toLocaleDateString()}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}

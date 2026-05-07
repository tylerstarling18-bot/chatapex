import { useState } from "react";
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Badge } from "../components/Badge";
import { Button } from "../components/Button";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { SectionHeader } from "../components/SectionHeader";
import { StatCard } from "../components/StatCard";
import {
  useClosePosition,
  useEquityHistory,
  useOpenPositions,
  usePortfolio,
  useTradeHistory,
} from "../hooks/useTrading";
import { fmtPct, fmtTime, fmtUSD, pctColor } from "../lib/format";

export function TradingPage() {
  const { data: portfolio, isLoading } = usePortfolio();
  const { data: positions } = useOpenPositions();
  const { data: trades } = useTradeHistory(50);
  const { data: equityHistory } = useEquityHistory(100);
  const closePosition = useClosePosition();
  const [tab, setTab] = useState<"positions" | "history" | "equity">(
    "positions",
  );
  const [closeConfirm, setCloseConfirm] = useState<string | null>(null);

  const pnl = portfolio?.totalPnl ?? 0;

  const equityData = (equityHistory ?? []).map((e) => ({
    t: Number(e.timestamp) * 1000,
    equity: e.equity,
  }));

  return (
    <div className="p-6 space-y-6">
      <SectionHeader
        title="Trading"
        description="Portfolio, open positions and trade history"
      />

      {isLoading ? (
        <LoadingSpinner />
      ) : (
        <>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <StatCard
              label="Portfolio Value"
              value={fmtUSD(portfolio?.totalValue ?? 0)}
              sub={`${fmtPct(portfolio?.totalPnlPercent ?? 0)} total`}
            />
            <StatCard
              label="Total PnL"
              value={<span className={pctColor(pnl)}>{fmtUSD(pnl)}</span>}
              sub={
                <span className={pctColor(pnl)}>
                  {fmtPct(portfolio?.totalPnlPercent ?? 0)}
                </span>
              }
            />
            <StatCard
              label="Cash Balance"
              value={fmtUSD(portfolio?.cashBalance ?? 0)}
              sub={`Invested: ${fmtUSD(portfolio?.investedValue ?? 0)}`}
            />
            <StatCard
              label="Win Rate"
              value={`${(portfolio?.winRate ?? 0).toFixed(1)}%`}
              sub={`${portfolio?.winningTrades ?? 0}W / ${Number(portfolio?.totalTrades ?? 0n) - Number(portfolio?.winningTrades ?? 0n)}L | ${portfolio?.totalTrades ?? 0} total`}
            />
          </div>

          {equityData.length > 1 && (
            <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
              <h3 className="text-sm font-semibold text-zinc-200 mb-3">
                Equity Curve
              </h3>
              <ResponsiveContainer width="100%" height={200}>
                <LineChart data={equityData}>
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
                    }}
                    labelFormatter={(v) => new Date(v).toLocaleString()}
                    formatter={(v: number) => [fmtUSD(v), "Equity"]}
                  />
                  <Line
                    type="monotone"
                    dataKey="equity"
                    stroke="#7c3aed"
                    strokeWidth={2}
                    dot={false}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          )}

          <div className="flex gap-2 border-b border-zinc-800">
            {(["positions", "history", "equity"] as const).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setTab(t)}
                className={`px-3 py-2 text-sm font-medium transition-colors capitalize ${
                  tab === t
                    ? "text-violet-400 border-b-2 border-violet-400"
                    : "text-zinc-500 hover:text-zinc-300"
                }`}
              >
                {t === "positions"
                  ? `Positions (${positions?.length ?? 0})`
                  : t === "history"
                    ? "Trade History"
                    : "Equity Log"}
              </button>
            ))}
          </div>

          {tab === "positions" && (
            <div className="rounded-xl border border-zinc-800 bg-zinc-900 overflow-x-auto">
              {!positions || positions.length === 0 ? (
                <p className="text-sm text-zinc-600 py-8 text-center">
                  No open positions
                </p>
              ) : (
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-xs text-zinc-600 border-b border-zinc-800">
                      <th className="text-left py-2.5 px-4">Symbol</th>
                      <th className="text-right py-2.5 px-4">Qty</th>
                      <th className="text-right py-2.5 px-4">Avg Entry</th>
                      <th className="text-right py-2.5 px-4">Current</th>
                      <th className="text-right py-2.5 px-4">Unreal. PnL</th>
                      <th className="text-right py-2.5 px-4">Stop Loss</th>
                      <th className="text-right py-2.5 px-4">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {positions.map((p) => (
                      <tr
                        key={p.symbol}
                        className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                      >
                        <td className="py-2.5 px-4 font-semibold text-zinc-100">
                          {p.symbol}
                        </td>
                        <td className="text-right py-2.5 px-4 text-zinc-300 font-mono">
                          {p.quantity.toFixed(6)}
                        </td>
                        <td className="text-right py-2.5 px-4 text-zinc-300">
                          {fmtUSD(p.averageEntryPrice)}
                        </td>
                        <td className="text-right py-2.5 px-4 text-zinc-200">
                          {fmtUSD(p.currentPrice)}
                        </td>
                        <td
                          className={`text-right py-2.5 px-4 font-medium ${pctColor(p.unrealizedPnl)}`}
                        >
                          {fmtUSD(p.unrealizedPnl)}{" "}
                          <span className="text-xs">
                            ({fmtPct(p.unrealizedPnlPercent)})
                          </span>
                        </td>
                        <td className="text-right py-2.5 px-4 text-red-400">
                          {fmtUSD(p.stopLoss)}
                        </td>
                        <td className="text-right py-2.5 px-4">
                          {closeConfirm === p.symbol ? (
                            <div className="flex items-center gap-1 justify-end">
                              <Button
                                variant="danger"
                                size="sm"
                                onClick={() => {
                                  closePosition.mutate(p.symbol);
                                  setCloseConfirm(null);
                                }}
                              >
                                Confirm
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => setCloseConfirm(null)}
                              >
                                Cancel
                              </Button>
                            </div>
                          ) : (
                            <Button
                              variant="secondary"
                              size="sm"
                              onClick={() => setCloseConfirm(p.symbol)}
                            >
                              Close
                            </Button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          )}

          {tab === "history" && (
            <div className="rounded-xl border border-zinc-800 bg-zinc-900 overflow-x-auto">
              {!trades || trades.length === 0 ? (
                <p className="text-sm text-zinc-600 py-8 text-center">
                  No trades yet
                </p>
              ) : (
                <table className="w-full text-xs">
                  <thead>
                    <tr className="text-zinc-600 border-b border-zinc-800">
                      <th className="text-left py-2 px-4">Symbol</th>
                      <th className="text-left py-2 px-4">Action</th>
                      <th className="text-right py-2 px-4">Entry</th>
                      <th className="text-right py-2 px-4">Exit</th>
                      <th className="text-right py-2 px-4">PnL</th>
                      <th className="text-left py-2 px-4">Status</th>
                      <th className="text-left py-2 px-4">Opened</th>
                    </tr>
                  </thead>
                  <tbody>
                    {trades.map((t) => (
                      <tr
                        key={t.id}
                        className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                      >
                        <td className="py-2 px-4 font-medium text-zinc-200">
                          {t.symbol}
                        </td>
                        <td className="py-2 px-4">
                          <Badge
                            className={
                              t.action === "Buy"
                                ? "bg-emerald-500/20 text-emerald-400"
                                : "bg-red-500/20 text-red-400"
                            }
                          >
                            {t.action}
                          </Badge>
                        </td>
                        <td className="text-right py-2 px-4 text-zinc-300 font-mono">
                          {fmtUSD(t.entryPrice)}
                        </td>
                        <td className="text-right py-2 px-4 text-zinc-400">
                          {t.exitPrice != null ? fmtUSD(t.exitPrice) : "—"}
                        </td>
                        <td
                          className={`text-right py-2 px-4 font-medium ${pctColor(t.pnl ?? 0)}`}
                        >
                          {t.pnl != null ? fmtUSD(t.pnl) : "—"}
                        </td>
                        <td className="py-2 px-4">
                          <Badge
                            className={
                              t.status === "Open"
                                ? "bg-blue-500/20 text-blue-400"
                                : t.status === "Closed"
                                  ? "bg-zinc-700 text-zinc-400"
                                  : t.status === "TakeProfitHit"
                                    ? "bg-emerald-500/20 text-emerald-400"
                                    : t.status === "StopLossHit"
                                      ? "bg-red-500/20 text-red-400"
                                      : "bg-zinc-700 text-zinc-500"
                            }
                          >
                            {t.status}
                          </Badge>
                        </td>
                        <td className="py-2 px-4 text-zinc-600">
                          {fmtTime(t.openTime)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          )}

          {tab === "equity" && (
            <div className="rounded-xl border border-zinc-800 bg-zinc-900 overflow-x-auto">
              {!equityHistory || equityHistory.length === 0 ? (
                <p className="text-sm text-zinc-600 py-8 text-center">
                  No equity snapshots yet
                </p>
              ) : (
                <table className="w-full text-xs">
                  <thead>
                    <tr className="text-zinc-600 border-b border-zinc-800">
                      <th className="text-left py-2 px-4">Time</th>
                      <th className="text-right py-2 px-4">Equity</th>
                      <th className="text-right py-2 px-4">Cash</th>
                      <th className="text-right py-2 px-4">Position Value</th>
                      <th className="text-right py-2 px-4">Daily PnL %</th>
                      <th className="text-right py-2 px-4">Total PnL %</th>
                    </tr>
                  </thead>
                  <tbody>
                    {[...equityHistory]
                      .reverse()
                      .slice(0, 50)
                      .map((e, _i) => (
                        <tr
                          key={`eq-${String(e.timestamp)}`}
                          className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                        >
                          <td className="py-2 px-4 text-zinc-500">
                            {new Date(
                              Number(e.timestamp) * 1000,
                            ).toLocaleString()}
                          </td>
                          <td className="text-right py-2 px-4 text-zinc-200 font-mono">
                            {fmtUSD(e.equity)}
                          </td>
                          <td className="text-right py-2 px-4 text-zinc-400">
                            {fmtUSD(e.cash)}
                          </td>
                          <td className="text-right py-2 px-4 text-zinc-400">
                            {fmtUSD(e.positionValue)}
                          </td>
                          <td
                            className={`text-right py-2 px-4 ${pctColor(e.dailyPnLPct)}`}
                          >
                            {fmtPct(e.dailyPnLPct)}
                          </td>
                          <td
                            className={`text-right py-2 px-4 ${pctColor(e.totalPnLPct)}`}
                          >
                            {fmtPct(e.totalPnLPct)}
                          </td>
                        </tr>
                      ))}
                  </tbody>
                </table>
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}

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
import type { BacktestSession } from "../backend";
import { Badge } from "../components/Badge";
import { Button } from "../components/Button";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { SectionHeader } from "../components/SectionHeader";
import { useBacktestSessions, useStartBacktest } from "../hooks/useBacktest";
import { fmtPct, fmtUSD, pctColor } from "../lib/format";

const SYMBOLS = [
  "BTC",
  "ETH",
  "BNB",
  "SOL",
  "ADA",
  "AVAX",
  "LINK",
  "DOT",
  "UNI",
  "LTC",
];

export function BacktestPage() {
  const { data: sessions, isLoading } = useBacktestSessions();
  const startBacktest = useStartBacktest();
  const [selected, setSelected] = useState<BacktestSession | null>(null);
  const [showForm, setShowForm] = useState(false);

  const [form, setForm] = useState({
    name: "My Backtest",
    symbols: ["BTC", "ETH"],
    startDate: "2024-01-01",
    endDate: "2024-12-31",
    initialBalance: 10000,
  });

  function toggleSymbol(s: string) {
    setForm((f) => ({
      ...f,
      symbols: f.symbols.includes(s)
        ? f.symbols.filter((x) => x !== s)
        : [...f.symbols, s],
    }));
  }

  async function handleStart() {
    const startNs = BigInt(new Date(form.startDate).getTime()) * 1_000_000n;
    const endNs = BigInt(new Date(form.endDate).getTime()) * 1_000_000n;
    await startBacktest.mutateAsync({
      name: form.name,
      symbols: form.symbols,
      startDate: startNs,
      endDate: endNs,
      initialBalance: form.initialBalance,
    });
    setShowForm(false);
  }

  const equityData =
    selected?.results?.equityCurve.map((p) => ({
      t: Number(p.timestamp),
      value: p.value,
    })) ?? [];

  return (
    <div className="p-6 space-y-6">
      <SectionHeader
        title="Backtesting"
        description="Run historical simulations against real OHLCV data"
        actions={
          <Button
            onClick={() => setShowForm(!showForm)}
            variant={showForm ? "ghost" : "primary"}
          >
            {showForm ? "Cancel" : "New Backtest"}
          </Button>
        }
      />

      {showForm && (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4 space-y-4">
          <h3 className="text-sm font-semibold text-zinc-200">
            Configure Backtest
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label
                htmlFor="btName"
                className="text-xs text-zinc-500 block mb-1"
              >
                Name
              </label>
              <input
                id="btName"
                value={form.name}
                onChange={(e) =>
                  setForm((f) => ({ ...f, name: e.target.value }))
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              />
            </div>
            <div>
              <label
                htmlFor="btBalance"
                className="text-xs text-zinc-500 block mb-1"
              >
                Initial Balance (USD)
              </label>
              <input
                id="btBalance"
                value={form.initialBalance}
                onChange={(e) =>
                  setForm((f) => ({
                    ...f,
                    initialBalance: Number.parseFloat(e.target.value),
                  }))
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              />
            </div>
            <div>
              <label
                htmlFor="btStart"
                className="text-xs text-zinc-500 block mb-1"
              >
                Start Date
              </label>
              <input
                id="btStart"
                value={form.startDate}
                onChange={(e) =>
                  setForm((f) => ({ ...f, startDate: e.target.value }))
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              />
            </div>
            <div>
              <label
                htmlFor="btEnd"
                className="text-xs text-zinc-500 block mb-1"
              >
                End Date
              </label>
              <input
                id="btEnd"
                value={form.endDate}
                onChange={(e) =>
                  setForm((f) => ({ ...f, endDate: e.target.value }))
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              />
            </div>
          </div>
          <div>
            <p className="text-xs text-zinc-500 block mb-2">Symbols</p>
            <div className="flex flex-wrap gap-2">
              {SYMBOLS.map((s) => (
                <button
                  key={s}
                  type="button"
                  onClick={() => toggleSymbol(s)}
                  className={`px-2.5 py-1 rounded-lg text-xs font-medium transition-colors ${
                    form.symbols.includes(s)
                      ? "bg-violet-600 text-white"
                      : "bg-zinc-800 text-zinc-400 hover:text-zinc-200"
                  }`}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
          <Button
            onClick={handleStart}
            loading={startBacktest.isPending}
            disabled={form.symbols.length === 0}
          >
            Run Backtest
          </Button>
          {startBacktest.isPending && (
            <p className="text-xs text-zinc-500">
              Fetching historical data from CoinGecko and running simulation…
            </p>
          )}
        </div>
      )}

      <div className="flex gap-4">
        <div className="flex-1 rounded-xl border border-zinc-800 bg-zinc-900">
          <div className="px-4 py-3 border-b border-zinc-800">
            <h3 className="text-sm font-semibold text-zinc-200">Sessions</h3>
          </div>
          {isLoading ? (
            <LoadingSpinner />
          ) : !sessions || sessions.length === 0 ? (
            <p className="text-sm text-zinc-600 py-8 text-center">
              No backtests yet
            </p>
          ) : (
            <table className="w-full text-xs">
              <thead>
                <tr className="text-zinc-600 border-b border-zinc-800">
                  <th className="text-left py-2 px-4">Name</th>
                  <th className="text-left py-2 px-4">Status</th>
                  <th className="text-right py-2 px-4">Return</th>
                  <th className="text-right py-2 px-4">Win Rate</th>
                  <th className="text-right py-2 px-4">Drawdown</th>
                  <th className="text-right py-2 px-4">Trades</th>
                </tr>
              </thead>
              <tbody>
                {sessions.map((s) => (
                  <tr
                    key={s.id}
                    tabIndex={0}
                    onClick={() =>
                      setSelected(selected?.id === s.id ? null : s)
                    }
                    onKeyDown={(e) =>
                      e.key === "Enter" &&
                      setSelected(selected?.id === s.id ? null : s)
                    }
                    className={`border-b border-zinc-800/40 cursor-pointer transition-colors ${
                      selected?.id === s.id
                        ? "bg-violet-600/10"
                        : "hover:bg-zinc-800/20"
                    }`}
                  >
                    <td className="py-2 px-4 font-medium text-zinc-200">
                      {s.name}
                    </td>
                    <td className="py-2 px-4">
                      <Badge
                        className={
                          s.status === "Completed"
                            ? "bg-emerald-500/20 text-emerald-400"
                            : s.status === "Running"
                              ? "bg-blue-500/20 text-blue-400"
                              : "bg-red-500/20 text-red-400"
                        }
                      >
                        {s.status}
                      </Badge>
                    </td>
                    <td
                      className={`text-right py-2 px-4 font-medium ${pctColor(s.results?.totalReturn ?? 0)}`}
                    >
                      {s.results ? fmtPct(s.results.totalReturn) : "—"}
                    </td>
                    <td className="text-right py-2 px-4 text-zinc-300">
                      {s.results
                        ? `${(s.results.winRate * 100).toFixed(1)}%`
                        : "—"}
                    </td>
                    <td className="text-right py-2 px-4 text-red-400">
                      {s.results ? fmtPct(-s.results.maxDrawdown) : "—"}
                    </td>
                    <td className="text-right py-2 px-4 text-zinc-400">
                      {s.results ? String(s.results.totalTrades) : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {selected?.results && (
          <div className="w-80 shrink-0 space-y-3">
            <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4 space-y-2">
              <h3 className="text-sm font-semibold text-zinc-200">
                {selected.name}
              </h3>
              <div className="grid grid-cols-2 gap-2 text-xs">
                <div className="rounded-lg bg-zinc-800 px-3 py-2">
                  <p className="text-zinc-500">Final Balance</p>
                  <p className="text-zinc-100 font-semibold">
                    {fmtUSD(selected.results.finalBalance)}
                  </p>
                </div>
                <div className="rounded-lg bg-zinc-800 px-3 py-2">
                  <p className="text-zinc-500">Total Return</p>
                  <p
                    className={`font-semibold ${pctColor(selected.results.totalReturn)}`}
                  >
                    {fmtPct(selected.results.totalReturn)}
                  </p>
                </div>
                <div className="rounded-lg bg-zinc-800 px-3 py-2">
                  <p className="text-zinc-500">Win Rate</p>
                  <p className="text-zinc-100 font-semibold">
                    {(selected.results.winRate * 100).toFixed(1)}%
                  </p>
                </div>
                <div className="rounded-lg bg-zinc-800 px-3 py-2">
                  <p className="text-zinc-500">Max Drawdown</p>
                  <p className="text-red-400 font-semibold">
                    {fmtPct(-selected.results.maxDrawdown)}
                  </p>
                </div>
                <div className="rounded-lg bg-zinc-800 px-3 py-2">
                  <p className="text-zinc-500">Sharpe Ratio</p>
                  <p className="text-zinc-100 font-semibold">
                    {selected.results.sharpeRatio?.toFixed(2) ?? "—"}
                  </p>
                </div>
                <div className="rounded-lg bg-zinc-800 px-3 py-2">
                  <p className="text-zinc-500">Total Trades</p>
                  <p className="text-zinc-100 font-semibold">
                    {String(selected.results.totalTrades)}
                  </p>
                </div>
              </div>
            </div>
            {equityData.length > 1 && (
              <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
                <p className="text-xs text-zinc-500 mb-2">Equity Curve</p>
                <ResponsiveContainer width="100%" height={120}>
                  <LineChart data={equityData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#27272a" />
                    <XAxis dataKey="t" hide />
                    <YAxis hide domain={["auto", "auto"]} />
                    <Tooltip
                      contentStyle={{
                        background: "#18181b",
                        border: "1px solid #3f3f46",
                        borderRadius: 6,
                        fontSize: 10,
                      }}
                      formatter={(v: number) => [fmtUSD(v), "Equity"]}
                    />
                    <Line
                      type="monotone"
                      dataKey="value"
                      stroke="#7c3aed"
                      strokeWidth={1.5}
                      dot={false}
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

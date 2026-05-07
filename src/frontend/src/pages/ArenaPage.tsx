import { useState } from "react";
import type { ArenaSession } from "../backend";
import { Badge } from "../components/Badge";
import { Button } from "../components/Button";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { SectionHeader } from "../components/SectionHeader";
import { useArenaSessions, useStartArena } from "../hooks/useArena";
import { fmtPct, fmtUSD, pctColor } from "../lib/format";
import { regimeBadgeClass, regimeLabel } from "../lib/regime";

const SYMBOLS = ["BTC", "ETH", "BNB", "SOL", "ADA"];

export function ArenaPage() {
  const { data: sessions, isLoading } = useArenaSessions();
  const startArena = useStartArena();
  const [selected, setSelected] = useState<ArenaSession | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({
    symbol: "BTC",
    startDate: "2024-01-01",
    endDate: "2024-12-31",
  });

  async function handleStart() {
    await startArena.mutateAsync(form);
    setShowForm(false);
  }

  return (
    <div className="p-6 space-y-6">
      <SectionHeader
        title="Strategy Arena"
        description="Pit multiple AI strategies against each other in a competition"
        actions={
          <Button
            onClick={() => setShowForm(!showForm)}
            variant={showForm ? "ghost" : "primary"}
          >
            {showForm ? "Cancel" : "New Arena"}
          </Button>
        }
      />

      {showForm && (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4 space-y-4">
          <h3 className="text-sm font-semibold text-zinc-200">
            Configure Arena
          </h3>
          <div className="grid grid-cols-3 gap-4">
            <div>
              <label
                htmlFor="arenaSymbol"
                className="text-xs text-zinc-500 block mb-1"
              >
                Symbol
              </label>
              <select
                value={form.symbol}
                onChange={(e) =>
                  setForm((f) => ({ ...f, symbol: e.target.value }))
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
                id="arenaSymbol"
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
                htmlFor="arenaStart"
                className="text-xs text-zinc-500 block mb-1"
              >
                Start Date
              </label>
              <input
                id="arenaStart"
                type="date"
                value={form.startDate}
                onChange={(e) =>
                  setForm((f) => ({ ...f, startDate: e.target.value }))
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              />
            </div>
            <div>
              <label
                htmlFor="arenaEnd"
                className="text-xs text-zinc-500 block mb-1"
              >
                End Date
              </label>
              <input
                id="arenaEnd"
                type="date"
                value={form.endDate}
                onChange={(e) =>
                  setForm((f) => ({ ...f, endDate: e.target.value }))
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              />
            </div>
          </div>
          <Button onClick={handleStart} loading={startArena.isPending}>
            Run Arena
          </Button>
        </div>
      )}

      <div className="flex gap-4">
        <div className="flex-1 rounded-xl border border-zinc-800 bg-zinc-900">
          <div className="px-4 py-3 border-b border-zinc-800">
            <h3 className="text-sm font-semibold text-zinc-200">
              Arena Sessions
            </h3>
          </div>
          {isLoading ? (
            <LoadingSpinner />
          ) : !sessions || sessions.length === 0 ? (
            <p className="text-sm text-zinc-600 py-8 text-center">
              No arena sessions yet
            </p>
          ) : (
            <table className="w-full text-xs">
              <thead>
                <tr className="text-zinc-600 border-b border-zinc-800">
                  <th className="text-left py-2 px-4">Session</th>
                  <th className="text-left py-2 px-4">Symbol</th>
                  <th className="text-left py-2 px-4">Period</th>
                  <th className="text-right py-2 px-4">Capital</th>
                  <th className="text-right py-2 px-4">Agents</th>
                </tr>
              </thead>
              <tbody>
                {sessions.map((s) => (
                  <tr
                    key={s.sessionId}
                    tabIndex={0}
                    onClick={() =>
                      setSelected(
                        selected?.sessionId === s.sessionId ? null : s,
                      )
                    }
                    onKeyDown={(e) =>
                      e.key === "Enter" &&
                      setSelected(
                        selected?.sessionId === s.sessionId ? null : s,
                      )
                    }
                    className={`border-b border-zinc-800/40 cursor-pointer transition-colors ${
                      selected?.sessionId === s.sessionId
                        ? "bg-violet-600/10"
                        : "hover:bg-zinc-800/20"
                    }`}
                  >
                    <td className="py-2 px-4 text-zinc-500 font-mono">
                      {s.sessionId.slice(0, 16)}…
                    </td>
                    <td className="py-2 px-4 font-semibold text-zinc-200">
                      {s.symbol}
                    </td>
                    <td className="py-2 px-4 text-zinc-400">
                      {s.startDate} → {s.endDate}
                    </td>
                    <td className="text-right py-2 px-4 text-zinc-300">
                      {fmtUSD(s.initialCapital)}
                    </td>
                    <td className="text-right py-2 px-4 text-zinc-400">
                      {s.results.length}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {selected && selected.results.length > 0 && (
          <div className="w-80 shrink-0 rounded-xl border border-zinc-800 bg-zinc-900 p-4">
            <h3 className="text-sm font-semibold text-zinc-200 mb-3">
              Results — {selected.symbol}
            </h3>
            <div className="space-y-2">
              {[...selected.results]
                .sort((a, b) => b.totalReturnPct - a.totalReturnPct)
                .map((r, i) => (
                  <div
                    key={r.agentId}
                    className={`rounded-lg border p-3 text-xs ${
                      i === 0
                        ? "border-violet-500/50 bg-violet-500/10"
                        : "border-zinc-700 bg-zinc-800"
                    }`}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-semibold text-zinc-200">
                        {i + 1}. {r.agentId}
                      </span>
                      <span
                        className={`font-bold ${pctColor(r.totalReturnPct)}`}
                      >
                        {fmtPct(r.totalReturnPct)}
                      </span>
                    </div>
                    <div className="grid grid-cols-2 gap-x-4 gap-y-0.5 text-zinc-500">
                      <span>
                        Balance:{" "}
                        <span className="text-zinc-300">
                          {fmtUSD(r.finalBalance)}
                        </span>
                      </span>
                      <span>
                        Trades:{" "}
                        <span className="text-zinc-300">
                          {String(r.tradeCount)}
                        </span>
                      </span>
                      <span>
                        Win Rate:{" "}
                        <span className="text-zinc-300">
                          {(r.winRate * 100).toFixed(1)}%
                        </span>
                      </span>
                      <span>
                        Sharpe:{" "}
                        <span className="text-zinc-300">
                          {r.sharpeRatio.toFixed(2)}
                        </span>
                      </span>
                      <span>
                        Drawdown:{" "}
                        <span className="text-red-400">
                          {fmtPct(-r.maxDrawdownPct)}
                        </span>
                      </span>
                    </div>
                    {r.performanceByRegime.length > 0 && (
                      <div className="mt-2 space-y-0.5">
                        <p className="text-zinc-600 mb-1">By Regime:</p>
                        {r.performanceByRegime.map((rb) => (
                          <div
                            key={String(rb.regime)}
                            className="flex items-center justify-between"
                          >
                            <Badge
                              className={regimeBadgeClass(rb.regime as any)}
                            >
                              {regimeLabel(rb.regime as any)}
                            </Badge>
                            <span className={pctColor(rb.returnPct)}>
                              {fmtPct(rb.returnPct)}
                            </span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

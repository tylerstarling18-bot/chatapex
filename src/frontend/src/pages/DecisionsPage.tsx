import { useState } from "react";
import { Badge } from "../components/Badge";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { SectionHeader } from "../components/SectionHeader";
import { StatCard } from "../components/StatCard";
import {
  useAIStatus,
  useConfidenceTimeline,
  useLiveActivityFeed,
  useNoTradeLog,
  useRecentDecisions,
} from "../hooks/useAI";
import { useCurrentMarketCondition } from "../hooks/useMarket";
import { fmtTime, fmtUSD } from "../lib/format";
import { regimeBadgeClass, regimeLabel } from "../lib/regime";

const ASSETS = [
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

export function DecisionsPage() {
  const { data: decisions, isLoading } = useRecentDecisions(50);
  const { data: aiStatus } = useAIStatus();
  const { data: condition } = useCurrentMarketCondition();
  const { data: noTradeLog } = useNoTradeLog();
  const [selected, setSelected] = useState<string | null>(null);
  const [asset, setAsset] = useState("BTC");
  const { data: timeline } = useConfidenceTimeline(asset, 50);
  const [tab, setTab] = useState<"decisions" | "notrade" | "confidence">(
    "decisions",
  );

  const selectedDecision = selected
    ? decisions?.find((d) => d.decision.id === selected)
    : null;

  return (
    <div className="p-6 space-y-6">
      <SectionHeader
        title="AI Decisions"
        description="Decision logs, confidence analysis and no-trade events"
      />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard
          label="AI Mode"
          value={aiStatus?.mode ?? "—"}
          sub={`Cycle #${aiStatus?.cycleCount ?? 0}`}
        />
        <StatCard
          label="Decisions"
          value={String(decisions?.length ?? 0)}
          sub="in view"
        />
        <StatCard
          label="Market Regime"
          value={
            <Badge className={regimeBadgeClass(condition ?? null)}>
              {regimeLabel(condition ?? null)}
            </Badge>
          }
        />
        <StatCard
          label="No-Trade Events"
          value={String(noTradeLog?.length ?? 0)}
          sub="total logged"
        />
      </div>

      <div className="flex gap-2 border-b border-zinc-800">
        {(["decisions", "notrade", "confidence"] as const).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTab(t)}
            className={`px-3 py-2 text-sm font-medium transition-colors ${
              tab === t
                ? "text-violet-400 border-b-2 border-violet-400"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            {t === "decisions"
              ? "Decision Log"
              : t === "notrade"
                ? "No-Trade Log"
                : "Confidence Timeline"}
          </button>
        ))}
      </div>

      {tab === "decisions" && (
        <div className="flex gap-4">
          <div className="flex-1 rounded-xl border border-zinc-800 bg-zinc-900 overflow-x-auto">
            {isLoading ? (
              <LoadingSpinner />
            ) : !decisions || decisions.length === 0 ? (
              <p className="text-sm text-zinc-600 py-8 text-center">
                No decisions yet — run an AI analysis or decision cycle
              </p>
            ) : (
              <table className="w-full text-xs">
                <thead>
                  <tr className="text-zinc-600 border-b border-zinc-800">
                    <th className="text-left py-2 px-4">Asset</th>
                    <th className="text-left py-2 px-4">Action</th>
                    <th className="text-right py-2 px-4">Confidence</th>
                    <th className="text-left py-2 px-4">Status</th>
                    <th className="text-left py-2 px-4">Regime</th>
                    <th className="text-left py-2 px-4">Strategy</th>
                    <th className="text-right py-2 px-4">Price</th>
                    <th className="text-left py-2 px-4">Time</th>
                  </tr>
                </thead>
                <tbody>
                  {decisions.map((d) => (
                    <tr
                      key={d.decision.id}
                      className={`border-b border-zinc-800/40 cursor-pointer transition-colors ${
                        selected === d.decision.id
                          ? "bg-violet-600/10"
                          : "hover:bg-zinc-800/20"
                      }`}
                      onClick={() =>
                        setSelected(
                          selected === d.decision.id ? null : d.decision.id,
                        )
                      }
                      onKeyDown={(e) =>
                        e.key === "Enter" &&
                        setSelected(
                          selected === d.decision.id ? null : d.decision.id,
                        )
                      }
                    >
                      <td className="py-2 px-4 font-medium text-zinc-200">
                        {d.decision.symbol}
                      </td>
                      <td className="py-2 px-4">
                        <Badge
                          className={
                            d.decision.action === "Buy"
                              ? "bg-emerald-500/20 text-emerald-400"
                              : d.decision.action === "Sell"
                                ? "bg-red-500/20 text-red-400"
                                : "bg-zinc-700 text-zinc-400"
                          }
                        >
                          {d.decision.action}
                        </Badge>
                      </td>
                      <td className="text-right py-2 px-4 text-zinc-300">
                        {d.confidenceFactors.total.toFixed(1)}%
                      </td>
                      <td className="py-2 px-4">
                        <Badge
                          className={
                            d.executionStatus === "Executed"
                              ? "bg-emerald-500/20 text-emerald-400"
                              : d.executionStatus === "Skipped"
                                ? "bg-zinc-700 text-zinc-500"
                                : d.executionStatus === "Pending"
                                  ? "bg-blue-500/20 text-blue-400"
                                  : "bg-red-500/20 text-red-400"
                          }
                        >
                          {d.executionStatus}
                        </Badge>
                      </td>
                      <td className="py-2 px-4">
                        <Badge
                          className={regimeBadgeClass(
                            d.decision.marketCondition as any,
                          )}
                        >
                          {regimeLabel(d.decision.marketCondition as any)}
                        </Badge>
                      </td>
                      <td className="py-2 px-4 text-zinc-500">
                        {d.decision.strategyMode}
                      </td>
                      <td className="text-right py-2 px-4 text-zinc-300 font-mono">
                        {fmtUSD(d.decision.entryPrice)}
                      </td>
                      <td className="py-2 px-4 text-zinc-600">
                        {fmtTime(d.decision.timestamp)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          {selectedDecision && (
            <div className="w-72 shrink-0 rounded-xl border border-zinc-800 bg-zinc-900 p-4 space-y-3">
              <h3 className="text-sm font-semibold text-zinc-200">
                Decision Detail
              </h3>
              <p className="text-xs text-zinc-400 leading-relaxed">
                {selectedDecision.decision.reasoning}
              </p>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span className="text-zinc-600">RSI</span>
                  <span className="text-zinc-300">
                    {selectedDecision.indicatorValues.rsi.toFixed(1)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-600">MACD</span>
                  <span className="text-zinc-300">
                    {selectedDecision.indicatorValues.macd.toFixed(4)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-600">EMA20</span>
                  <span className="text-zinc-300">
                    {fmtUSD(selectedDecision.indicatorValues.ema20)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-600">EMA50</span>
                  <span className="text-zinc-300">
                    {fmtUSD(selectedDecision.indicatorValues.ema50)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-600">ATR</span>
                  <span className="text-zinc-300">
                    {selectedDecision.indicatorValues.atr.toFixed(4)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-600">BB Width</span>
                  <span className="text-zinc-300">
                    {selectedDecision.indicatorValues.bollingerBandwidth.toFixed(
                      4,
                    )}
                  </span>
                </div>
              </div>
              <div className="border-t border-zinc-800 pt-2 space-y-1 text-xs">
                <p className="text-zinc-600 font-medium">Confidence Factors</p>
                {Object.entries(selectedDecision.confidenceFactors)
                  .filter(([k]) => k !== "total")
                  .map(([k, v]) => (
                    <div key={k} className="flex justify-between">
                      <span className="text-zinc-600 capitalize">
                        {k.replace(/([A-Z])/g, " $1")}
                      </span>
                      <span className="text-zinc-300">
                        {(v as number).toFixed(1)}%
                      </span>
                    </div>
                  ))}
                <div className="flex justify-between border-t border-zinc-800 pt-1 font-semibold">
                  <span className="text-zinc-400">Total</span>
                  <span className="text-violet-400">
                    {selectedDecision.confidenceFactors.total.toFixed(1)}%
                  </span>
                </div>
              </div>
              {selectedDecision.skipReason && (
                <div className="rounded-lg bg-zinc-800 px-2 py-1.5 text-xs text-zinc-400">
                  Skip: {selectedDecision.skipReason}
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {tab === "notrade" && (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 overflow-x-auto">
          {!noTradeLog || noTradeLog.length === 0 ? (
            <p className="text-sm text-zinc-600 py-8 text-center">
              No no-trade decisions logged
            </p>
          ) : (
            <table className="w-full text-xs">
              <thead>
                <tr className="text-zinc-600 border-b border-zinc-800">
                  <th className="text-left py-2 px-4">Symbol</th>
                  <th className="text-left py-2 px-4">Reason</th>
                  <th className="text-right py-2 px-4">Confidence</th>
                  <th className="text-right py-2 px-4">Threshold</th>
                  <th className="text-left py-2 px-4">Regime</th>
                  <th className="text-left py-2 px-4">Time</th>
                </tr>
              </thead>
              <tbody>
                {[...noTradeLog]
                  .reverse()
                  .slice(0, 100)
                  .map((n, i) => (
                    <tr
                      key={`ntl-${n.symbol}-${i}`}
                      className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                    >
                      <td className="py-2 px-4 font-medium text-zinc-200">
                        {n.symbol}
                      </td>
                      <td className="py-2 px-4">
                        <Badge className="bg-orange-500/20 text-orange-300">
                          {n.reason}
                        </Badge>
                      </td>
                      <td className="text-right py-2 px-4 text-zinc-300">
                        {n.confidenceAtTime.toFixed(1)}%
                      </td>
                      <td className="text-right py-2 px-4 text-zinc-500">
                        {n.thresholdAtTime.toFixed(1)}%
                      </td>
                      <td className="py-2 px-4">
                        <Badge
                          className={regimeBadgeClass(n.marketRegime as any)}
                        >
                          {regimeLabel(n.marketRegime as any)}
                        </Badge>
                      </td>
                      <td className="py-2 px-4 text-zinc-600">
                        {fmtTime(n.timestamp)}
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {tab === "confidence" && (
        <div className="space-y-3">
          <div className="flex gap-2 flex-wrap">
            {ASSETS.map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => setAsset(a)}
                className={`px-2.5 py-1 rounded-lg text-xs font-medium transition-colors ${
                  asset === a
                    ? "bg-violet-600 text-white"
                    : "bg-zinc-800 text-zinc-400 hover:text-zinc-200"
                }`}
              >
                {a}
              </button>
            ))}
          </div>
          <div className="rounded-xl border border-zinc-800 bg-zinc-900 overflow-x-auto">
            {!timeline || timeline.length === 0 ? (
              <p className="text-sm text-zinc-600 py-8 text-center">
                No confidence data for {asset}
              </p>
            ) : (
              <table className="w-full text-xs">
                <thead>
                  <tr className="text-zinc-600 border-b border-zinc-800">
                    <th className="text-left py-2 px-4">Time</th>
                    <th className="text-left py-2 px-4">Action</th>
                    <th className="text-right py-2 px-4">Confidence</th>
                    <th className="text-left py-2 px-4">Regime</th>
                  </tr>
                </thead>
                <tbody>
                  {[...timeline].reverse().map((p, i) => (
                    <tr
                      key={`cp-${String(p.timestamp)}-${i}`}
                      className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                    >
                      <td className="py-2 px-4 text-zinc-600">
                        {new Date(Number(p.timestamp) * 1000).toLocaleString()}
                      </td>
                      <td className="py-2 px-4">
                        <Badge
                          className={
                            p.action === "BUY"
                              ? "bg-emerald-500/20 text-emerald-400"
                              : p.action === "SELL"
                                ? "bg-red-500/20 text-red-400"
                                : "bg-zinc-700 text-zinc-500"
                          }
                        >
                          {p.action}
                        </Badge>
                      </td>
                      <td className="text-right py-2 px-4 text-zinc-300">
                        {p.confidence.toFixed(1)}%
                      </td>
                      <td className="py-2 px-4 text-zinc-500">{p.regime}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

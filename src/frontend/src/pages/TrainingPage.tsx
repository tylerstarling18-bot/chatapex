import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Badge } from "../components/Badge";
import { Button } from "../components/Button";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { SectionHeader } from "../components/SectionHeader";
import { StatCard } from "../components/StatCard";
import {
  useAITrainingState,
  useMarketMemory,
  useStrategyPerformances,
} from "../hooks/useAI";
import { useClient } from "../lib/backend-client";
import { fmtPct, fmtUSD } from "../lib/format";
import { regimeBadgeClass, regimeLabel } from "../lib/regime";

export function TrainingPage() {
  const { data: state, isLoading } = useAITrainingState();
  const { data: stratPerf } = useStrategyPerformances();
  const { data: memory } = useMarketMemory();
  const qc = useQueryClient();
  const client = useClient();
  const resetTraining = useMutation({
    mutationFn: () => client.resetTrainingData(),
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["trainingState"] });
      qc.invalidateQueries({ queryKey: ["stratPerf"] });
      qc.invalidateQueries({ queryKey: ["marketMemory"] });
    },
  });

  if (isLoading) return <LoadingSpinner />;

  return (
    <div className="p-6 space-y-6">
      <SectionHeader
        title="AI Training"
        description="Training state, strategy performance and market memory"
        actions={
          <Button
            variant="secondary"
            size="sm"
            onClick={() => resetTraining.mutate()}
            loading={resetTraining.isPending}
          >
            Reset Training
          </Button>
        }
      />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard label="Sessions" value={String(state?.totalSessions ?? 0)} />
        <StatCard
          label="Practice Trades"
          value={String(state?.practiceTradesCount ?? 0)}
        />
        <StatCard
          label="Overall Win Rate"
          value={`${((state?.overallWinRate ?? 0) * 100).toFixed(1)}%`}
        />
        <StatCard
          label="Avg Confidence"
          value={`${(state?.avgConfidenceScore ?? 0).toFixed(1)}%`}
        />
        <StatCard
          label="Learning Progress"
          value={`${(state?.learningProgress ?? 0).toFixed(1)}%`}
        />
        <StatCard
          label="Confidence Threshold"
          value={`${(state?.confidenceThreshold ?? 0).toFixed(1)}%`}
        />
        <StatCard
          label="Consecutive Losses"
          value={String(state?.consecutiveLosses ?? 0)}
        />
        <StatCard
          label="Overtrading Count"
          value={String(state?.overtradingCount ?? 0)}
        />
      </div>

      {stratPerf && stratPerf.length > 0 && (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
          <h3 className="text-sm font-semibold text-zinc-200 mb-3">
            Strategy Performance
          </h3>
          <table className="w-full text-xs">
            <thead>
              <tr className="text-zinc-600 border-b border-zinc-800">
                <th className="text-left py-2 px-4">Strategy</th>
                <th className="text-right py-2 px-4">Trades</th>
                <th className="text-right py-2 px-4">W/L</th>
                <th className="text-right py-2 px-4">Win Rate</th>
                <th className="text-right py-2 px-4">Total PnL</th>
                <th className="text-right py-2 px-4">Avg Confidence</th>
              </tr>
            </thead>
            <tbody>
              {stratPerf.map((s) => (
                <tr
                  key={String(s.strategyMode)}
                  className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                >
                  <td className="py-2 px-4 font-medium text-zinc-200">
                    {s.strategyMode}
                  </td>
                  <td className="text-right py-2 px-4 text-zinc-300">
                    {String(s.totalTrades)}
                  </td>
                  <td className="text-right py-2 px-4 text-zinc-400">
                    {String(s.wins)}W / {String(s.losses)}L
                  </td>
                  <td className="text-right py-2 px-4 text-zinc-300">
                    {(s.winRate * 100).toFixed(1)}%
                  </td>
                  <td
                    className={`text-right py-2 px-4 font-medium ${s.totalPnl >= 0 ? "text-emerald-400" : "text-red-400"}`}
                  >
                    {fmtUSD(s.totalPnl)}
                  </td>
                  <td className="text-right py-2 px-4 text-zinc-400">
                    {s.avgConfidence.toFixed(1)}%
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {memory && memory.length > 0 && (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
          <h3 className="text-sm font-semibold text-zinc-200 mb-3">
            Market Memory (Strategy × Regime)
          </h3>
          <table className="w-full text-xs">
            <thead>
              <tr className="text-zinc-600 border-b border-zinc-800">
                <th className="text-left py-2 px-4">Strategy</th>
                <th className="text-left py-2 px-4">Regime</th>
                <th className="text-right py-2 px-4">W/L</th>
                <th className="text-right py-2 px-4">Total PnL</th>
                <th className="text-right py-2 px-4">Avg PnL</th>
              </tr>
            </thead>
            <tbody>
              {memory.map((m) => (
                <tr
                  key={`${String(m.strategyMode)}-${String(m.marketCondition)}`}
                  className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                >
                  <td className="py-2 px-4 text-zinc-300">{m.strategyMode}</td>
                  <td className="py-2 px-4">
                    <Badge
                      className={regimeBadgeClass(m.marketCondition as any)}
                    >
                      {regimeLabel(m.marketCondition as any)}
                    </Badge>
                  </td>
                  <td className="text-right py-2 px-4 text-zinc-400">
                    {String(m.winCount)}W / {String(m.lossCount)}L
                  </td>
                  <td
                    className={`text-right py-2 px-4 ${m.totalPnl >= 0 ? "text-emerald-400" : "text-red-400"}`}
                  >
                    {fmtUSD(m.totalPnl)}
                  </td>
                  <td
                    className={`text-right py-2 px-4 ${m.avgPnl >= 0 ? "text-emerald-400" : "text-red-400"}`}
                  >
                    {fmtUSD(m.avgPnl)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {state?.noTradeLog && state.noTradeLog.length > 0 && (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
          <h3 className="text-sm font-semibold text-zinc-200 mb-3">
            No-Trade Log (recent {Math.min(state.noTradeLog.length, 20)})
          </h3>
          <table className="w-full text-xs">
            <thead>
              <tr className="text-zinc-600 border-b border-zinc-800">
                <th className="text-left py-2 px-4">Symbol</th>
                <th className="text-left py-2 px-4">Reason</th>
                <th className="text-right py-2 px-4">Confidence</th>
                <th className="text-right py-2 px-4">Threshold</th>
              </tr>
            </thead>
            <tbody>
              {[...state.noTradeLog]
                .reverse()
                .slice(0, 20)
                .map((n, i) => (
                  <tr
                    key={`ntl-${n.symbol}-${i}`}
                    className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                  >
                    <td className="py-2 px-4 text-zinc-200">{n.symbol}</td>
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
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

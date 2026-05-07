import {
  Activity,
  AlertTriangle,
  Pause,
  Play,
  RefreshCw,
  StopCircle,
  TrendingDown,
  TrendingUp,
  Wifi,
  WifiOff,
} from "lucide-react";
import { useState } from "react";
import { BotStatus } from "../backend";
import { Badge } from "../components/Badge";
import { Button } from "../components/Button";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { SectionHeader } from "../components/SectionHeader";
import { StatCard } from "../components/StatCard";
import { StatusBanner } from "../components/StatusBanner";
import { useLiveActivityFeed } from "../hooks/useAI";
import {
  useBotConfig,
  useBotState,
  useDataFeedStatus,
  useDecisionCycleStats,
  useEmergencyStop,
  usePauseBot,
  useResetBot,
  useResumeBot,
  useSimulationStats,
  useStartBot,
} from "../hooks/useBot";
import {
  useCurrentMarketCondition,
  useLatestSnapshot,
} from "../hooks/useMarket";
import { useRiskStatus } from "../hooks/useRisk";
import { useCurrentEquity, usePortfolio } from "../hooks/useTrading";
import {
  fmtCompact,
  fmtPct,
  fmtTimeSec,
  fmtUSD,
  pctColor,
} from "../lib/format";
import { regimeBadgeClass, regimeLabel } from "../lib/regime";

export function DashboardPage() {
  const { data: bot } = useBotState();
  const { data: config } = useBotConfig();
  const { data: portfolio } = usePortfolio();
  const { data: equity } = useCurrentEquity();
  const { data: activity } = useLiveActivityFeed(15);
  const { data: risk } = useRiskStatus();
  const { data: snapshot } = useLatestSnapshot();
  const { data: condition } = useCurrentMarketCondition();
  const { data: stats } = useDecisionCycleStats();
  const { data: simStats } = useSimulationStats();
  const { data: feed } = useDataFeedStatus();

  const startBot = useStartBot();
  const pauseBot = usePauseBot();
  const resumeBot = useResumeBot();
  const emergencyStop = useEmergencyStop();
  const resetBot = useResetBot();

  const [resetConfirm, setResetConfirm] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isRunning = bot?.status === BotStatus.Running;
  const isPaused = bot?.status === BotStatus.Paused;
  const isStopped = bot?.status === BotStatus.Stopped;
  const isEmergency = bot?.status === BotStatus.EmergencyStopped;

  async function handleStart() {
    setError(null);
    const r = await startBot.mutateAsync();
    if (r && "__kind__" in r && r.__kind__ === "err") {
      setError((r as { __kind__: "err"; err: string }).err);
    }
  }

  const pnl = portfolio?.totalPnl ?? 0;
  const pnlPct = portfolio?.totalPnlPercent ?? 0;

  return (
    <div className="p-6 space-y-6">
      <SectionHeader
        title="Dashboard"
        description="Bot controls and live portfolio overview"
      />

      {/* Error banner */}
      {error && <StatusBanner type="error" message={error} />}

      {/* Risk paused warning */}
      {risk?.isPaused && (
        <StatusBanner
          type="warning"
          message="Risk manager has paused all trading. Go to Risk page to resume."
        />
      )}

      {/* Emergency stop banner */}
      {isEmergency && (
        <StatusBanner
          type="error"
          message="Emergency stop active — all trading halted."
        />
      )}

      {/* Bot Controls */}
      <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-3">
            <div
              className={`w-3 h-3 rounded-full ${
                isRunning
                  ? "bg-emerald-400 animate-pulse"
                  : isPaused
                    ? "bg-yellow-400"
                    : isEmergency
                      ? "bg-red-500 animate-pulse"
                      : "bg-zinc-600"
              }`}
            />
            <span className="font-semibold text-zinc-100">
              {bot?.status ?? "Loading"}
            </span>
            {isRunning && (
              <span className="text-sm text-zinc-500">
                Uptime {fmtTimeSec(bot?.uptimeSeconds ?? 0n)}
              </span>
            )}
          </div>
          <div className="flex items-center gap-1.5">
            {feed?.healthy ? (
              <span className="flex items-center gap-1 text-xs text-emerald-400">
                <Wifi size={12} /> Live
              </span>
            ) : (
              <span className="flex items-center gap-1 text-xs text-red-400">
                <WifiOff size={12} /> No Feed
              </span>
            )}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {(isStopped || isEmergency) && (
            <Button onClick={handleStart} loading={startBot.isPending}>
              <Play size={14} /> Start Bot
            </Button>
          )}
          {isRunning && (
            <Button
              variant="secondary"
              onClick={() => pauseBot.mutate()}
              loading={pauseBot.isPending}
            >
              <Pause size={14} /> Pause
            </Button>
          )}
          {isPaused && (
            <Button
              onClick={() => resumeBot.mutate()}
              loading={resumeBot.isPending}
            >
              <Play size={14} /> Resume
            </Button>
          )}
          {(isRunning || isPaused) && (
            <Button
              variant="danger"
              onClick={() => emergencyStop.mutate()}
              loading={emergencyStop.isPending}
            >
              <StopCircle size={14} /> Emergency Stop
            </Button>
          )}
          {!isRunning &&
            (resetConfirm ? (
              <>
                <span className="text-xs text-zinc-400">Confirm reset?</span>
                <Button
                  variant="danger"
                  size="sm"
                  onClick={() => {
                    resetBot.mutate();
                    setResetConfirm(false);
                  }}
                  loading={resetBot.isPending}
                >
                  Yes, Reset
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setResetConfirm(false)}
                >
                  Cancel
                </Button>
              </>
            ) : (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setResetConfirm(true)}
              >
                <RefreshCw size={12} /> Reset
              </Button>
            ))}
        </div>

        {config && (
          <div className="mt-3 flex flex-wrap gap-3 text-xs text-zinc-500">
            <span>
              Mode: <span className="text-zinc-300">{config.tradingMode}</span>
            </span>
            <span>
              Balance:{" "}
              <span className="text-zinc-300">
                {fmtUSD(config.startingBalance)}
              </span>
            </span>
            <span>
              Refresh:{" "}
              <span className="text-zinc-300">
                {Number(config.refreshIntervalSecs)}s
              </span>
            </span>
            <span>
              Decision:{" "}
              <span className="text-zinc-300">
                {Number(config.decisionIntervalSecs)}s
              </span>
            </span>
          </div>
        )}
      </div>

      {/* Portfolio Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard
          label="Portfolio Value"
          value={fmtUSD(portfolio?.totalValue ?? 0)}
          sub={<span className={pctColor(pnlPct)}>{fmtPct(pnlPct)} total</span>}
          icon={<TrendingUp size={16} />}
        />
        <StatCard
          label="Total PnL"
          value={<span className={pctColor(pnl)}>{fmtUSD(pnl)}</span>}
          sub={<span className={pctColor(pnl)}>{fmtPct(pnlPct)}</span>}
        />
        <StatCard
          label="Cash Balance"
          value={fmtUSD(portfolio?.cashBalance ?? 0)}
          sub={`Invested: ${fmtUSD(portfolio?.investedValue ?? 0)}`}
        />
        <StatCard
          label="Win Rate"
          value={`${(portfolio?.winRate ?? 0).toFixed(1)}%`}
          sub={`${portfolio?.winningTrades ?? 0}W / ${Number(portfolio?.totalTrades ?? 0n) - Number(portfolio?.winningTrades ?? 0n)}L`}
        />
      </div>

      {/* Cycle + Market */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard
          label="Decision Cycles"
          value={String(stats?.totalCycles ?? 0)}
          sub={`${(stats?.noTradeRate ?? 0 * 100).toFixed(1)}% no-trade`}
        />
        <StatCard
          label="Avg Confidence"
          value={`${(stats?.avgConfidence ?? 0).toFixed(1)}%`}
          sub="across all decisions"
        />
        <StatCard
          label="Market Condition"
          value={
            <Badge className={regimeBadgeClass(condition ?? null)}>
              {regimeLabel(condition ?? null)}
            </Badge>
          }
          sub={
            snapshot ? `${snapshot.markets.length} assets tracked` : "No data"
          }
        />
        <StatCard
          label="Market Cap"
          value={fmtCompact(snapshot?.totalMarketCap ?? 0)}
          sub={`BTC Dom: ${(snapshot?.btcDominance ?? 0).toFixed(1)}%`}
        />
      </div>

      {/* Equity + Costs */}
      {equity && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <StatCard
            label="Equity"
            value={fmtUSD(equity.equity)}
            sub={`Cash: ${fmtUSD(equity.cash)}`}
          />
          <StatCard
            label="Unrealized PnL"
            value={
              <span className={pctColor(equity.unrealizedPnL)}>
                {fmtUSD(equity.unrealizedPnL)}
              </span>
            }
          />
          <StatCard
            label="Today's PnL"
            value={
              <span className={pctColor(equity.realizedPnLToday)}>
                {fmtUSD(equity.realizedPnLToday)}
              </span>
            }
            sub={fmtPct(equity.dailyPnLPct)}
          />
          <StatCard
            label="Sim Costs"
            value={fmtUSD(
              (simStats?.totalFeeCost ?? 0) +
                (simStats?.totalSlippageCost ?? 0),
            )}
            sub={`Fees: ${fmtUSD(simStats?.totalFeeCost ?? 0)}`}
          />
        </div>
      )}

      {/* Live Activity Feed */}
      <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
        <div className="flex items-center gap-2 mb-3">
          <Activity size={16} className="text-violet-400" />
          <h3 className="text-sm font-semibold text-zinc-200">
            Live Activity Feed
          </h3>
          <span className="ml-auto text-xs text-zinc-600">
            {activity?.length ?? 0} recent events
          </span>
        </div>
        {!activity || activity.length === 0 ? (
          <p className="text-sm text-zinc-600 py-4 text-center">
            No activity yet — start the bot and run a decision cycle
          </p>
        ) : (
          <div className="space-y-1.5 max-h-80 overflow-y-auto">
            {activity.map((item, i) => (
              <div
                key={`${item.asset}-${String(item.timestamp)}-${i}`}
                className="flex items-start gap-3 rounded-lg px-3 py-2 bg-zinc-950 text-xs"
              >
                <span
                  className={`mt-0.5 font-bold w-8 shrink-0 ${
                    item.action === "BUY"
                      ? "text-emerald-400"
                      : item.action === "SELL"
                        ? "text-red-400"
                        : "text-zinc-500"
                  }`}
                >
                  {item.action}
                </span>
                <span className="text-zinc-300 font-medium w-10 shrink-0">
                  {item.asset}
                </span>
                <span className="text-zinc-500 flex-1 truncate">
                  {item.reasoning}
                </span>
                <span className="text-zinc-600 shrink-0">
                  {item.confidence.toFixed(0)}%
                </span>
                {item.executed && (
                  <span className="text-emerald-400 shrink-0">✓</span>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Market overview */}
      {snapshot && (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
          <h3 className="text-sm font-semibold text-zinc-200 mb-3">
            Market Overview
          </h3>
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-zinc-600 border-b border-zinc-800">
                  <th className="text-left py-1.5 pr-4">Asset</th>
                  <th className="text-right py-1.5 pr-4">Price</th>
                  <th className="text-right py-1.5 pr-4">24h %</th>
                  <th className="text-right py-1.5 pr-4">Volume</th>
                  <th className="text-right py-1.5">Market Cap</th>
                </tr>
              </thead>
              <tbody>
                {snapshot.markets.map((m) => (
                  <tr
                    key={m.symbol}
                    className="border-b border-zinc-800/50 hover:bg-zinc-800/20"
                  >
                    <td className="py-1.5 pr-4 font-medium text-zinc-200">
                      {m.symbol}
                    </td>
                    <td className="text-right py-1.5 pr-4 text-zinc-300">
                      {fmtUSD(m.price)}
                    </td>
                    <td
                      className={`text-right py-1.5 pr-4 font-medium ${pctColor(m.change24h)}`}
                    >
                      {fmtPct(m.change24h)}
                    </td>
                    <td className="text-right py-1.5 pr-4 text-zinc-400">
                      {fmtCompact(m.volume24h)}
                    </td>
                    <td className="text-right py-1.5 text-zinc-400">
                      {fmtCompact(m.marketCap)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

import { Cpu, RefreshCw } from "lucide-react";
import { BotStatus } from "../backend";
import {
  useBotState,
  useRunDecisionCycle,
  useRunMarketCycle,
} from "../hooks/useBot";
import { useRiskStatus } from "../hooks/useRisk";
import { fmtTimeSec } from "../lib/format";
import { cn } from "../lib/utils";
import { Button } from "./Button";

export function TopBar() {
  const { data: bot } = useBotState();
  const { data: risk } = useRiskStatus();
  const runMarket = useRunMarketCycle();
  const runDecision = useRunDecisionCycle();

  const statusColor: Record<BotStatus, string> = {
    [BotStatus.Running]: "bg-emerald-400",
    [BotStatus.Paused]: "bg-yellow-400",
    [BotStatus.Stopped]: "bg-zinc-500",
    [BotStatus.EmergencyStopped]: "bg-red-500",
  };

  const uptime = bot?.uptimeSeconds ? fmtTimeSec(bot.uptimeSeconds) : "--";

  return (
    <header className="h-14 bg-zinc-950 border-b border-zinc-800 flex items-center px-4 gap-4">
      <div className="flex items-center gap-2">
        <span
          className={cn(
            "w-2.5 h-2.5 rounded-full animate-pulse",
            bot?.status ? statusColor[bot.status] : "bg-zinc-600",
          )}
        />
        <span className="text-sm text-zinc-400">
          {bot?.status ?? "Loading"}
        </span>
        {bot?.status === BotStatus.Running && (
          <span className="text-xs text-zinc-600">Uptime {uptime}</span>
        )}
      </div>

      {risk?.isPaused && (
        <span className="ml-2 rounded-full bg-yellow-500/15 border border-yellow-500/30 px-2 py-0.5 text-xs text-yellow-300">
          Risk Paused
        </span>
      )}

      <div className="ml-auto flex items-center gap-2">
        <Button
          variant="secondary"
          size="sm"
          loading={runMarket.isPending}
          onClick={() => runMarket.mutate()}
        >
          <RefreshCw size={12} />
          Refresh Market
        </Button>
        <Button
          variant="secondary"
          size="sm"
          loading={runDecision.isPending}
          onClick={() => runDecision.mutate()}
          disabled={bot?.status !== BotStatus.Running}
        >
          <Cpu size={12} />
          Run Cycle
        </Button>
      </div>
    </header>
  );
}

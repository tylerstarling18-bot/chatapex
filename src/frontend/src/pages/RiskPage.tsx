import { useState } from "react";
import type { RiskSettings } from "../backend";
import { RiskSeverity } from "../backend";
import { Badge } from "../components/Badge";
import { Button } from "../components/Button";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { SectionHeader } from "../components/SectionHeader";
import { StatCard } from "../components/StatCard";
import { StatusBanner } from "../components/StatusBanner";
import {
  useResumeTrading,
  useRiskEvents,
  useRiskSettings,
  useRiskStatus,
  useTriggerEmergencyStop,
  useUpdateRiskSettings,
} from "../hooks/useRisk";
import { fmtTime, fmtUSD } from "../lib/format";

export function RiskPage() {
  const { data: status } = useRiskStatus();
  const { data: settings, isLoading } = useRiskSettings();
  const { data: events } = useRiskEvents(30);
  const updateSettings = useUpdateRiskSettings();
  const emergencyStop = useTriggerEmergencyStop();
  const resumeTrading = useResumeTrading();

  const [editSettings, setEditSettings] = useState<RiskSettings | null>(null);
  const editing = editSettings ?? settings;

  if (isLoading) return <LoadingSpinner />;

  function handleSave() {
    if (!editSettings) return;
    updateSettings.mutate(editSettings);
    setEditSettings(null);
  }

  return (
    <div className="p-6 space-y-6">
      <SectionHeader
        title="Risk Management"
        description="Risk controls, events and emergency stop"
        actions={
          <div className="flex gap-2">
            {status?.isPaused ? (
              <Button
                onClick={() => resumeTrading.mutate()}
                loading={resumeTrading.isPending}
              >
                Resume Trading
              </Button>
            ) : (
              <Button
                variant="danger"
                onClick={() => emergencyStop.mutate()}
                loading={emergencyStop.isPending}
              >
                Emergency Stop
              </Button>
            )}
          </div>
        }
      />

      {status?.isPaused && (
        <StatusBanner
          type="warning"
          message="Trading is currently PAUSED by the risk manager."
        />
      )}

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard
          label="Trading Status"
          value={
            <span
              className={status?.isPaused ? "text-red-400" : "text-emerald-400"}
            >
              {status?.isPaused ? "Paused" : "Active"}
            </span>
          }
        />
        <StatCard
          label="Daily Loss"
          value={fmtUSD(status?.dailyLoss ?? 0)}
          sub={`${(status?.dailyLossPercent ?? 0).toFixed(2)}%`}
        />
        <StatCard
          label="Consecutive Losses"
          value={String(status?.consecutiveLosses ?? 0)}
        />
        <StatCard
          label="Risk Score"
          value={`${(status?.riskScore ?? 0).toFixed(1)}`}
        />
      </div>

      {/* Settings editor */}
      {editing && (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-zinc-200">
              Risk Settings
            </h3>
            <div className="flex gap-2">
              {editSettings && (
                <>
                  <Button
                    size="sm"
                    onClick={handleSave}
                    loading={updateSettings.isPending}
                  >
                    Save
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setEditSettings(null)}
                  >
                    Cancel
                  </Button>
                </>
              )}
              {!editSettings && (
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => setEditSettings({ ...settings! })}
                >
                  Edit
                </Button>
              )}
            </div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            <div>
              <label
                htmlFor="maxDailyLoss"
                className="text-xs text-zinc-500 block mb-1"
              >
                Max Daily Loss %
              </label>
              <input
                id="maxDailyLoss"
                onChange={(e) =>
                  setEditSettings((s) =>
                    s
                      ? {
                          ...s,
                          maxDailyLossPercent: Number.parseFloat(
                            e.target.value,
                          ),
                        }
                      : s,
                  )
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200 disabled:opacity-50"
              />
            </div>
            <div>
              <label
                htmlFor="maxPosSize"
                className="text-xs text-zinc-500 block mb-1"
              >
                Max Position Size %
              </label>
              <input
                id="maxPosSize"
                type="number"
                step="0.5"
                value={editing.maxPositionSizePercent}
                disabled={!editSettings}
                onChange={(e) =>
                  setEditSettings((s) =>
                    s
                      ? {
                          ...s,
                          maxPositionSizePercent: Number.parseFloat(
                            e.target.value,
                          ),
                        }
                      : s,
                  )
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200 disabled:opacity-50"
              />
            </div>
            <div>
              <label
                htmlFor="maxConsecLoss"
                className="text-xs text-zinc-500 block mb-1"
              >
                Max Consecutive Losses
              </label>
              <input
                id="maxConsecLoss"
                type="number"
                min="1"
                value={Number(editing.maxConsecutiveLosses)}
                disabled={!editSettings}
                onChange={(e) =>
                  setEditSettings((s) =>
                    s
                      ? {
                          ...s,
                          maxConsecutiveLosses: BigInt(
                            Number.parseInt(e.target.value),
                          ),
                        }
                      : s,
                  )
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200 disabled:opacity-50"
              />
            </div>
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="paperTrading"
                checked={editing.enablePaperTrading}
                disabled={!editSettings}
                onChange={(e) =>
                  setEditSettings((s) =>
                    s ? { ...s, enablePaperTrading: e.target.checked } : s,
                  )
                }
                className="rounded"
              />
              <label htmlFor="paperTrading" className="text-sm text-zinc-300">
                Paper Trading
              </label>
            </div>
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="conservativeMode"
                checked={editing.conservativeMode}
                disabled={!editSettings}
                onChange={(e) =>
                  setEditSettings((s) =>
                    s ? { ...s, conservativeMode: e.target.checked } : s,
                  )
                }
                className="rounded"
              />
              <label
                htmlFor="conservativeMode"
                className="text-sm text-zinc-300"
              >
                Conservative Mode
              </label>
            </div>
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="emergencyStop"
                checked={editing.emergencyStopEnabled}
                disabled={!editSettings}
                onChange={(e) =>
                  setEditSettings((s) =>
                    s ? { ...s, emergencyStopEnabled: e.target.checked } : s,
                  )
                }
                className="rounded"
              />
              <label htmlFor="emergencyStop" className="text-sm text-zinc-300">
                Emergency Stop Enabled
              </label>
            </div>
          </div>
        </div>
      )}

      {/* Risk Events */}
      <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
        <h3 className="text-sm font-semibold text-zinc-200 mb-3">
          Risk Events
        </h3>
        {!events || events.length === 0 ? (
          <p className="text-sm text-zinc-600 py-4 text-center">
            No risk events recorded
          </p>
        ) : (
          <table className="w-full text-xs">
            <thead>
              <tr className="text-zinc-600 border-b border-zinc-800">
                <th className="text-left py-2 px-4">Severity</th>
                <th className="text-left py-2 px-4">Type</th>
                <th className="text-left py-2 px-4">Message</th>
                <th className="text-left py-2 px-4">Time</th>
              </tr>
            </thead>
            <tbody>
              {events.map((ev) => (
                <tr
                  key={ev.id}
                  className="border-b border-zinc-800/40 hover:bg-zinc-800/20"
                >
                  <td className="py-2 px-4">
                    <Badge
                      className={
                        ev.severity === RiskSeverity.Critical
                          ? "bg-red-500/20 text-red-400"
                          : ev.severity === RiskSeverity.Warning
                            ? "bg-yellow-500/20 text-yellow-300"
                            : "bg-blue-500/20 text-blue-400"
                      }
                    >
                      {ev.severity}
                    </Badge>
                  </td>
                  <td className="py-2 px-4 text-zinc-400">{ev.eventType}</td>
                  <td className="py-2 px-4 text-zinc-300">{ev.message}</td>
                  <td className="py-2 px-4 text-zinc-600">
                    {fmtTime(ev.timestamp)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

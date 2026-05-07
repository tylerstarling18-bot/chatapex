import { useState } from "react";
import { Badge } from "../components/Badge";
import { Button } from "../components/Button";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBanner } from "../components/StatusBanner";
import {
  useExchangeBalances,
  useExchangeConnections,
  useRemoveExchange,
  useSaveExchange,
  useTestExchange,
} from "../hooks/useExchange";
import { fmtTime } from "../lib/format";

const EXCHANGES = ["binance", "coinbase", "kraken", "okx"];

export function ExchangePage() {
  const { data: connections, isLoading } = useExchangeConnections();
  const saveExchange = useSaveExchange();
  const removeExchange = useRemoveExchange();
  const testExchange = useTestExchange();
  const [showForm, setShowForm] = useState(false);
  const [selectedExchange, setSelectedExchange] = useState<string | null>(null);
  const { data: balances } = useExchangeBalances(selectedExchange);
  const [form, setForm] = useState({
    exchangeId: "binance",
    apiKey: "",
    apiSecret: "",
  });
  const [saveError, setSaveError] = useState<string | null>(null);

  async function handleSave() {
    setSaveError(null);
    if (!form.apiKey || !form.apiSecret) {
      setSaveError("API key and secret are required");
      return;
    }
    await saveExchange.mutateAsync(form);
    setShowForm(false);
    setForm({ exchangeId: "binance", apiKey: "", apiSecret: "" });
  }

  return (
    <div className="p-6 space-y-6">
      <SectionHeader
        title="Exchange Connections"
        description="Phase 1: API key storage (read-only). Phase 2: live trading integration."
        actions={
          <Button
            onClick={() => setShowForm(!showForm)}
            variant={showForm ? "ghost" : "primary"}
          >
            {showForm ? "Cancel" : "Add Exchange"}
          </Button>
        }
      />

      <StatusBanner
        type="info"
        message="Phase 1: Keys are obfuscated in canister memory. Live trading requires Phase 2 (vetKD encryption + HMAC signing)."
      />

      {showForm && (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4 space-y-4">
          <h3 className="text-sm font-semibold text-zinc-200">
            Connect Exchange
          </h3>
          {saveError && <StatusBanner type="error" message={saveError} />}
          <div className="grid grid-cols-1 gap-4 max-w-md">
            <div>
              <label
                htmlFor="exchId"
                className="text-xs text-zinc-500 block mb-1"
              >
                Exchange
              </label>
              <select
                id="exchId"
                value={form.exchangeId}
                onChange={(e) =>
                  setForm((f) => ({ ...f, exchangeId: e.target.value }))
                }
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              >
                {EXCHANGES.map((e) => (
                  <option key={e} value={e} className="capitalize">
                    {e}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label
                htmlFor="apiKey"
                className="text-xs text-zinc-500 block mb-1"
              >
                API Key
              </label>
              <input
                id="apiKey"
                value={form.apiKey}
                onChange={(e) =>
                  setForm((f) => ({ ...f, apiKey: e.target.value }))
                }
                placeholder="Your API key"
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              />
            </div>
            <div>
              <label
                htmlFor="apiSecret"
                className="text-xs text-zinc-500 block mb-1"
              >
                API Secret
              </label>
              <input
                id="apiSecret"
                type="password"
                onChange={(e) =>
                  setForm((f) => ({ ...f, apiSecret: e.target.value }))
                }
                placeholder="Your API secret"
                className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-200"
              />
            </div>
          </div>
          <Button onClick={handleSave} loading={saveExchange.isPending}>
            Save Connection
          </Button>
        </div>
      )}

      {isLoading ? (
        <LoadingSpinner />
      ) : !connections || connections.length === 0 ? (
        <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-8 text-center">
          <p className="text-zinc-500 text-sm">
            No exchange connections configured
          </p>
          <p className="text-zinc-600 text-xs mt-1">
            Add an exchange to view balances and order history
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {connections.map((c) => (
            <div
              key={c.exchangeId}
              className="rounded-xl border border-zinc-800 bg-zinc-900 p-4"
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-zinc-800 flex items-center justify-center text-xs font-bold text-zinc-400">
                    {c.exchangeId[0].toUpperCase()}
                  </div>
                  <div>
                    <p className="font-semibold text-zinc-200 capitalize">
                      {c.exchangeId}
                    </p>
                    <p className="text-xs text-zinc-500">
                      Phase {String(c.phase)} • Last tested:{" "}
                      {c.lastTestTimestamp
                        ? fmtTime(c.lastTestTimestamp)
                        : "Never"}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <Badge
                    className={
                      c.connected
                        ? "bg-emerald-500/20 text-emerald-400"
                        : "bg-zinc-700 text-zinc-500"
                    }
                  >
                    {c.connected ? "Connected" : "Disconnected"}
                  </Badge>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => testExchange.mutate(c.exchangeId)}
                    loading={
                      testExchange.isPending &&
                      testExchange.variables === c.exchangeId
                    }
                  >
                    Test
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() =>
                      setSelectedExchange(
                        selectedExchange === c.exchangeId ? null : c.exchangeId,
                      )
                    }
                  >
                    {selectedExchange === c.exchangeId
                      ? "Hide Balances"
                      : "View Balances"}
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => removeExchange.mutate(c.exchangeId)}
                    loading={removeExchange.isPending}
                  >
                    Remove
                  </Button>
                </div>
              </div>

              {selectedExchange === c.exchangeId &&
                balances &&
                balances.length > 0 && (
                  <div className="mt-4 border-t border-zinc-800 pt-3">
                    <p className="text-xs text-zinc-500 mb-2">
                      Balances (simulated — Phase 1)
                    </p>
                    <div className="flex flex-wrap gap-2">
                      {balances.map((b) => (
                        <div
                          key={b.asset}
                          className="rounded-lg bg-zinc-800 px-3 py-2 text-xs"
                        >
                          <p className="text-zinc-400 font-semibold">
                            {b.asset}
                          </p>
                          <p className="text-zinc-300">
                            Free: {b.free.toFixed(4)}
                          </p>
                          <p className="text-zinc-500">
                            Locked: {b.locked.toFixed(4)}
                          </p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

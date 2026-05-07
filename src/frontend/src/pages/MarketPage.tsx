import { RefreshCw } from "lucide-react";
import { Badge } from "../components/Badge";
import { Button } from "../components/Button";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { SectionHeader } from "../components/SectionHeader";
import { StatCard } from "../components/StatCard";
import {
  useCurrentMarketCondition,
  useFetchMarketData,
  useLatestSnapshot,
} from "../hooks/useMarket";
import { fmtCompact, fmtPct, fmtUSD, pctColor } from "../lib/format";
import { regimeBadgeClass, regimeLabel } from "../lib/regime";

export function MarketPage() {
  const { data: markets, isLoading, refetch } = useFetchMarketData();
  const { data: snapshot } = useLatestSnapshot();
  const { data: condition } = useCurrentMarketCondition();

  return (
    <div className="p-6 space-y-6">
      <SectionHeader
        title="Market Data"
        description="Live market overview from CoinGecko"
        actions={
          <Button
            variant="secondary"
            size="sm"
            onClick={() => refetch()}
            loading={isLoading}
          >
            <RefreshCw size={12} /> Refresh
          </Button>
        }
      />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard
          label="Market Condition"
          value={
            <Badge className={regimeBadgeClass(condition ?? null)}>
              {regimeLabel(condition ?? null)}
            </Badge>
          }
        />
        <StatCard
          label="Total Market Cap"
          value={fmtCompact(snapshot?.totalMarketCap ?? 0)}
        />
        <StatCard
          label="BTC Dominance"
          value={`${(snapshot?.btcDominance ?? 0).toFixed(2)}%`}
        />
        <StatCard
          label="Assets Tracked"
          value={String(snapshot?.markets.length ?? 0)}
        />
      </div>

      <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
        <h3 className="text-sm font-semibold text-zinc-200 mb-3">Top Assets</h3>
        {isLoading ? (
          <LoadingSpinner />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-xs text-zinc-600 border-b border-zinc-800">
                  <th className="text-left py-2 pr-4">#</th>
                  <th className="text-left py-2 pr-4">Asset</th>
                  <th className="text-right py-2 pr-4">Price</th>
                  <th className="text-right py-2 pr-4">24h Change</th>
                  <th className="text-right py-2 pr-4">Volume 24h</th>
                  <th className="text-right py-2">Market Cap</th>
                </tr>
              </thead>
              <tbody>
                {(markets ?? snapshot?.markets ?? []).map((m, i) => (
                  <tr
                    key={m.symbol}
                    className="border-b border-zinc-800/40 hover:bg-zinc-800/20 transition-colors"
                  >
                    <td className="py-2.5 pr-4 text-zinc-600 text-xs">
                      {i + 1}
                    </td>
                    <td className="py-2.5 pr-4">
                      <span className="font-semibold text-zinc-100">
                        {m.symbol}
                      </span>
                    </td>
                    <td className="text-right py-2.5 pr-4 font-mono text-zinc-200">
                      {fmtUSD(m.price)}
                    </td>
                    <td
                      className={`text-right py-2.5 pr-4 font-medium ${pctColor(m.change24h)}`}
                    >
                      {fmtPct(m.change24h)}
                    </td>
                    <td className="text-right py-2.5 pr-4 text-zinc-400">
                      {fmtCompact(m.volume24h)}
                    </td>
                    <td className="text-right py-2.5 text-zinc-400">
                      {fmtCompact(m.marketCap)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

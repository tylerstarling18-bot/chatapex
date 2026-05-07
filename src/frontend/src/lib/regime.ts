import type { MarketCondition } from "../backend";

export function regimeLabel(c: MarketCondition | null | undefined): string {
  if (!c) return "—";
  const map: Record<string, string> = {
    StrongBullish: "Strong Bullish",
    Bullish: "Bullish",
    Neutral: "Neutral",
    Ranging: "Ranging",
    WeakBearish: "Weak Bearish",
    StrongBearish: "Strong Bearish",
    HighVolatility: "High Volatility",
    ManipulationRisk: "Manipulation Risk",
    LowLiquidityDanger: "Low Liquidity",
  };
  return map[c as string] ?? String(c);
}

export function regimeColor(c: MarketCondition | null | undefined): string {
  if (!c) return "text-zinc-400";
  const map: Record<string, string> = {
    StrongBullish: "text-emerald-400",
    Bullish: "text-green-400",
    Neutral: "text-zinc-300",
    Ranging: "text-blue-300",
    WeakBearish: "text-orange-400",
    StrongBearish: "text-red-400",
    HighVolatility: "text-yellow-400",
    ManipulationRisk: "text-pink-400",
    LowLiquidityDanger: "text-purple-400",
  };
  return map[c as string] ?? "text-zinc-400";
}

export function regimeBadgeClass(
  c: MarketCondition | null | undefined,
): string {
  if (!c) return "bg-zinc-800 text-zinc-400";
  const map: Record<string, string> = {
    StrongBullish: "bg-emerald-500/20 text-emerald-300",
    Bullish: "bg-green-500/20 text-green-300",
    Neutral: "bg-zinc-700 text-zinc-300",
    Ranging: "bg-blue-500/20 text-blue-300",
    WeakBearish: "bg-orange-500/20 text-orange-300",
    StrongBearish: "bg-red-500/20 text-red-300",
    HighVolatility: "bg-yellow-500/20 text-yellow-300",
    ManipulationRisk: "bg-pink-500/20 text-pink-300",
    LowLiquidityDanger: "bg-purple-500/20 text-purple-300",
  };
  return map[c as string] ?? "bg-zinc-800 text-zinc-400";
}

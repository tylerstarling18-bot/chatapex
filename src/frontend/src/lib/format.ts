export function fmtUSD(n: number, decimals = 2): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(n);
}

export function fmtPct(n: number, decimals = 2): string {
  const sign = n >= 0 ? "+" : "";
  return `${sign}${n.toFixed(decimals)}%`;
}

export function fmtNum(n: number, decimals = 4): string {
  return n.toLocaleString("en-US", {
    minimumFractionDigits: 0,
    maximumFractionDigits: decimals,
  });
}

export function fmtCompact(n: number): string {
  if (n >= 1e12) return `$${(n / 1e12).toFixed(2)}T`;
  if (n >= 1e9) return `$${(n / 1e9).toFixed(2)}B`;
  if (n >= 1e6) return `$${(n / 1e6).toFixed(2)}M`;
  if (n >= 1e3) return `$${(n / 1e3).toFixed(2)}K`;
  return `$${n.toFixed(2)}`;
}

export function fmtTime(ns: bigint | number): string {
  const ms = typeof ns === "bigint" ? Number(ns) / 1_000_000 : ns;
  return new Date(ms).toLocaleString();
}

export function fmtTimeSec(sec: bigint | number): string {
  const s = typeof sec === "bigint" ? Number(sec) : sec;
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  if (h > 0) return `${h}h ${m}m ${ss}s`;
  if (m > 0) return `${m}m ${ss}s`;
  return `${ss}s`;
}

export function fmtTimeNs(ns: bigint | number): string {
  const ms = typeof ns === "bigint" ? Number(ns) * 1000 : ns * 1000;
  return new Date(ms).toLocaleString();
}

export function pctColor(n: number): string {
  if (n > 0) return "text-emerald-400";
  if (n < 0) return "text-red-400";
  return "text-zinc-400";
}

export function pctBg(n: number): string {
  if (n > 0) return "bg-emerald-500/15 text-emerald-400";
  if (n < 0) return "bg-red-500/15 text-red-400";
  return "bg-zinc-500/15 text-zinc-400";
}

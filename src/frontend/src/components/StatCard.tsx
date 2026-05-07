import type { ReactNode } from "react";
import { cn } from "../lib/utils";

interface StatCardProps {
  label: string;
  value: ReactNode;
  sub?: ReactNode;
  className?: string;
  icon?: ReactNode;
}

export function StatCard({
  label,
  value,
  sub,
  className,
  icon,
}: StatCardProps) {
  return (
    <div
      className={cn(
        "rounded-xl border border-zinc-800 bg-zinc-900 p-4",
        className,
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <p className="text-xs font-medium text-zinc-500 uppercase tracking-wide">
          {label}
        </p>
        {icon && <span className="text-zinc-600">{icon}</span>}
      </div>
      <p className="mt-1 text-2xl font-semibold text-zinc-100">{value}</p>
      {sub && <p className="mt-0.5 text-xs text-zinc-500">{sub}</p>}
    </div>
  );
}

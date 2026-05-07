import { AlertTriangle, CheckCircle2, Info, XCircle } from "lucide-react";
import { cn } from "../lib/utils";

type StatusType = "ok" | "warning" | "error" | "info";

interface StatusBannerProps {
  type: StatusType;
  message: string;
  className?: string;
}

const icons = {
  ok: CheckCircle2,
  warning: AlertTriangle,
  error: XCircle,
  info: Info,
};

const styles: Record<StatusType, string> = {
  ok: "bg-emerald-500/10 border-emerald-500/30 text-emerald-300",
  warning: "bg-yellow-500/10 border-yellow-500/30 text-yellow-300",
  error: "bg-red-500/10 border-red-500/30 text-red-300",
  info: "bg-blue-500/10 border-blue-500/30 text-blue-300",
};

export function StatusBanner({ type, message, className }: StatusBannerProps) {
  const Icon = icons[type];
  return (
    <div
      className={cn(
        "flex items-center gap-2 rounded-lg border px-3 py-2 text-sm",
        styles[type],
        className,
      )}
    >
      <Icon className="w-4 h-4 shrink-0" />
      {message}
    </div>
  );
}

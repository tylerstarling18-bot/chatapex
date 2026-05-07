import {
  Activity,
  AlertTriangle,
  BarChart2,
  Bot,
  Brain,
  ChevronRight,
  Cpu,
  Layers,
  LineChart,
  RefreshCw,
  Shield,
  Zap,
} from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "../lib/utils";

export type Page =
  | "simulator"
  | "dashboard"
  | "market"
  | "trading"
  | "decisions"
  | "training"
  | "backtest"
  | "arena"
  | "risk"
  | "exchange";

const NAV_ITEMS: {
  id: Page;
  label: string;
  icon: ReactNode;
  highlight?: boolean;
}[] = [
  {
    id: "simulator",
    label: "Simulator",
    icon: <Cpu size={16} />,
    highlight: true,
  },
  { id: "dashboard", label: "Dashboard", icon: <Bot size={16} /> },
  { id: "market", label: "Market", icon: <BarChart2 size={16} /> },
  { id: "trading", label: "Trading", icon: <LineChart size={16} /> },
  { id: "decisions", label: "AI Decisions", icon: <Brain size={16} /> },
  { id: "training", label: "AI Training", icon: <Zap size={16} /> },
  { id: "backtest", label: "Backtest", icon: <RefreshCw size={16} /> },
  { id: "arena", label: "Arena", icon: <Layers size={16} /> },
  { id: "risk", label: "Risk", icon: <Shield size={16} /> },
  { id: "exchange", label: "Exchange", icon: <Activity size={16} /> },
];

interface SidebarProps {
  page: Page;
  onNavigate: (p: Page) => void;
  paused?: boolean;
}

export function Sidebar({ page, onNavigate, paused }: SidebarProps) {
  return (
    <aside className="flex flex-col w-56 bg-zinc-950 border-r border-zinc-800 min-h-screen">
      <div className="px-4 py-5 border-b border-zinc-800">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-lg bg-violet-600 flex items-center justify-center">
            <Bot size={14} className="text-white" />
          </div>
          <span className="text-sm font-bold text-zinc-100 tracking-wide">
            APEX AI
          </span>
        </div>
        <p className="text-xs text-zinc-600 mt-1">Paper Trading Engine</p>
      </div>

      {paused && (
        <div className="mx-3 mt-3 flex items-center gap-1.5 rounded-lg bg-yellow-500/10 border border-yellow-500/30 px-2 py-1.5 text-xs text-yellow-300">
          <AlertTriangle size={12} />
          Risk paused
        </div>
      )}

      <nav className="flex-1 px-2 py-3 space-y-0.5">
        {NAV_ITEMS.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => onNavigate(item.id)}
            data-ocid={`nav.${item.id}_link`}
            className={cn(
              "w-full flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm font-medium transition-colors text-left",
              page === item.id
                ? "bg-violet-600/20 text-violet-300"
                : item.highlight
                  ? "text-violet-400 hover:text-violet-300 hover:bg-violet-600/10"
                  : "text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800",
            )}
          >
            {item.icon}
            {item.label}
            {item.highlight && page !== item.id && (
              <span className="ml-auto px-1.5 py-0.5 rounded text-xs bg-violet-600/20 text-violet-400 font-medium">
                NEW
              </span>
            )}
            {page === item.id && <ChevronRight size={12} className="ml-auto" />}
          </button>
        ))}
      </nav>

      <div className="px-4 py-3 border-t border-zinc-800">
        <p className="text-xs text-zinc-600">v1.0 • Paper Mode</p>
      </div>
    </aside>
  );
}

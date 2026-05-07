import { useState } from "react";
import { type Page, Sidebar } from "./components/Sidebar";
import { TopBar } from "./components/TopBar";
import { useRiskStatus } from "./hooks/useRisk";
import { ArenaPage } from "./pages/ArenaPage";
import { BacktestPage } from "./pages/BacktestPage";
import { DashboardPage } from "./pages/DashboardPage";
import { DecisionsPage } from "./pages/DecisionsPage";
import { ExchangePage } from "./pages/ExchangePage";
import { MarketPage } from "./pages/MarketPage";
import { RiskPage } from "./pages/RiskPage";
import { TradingPage } from "./pages/TradingPage";
import { TrainingPage } from "./pages/TrainingPage";

function PageContent({ page }: { page: Page }) {
  switch (page) {
    case "dashboard":
      return <DashboardPage />;
    case "market":
      return <MarketPage />;
    case "trading":
      return <TradingPage />;
    case "decisions":
      return <DecisionsPage />;
    case "training":
      return <TrainingPage />;
    case "backtest":
      return <BacktestPage />;
    case "arena":
      return <ArenaPage />;
    case "risk":
      return <RiskPage />;
    case "exchange":
      return <ExchangePage />;
  }
}

export default function App() {
  const [page, setPage] = useState<Page>("dashboard");
  const { data: risk } = useRiskStatus();

  return (
    <div className="flex min-h-screen bg-zinc-950 text-zinc-100">
      <Sidebar page={page} onNavigate={setPage} paused={risk?.isPaused} />
      <div className="flex-1 flex flex-col min-h-screen overflow-hidden">
        <TopBar />
        <main className="flex-1 overflow-y-auto">
          <PageContent page={page} />
        </main>
      </div>
    </div>
  );
}

import List "mo:core/List";
import AccessControl "mo:caffeineai-authorization/access-control";
import MixinAuthorization "mo:caffeineai-authorization/MixinAuthorization";
import MarketTypes "types/market";
import TradingTypes "types/trading";
import RiskTypes "types/risk";
import BacktestTypes "types/backtest";
import TrainingTypes "types/training";
import MarketApi "mixins/market-api";
import AIEngineApi "mixins/ai-engine-api";
import TradingApi "mixins/trading-api";
import RiskApi "mixins/risk-api";
import BacktestApi "mixins/backtest-api";
import TrainingApi "mixins/training-api";

import ExchangeTypes "types/exchange";
import ExchangeApi "mixins/exchange-api";
import ArenaTypes "types/arena";
import ConfidenceTypes "types/confidence";
import ArenaApi "mixins/arena-api";
import BotTypes "types/bot";
import EquityTypes "types/equity";
import BotApi "mixins/bot-api";
import Map "mo:core/Map";
import Timer "mo:core/Timer";




actor {
  // --- Authorization ---
  let accessControlState = AccessControl.initState();
  include MixinAuthorization(accessControlState);

  // --- Exchange Connections State ---
  let exchangeConnections = List.empty<ExchangeTypes.ExchangeConnection>();
  include ExchangeApi(accessControlState, exchangeConnections);

  // --- Market Data State ---
  let marketSnapshots = List.empty<MarketTypes.MarketSnapshot>();
  include MarketApi(accessControlState, marketSnapshots);

  // --- AI Training State (declared early — consumed by AIEngineApi) ---
  let trainingState = {
    var value : TrainingTypes.AITrainingState = {
      totalSessions = 0;
      practiceTradesCount = 0;
      overallWinRate = 0.0;
      avgConfidenceScore = 0.0;
      strategyPerformances = [];
      lastTrainingUpdate = 0;
      confidenceCalibration = 1.0;
      learningProgress = 0.0;
      marketMemory = [];
      noTradeLog = [];
      correlationData = [];
      confidenceThreshold = 0.6;
      overtradingCount = 0;
      consecutiveLosses = 0;
    };
  };
  let noTradeDecisions = List.empty<ConfidenceTypes.NoTradeDecision>();
  let strategyPerformances = List.empty<TradingTypes.StrategyPerformance>();
  include TrainingApi(accessControlState, trainingState, strategyPerformances);

  // --- AI Engine State ---
  let decisionLogs = List.empty<TradingTypes.AIDecisionLog>();
  let latestCondition = { var value : ?MarketTypes.MarketCondition = null };
  let aiState = {
    var isRunning = false;
    var lastRunTime : Int = 0;
    var nextRunTime : Int = 0;
    var mode = "paper";
    var cycleCount : Nat = 0;
  };
  include AIEngineApi(accessControlState, decisionLogs, latestCondition, aiState, trainingState, noTradeDecisions);

  // --- Risk Management State ---
  let riskSettings = {
    var value : RiskTypes.RiskSettings = {
      maxDailyLossPercent = 5.0;
      maxPositionSizePercent = 2.0;
      maxConsecutiveLosses = 3;
      enablePaperTrading = true;
      conservativeMode = true;
      emergencyStopEnabled = true;
    };
  };
  let riskEvents = List.empty<RiskTypes.RiskEvent>();
  let riskState = {
    var isPaused = false;
    var dailyLoss = 0.0;
    var dailyLossPercent = 0.0;
    var consecutiveLosses : Nat = 0;
    var riskScore = 0.0;
  };
  include RiskApi(accessControlState, riskSettings, riskEvents, riskState);

  // --- Paper Trading State ---
  let trades = List.empty<TradingTypes.Trade>();
  let portfolio = {
    var value : TradingTypes.Portfolio = {
      totalValue = 10_000.0;
      cashBalance = 10_000.0;
      investedValue = 0.0;
      totalPnl = 0.0;
      totalPnlPercent = 0.0;
      dayPnl = 0.0;
      dayPnlPercent = 0.0;
      winRate = 0.0;
      totalTrades = 0;
      winningTrades = 0;
      positions = [];
    };
  };
  include TradingApi(accessControlState, trades, portfolio, marketSnapshots, riskSettings, riskState, decisionLogs, riskEvents);

  // --- Backtesting State ---
  let backtestSessions = List.empty<BacktestTypes.BacktestSession>();
  include BacktestApi(accessControlState, backtestSessions);

  // --- Arena State ---
  let arenaSessions = List.empty<ArenaTypes.ArenaSession>();
  include ArenaApi(accessControlState, arenaSessions);

  // --- Trade Snapshots ---
  let tradeSnapshots = List.empty<ConfidenceTypes.TradeSnapshot>();

  // Return a trade snapshot by trade ID
  public query func getTradeSnapshot(tradeId : Text) : async ?ConfidenceTypes.TradeSnapshot {
    tradeSnapshots.find(func(s : ConfidenceTypes.TradeSnapshot) : Bool {
      s.tradeId == tradeId
    });
  };

  // --- Bot Timer State ---
  let botTimerState = {
    var marketTimerId  : ?Timer.TimerId = null;
    var decisionTimerId : ?Timer.TimerId = null;
  };

  // --- Bot Lifecycle State ---
  let botConfig = {
    var value : BotTypes.BotConfig = {
      refreshIntervalSecs  = 60;
      decisionIntervalSecs = 60;
      tradingMode          = #Autonomous;
      volatilityPositionSizing = true;
      simulationFidelity = {
        slippagePct  = 0.0005;
        feeMakerPct  = 0.0002;
        feeTakerPct  = 0.001;
        spreadPct    = 0.001;
      };
      partialExitLevels = [(0.02, 0.25), (0.05, 0.25)];
      startingBalance   = 10_000.0;
    };
  };
  let botState = {
    var value : BotTypes.BotState = {
      status              = #Stopped;
      startedAt           = null;
      lastDecisionAt      = null;
      lastDataFetchAt     = null;
      uptimeSeconds       = 0;
      decisionCycleCount  = 0;
      tradesExecutedCount = 0;
      dataFeedHealthy     = false;
    };
  };

  // --- Equity + Confidence History ---
  let equityHistory  = List.empty<EquityTypes.EquitySnapshot>();
  let confidenceHist = List.empty<EquityTypes.ConfidencePoint>();

  // --- Simulation cost accumulators ---
  let simCosts = {
    var totalSlippage : Float = 0.0;
    var totalFees     : Float = 0.0;
    var totalSpread   : Float = 0.0;
    var tradeCount    : Nat   = 0;
  };

  // --- Daily realized PnL (reset on resetBot) ---
  let dailyRealizedPnL = { var value : Float = 0.0 };

  // --- Candle Store: symbol -> OHLCV candles fetched from CoinGecko ---
  let candleStore = Map.empty<Text, List.List<MarketTypes.Candle>>();

  include BotApi(
    accessControlState,
    botConfig, botState,
    botTimerState,
    trades, portfolio, marketSnapshots,
    decisionLogs, latestCondition, aiState,
    trainingState, noTradeDecisions,
    riskSettings, riskState, riskEvents,
    equityHistory, confidenceHist,
    simCosts, dailyRealizedPnL,
    candleStore,
  );
};

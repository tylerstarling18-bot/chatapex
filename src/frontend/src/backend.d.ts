import type { Principal } from "@icp-sdk/core/principal";
export interface Some<T> {
    __kind__: "Some";
    value: T;
}
export interface None {
    __kind__: "None";
}
export type Option<T> = Some<T> | None;
export interface TransformationOutput {
    status: bigint;
    body: Uint8Array;
    headers: Array<http_header>;
}
export interface StrategyPerformanceByRegime {
    lossCount: bigint;
    marketCondition: MarketCondition;
    totalPnl: number;
    winCount: bigint;
    avgHoldTimeSeconds: bigint;
    strategyMode: StrategyMode;
    avgPnl: number;
}
export interface RiskEvent {
    id: string;
    message: string;
    timestamp: bigint;
    severity: RiskSeverity;
    eventType: RiskEventType;
}
export interface ConfidenceFactors {
    regimeConfidence: number;
    total: number;
    trendAlignment: number;
    liquidity: number;
    momentum: number;
    marketStructure: number;
    historicalSetupPerformance: number;
    volatilityQuality: number;
}
export interface RiskStatus {
    dailyLoss: number;
    isPaused: boolean;
    consecutiveLosses: bigint;
    riskScore: number;
    dailyLossPercent: number;
}
export interface SimulationFidelity {
    slippagePct: number;
    feeTakerPct: number;
    feeMakerPct: number;
    spreadPct: number;
}
export interface MarketData {
    change24h: number;
    marketCap: number;
    lastUpdated: bigint;
    volume24h: number;
    price: number;
    symbol: string;
}
export interface CorrelationData {
    lastUpdated: bigint;
    btcCorrelation: number;
    symbol: string;
}
export interface RegimeBreakdown {
    regime: MarketCondition;
    returnPct: number;
    winRate: number;
}
export interface Candle {
    low: number;
    high: number;
    close: number;
    open: number;
    volume: number;
    timestamp: bigint;
}
export interface ArenaResult {
    tradeCount: bigint;
    agentId: string;
    avgHoldTime: bigint;
    sharpeRatio: number;
    performanceByRegime: Array<RegimeBreakdown>;
    finalBalance: number;
    winRate: number;
    totalReturnPct: number;
    maxDrawdownPct: number;
}
export interface BacktestSession {
    id: string;
    status: BacktestStatus;
    initialBalance: number;
    symbols: Array<string>;
    endDate: bigint;
    name: string;
    results?: BacktestResults;
    startDate: bigint;
}
export interface ActivityItem {
    action: string;
    asset: string;
    reasoning: string;
    timestamp: bigint;
    executed: boolean;
    confidence: number;
}
export interface TradeDecision {
    id: string;
    action: TradeAction;
    marketCondition: MarketCondition;
    targetPrice?: number;
    reasoning: string;
    riskReward: number;
    stopLoss: number;
    indicators: {
        atr: number;
        rsi: number;
        macdSignal: number;
        bollingerMid: number;
        trendStrength: number;
        macd: number;
        momentum: number;
        bollingerLower: number;
        ema20: number;
        ema50: number;
        bollingerUpper: number;
    };
    timestamp: bigint;
    entryPrice: number;
    confidence: number;
    strategyMode: StrategyMode;
    symbol: string;
}
export interface AITrainingState {
    confidenceThreshold: number;
    correlationData: Array<CorrelationData>;
    marketMemory: Array<StrategyPerformanceByRegime>;
    lastTrainingUpdate: bigint;
    avgConfidenceScore: number;
    consecutiveLosses: bigint;
    strategyPerformances: Array<{
        totalTrades: bigint;
        wins: bigint;
        lastUpdated: bigint;
        avgConfidence: number;
        losses: bigint;
        totalPnl: number;
        winRate: number;
        strategyMode: Variant_Defensive_Observation_TrendFollowing_Scalping_MeanReversion;
    }>;
    overallWinRate: number;
    learningProgress: number;
    confidenceCalibration: number;
    overtradingCount: bigint;
    practiceTradesCount: bigint;
    totalSessions: bigint;
    noTradeLog: Array<NoTradeDecision>;
}
export interface BotConfig {
    partialExitLevels: Array<PartialExitLevel>;
    decisionIntervalSecs: bigint;
    simulationFidelity: SimulationFidelity;
    refreshIntervalSecs: bigint;
    startingBalance: number;
    tradingMode: TradingMode;
    volatilityPositionSizing: boolean;
}
export type PartialExitLevel = [number, number];
export interface OrderRecord {
    qty: number;
    status: string;
    side: string;
    orderId: string;
    timestamp: bigint;
    price: number;
    symbol: string;
}
export interface AIDecisionLog {
    executionDetails?: {
        slippagePct: number;
        feePct: number;
        executionDelayMs: bigint;
        spreadPct: number;
    };
    indicatorValues: {
        atr: number;
        rsi: number;
        bollingerBandwidth: number;
        macd: number;
        ema20: number;
        ema50: number;
    };
    decision: TradeDecision;
    noTradeReason?: string;
    decisionCycleId: bigint;
    alternativesConsidered: Array<[string, number]>;
    skipReason?: string;
    executionStatus: Variant_Skipped_Failed_Executed_Pending;
    multiTimeframeSignals: Array<{
        rsi: number;
        macdSignal: Variant_Bearish_Cross_Bullish;
        trend: Variant_Bearish_Neutral_Bullish;
        timeframe: string;
        emaAlignment: boolean;
        strength: number;
    }>;
    marketSnapshot: {
        btcDominance: number;
        volume24h: number;
        volatilityPct: number;
        price: number;
    };
    executedTradeId?: string;
    confidenceFactors: {
        regimeConfidence: number;
        total: number;
        trendAlignment: number;
        liquidity: number;
        momentum: number;
        marketStructure: number;
        historicalSetupPerformance: number;
        volatilityQuality: number;
    };
}
export type TradeId = string;
export interface BacktestResults {
    totalTrades: bigint;
    trades: Array<{
        id: string;
        pnl?: number;
        status: Variant_Open_Closed_TakeProfitHit_StopLossHit_Cancelled;
        action: Variant_Buy_Hold_Sell_Skip;
        closeTime: bigint;
        pnlPercent?: number;
        decisionId: string;
        takeProfit?: number;
        stopLoss: number;
        quantity: number;
        entryPrice: number;
        exitPrice?: number;
        openTime: bigint;
        symbol: string;
    }>;
    sharpeRatio?: number;
    finalBalance: number;
    equityCurve: Array<EquityPoint>;
    totalReturn: number;
    winRate: number;
    maxDrawdown: number;
    totalPnlPercent: number;
}
export interface Trade {
    id: string;
    pnl?: number;
    status: TradeStatus;
    action: TradeAction;
    closeTime: bigint;
    pnlPercent?: number;
    decisionId: string;
    takeProfit?: number;
    stopLoss: number;
    quantity: number;
    entryPrice: number;
    exitPrice?: number;
    openTime: bigint;
    symbol: string;
}
export interface RiskSettings {
    conservativeMode: boolean;
    maxConsecutiveLosses: bigint;
    enablePaperTrading: boolean;
    emergencyStopEnabled: boolean;
    maxDailyLossPercent: number;
    maxPositionSizePercent: number;
}
export interface http_header {
    value: string;
    name: string;
}
export interface http_request_result {
    status: bigint;
    body: Uint8Array;
    headers: Array<http_header>;
}
export interface TechnicalIndicators {
    atr: number;
    rsi: number;
    macdSignal: number;
    bollingerMid: number;
    trendStrength: number;
    macd: number;
    momentum: number;
    bollingerLower: number;
    ema20: number;
    ema50: number;
    bollingerUpper: number;
}
export interface EquitySnapshot {
    dailyPnLPct: number;
    totalPnLPct: number;
    realizedPnLToday: number;
    cash: number;
    positionValue: number;
    timestamp: bigint;
    unrealizedPnL: number;
    equity: number;
}
export interface Position {
    currentPrice: number;
    averageEntryPrice: number;
    takeProfit?: number;
    stopLoss: number;
    unrealizedPnlPercent: number;
    quantity: number;
    unrealizedPnl: number;
    openTime: bigint;
    symbol: string;
}
export interface BotState {
    status: BotStatus;
    startedAt?: bigint;
    dataFeedHealthy: boolean;
    uptimeSeconds: bigint;
    tradesExecutedCount: bigint;
    lastDecisionAt?: bigint;
    decisionCycleCount: bigint;
    lastDataFetchAt?: bigint;
}
export type Timestamp = bigint;
export interface ArenaSession {
    completedAt: bigint;
    endDate: string;
    results: Array<ArenaResult>;
    initialCapital: number;
    sessionId: string;
    symbol: string;
    startDate: string;
}
export interface EquityPoint {
    value: number;
    timestamp: bigint;
}
export interface DecisionCycleStats {
    cyclesPerHour: number;
    totalCycles: bigint;
    avgConfidence: number;
    noTradeRate: number;
    tradesThisSession: bigint;
    winRate: number;
}
export interface DataFeedStatus {
    healthy: boolean;
    staleSince?: bigint;
    lastFetchAt?: bigint;
    assetCount: bigint;
}
export interface TransformationInput {
    context: Uint8Array;
    response: http_request_result;
}
export interface Portfolio {
    totalTrades: bigint;
    dayPnl: number;
    dayPnlPercent: number;
    totalValue: number;
    totalPnl: number;
    cashBalance: number;
    winningTrades: bigint;
    positions: Array<Position>;
    winRate: number;
    totalPnlPercent: number;
    investedValue: number;
}
export interface ExchangeStatus {
    exchangeId: string;
    connected: boolean;
    phase: bigint;
    lastTestTimestamp: bigint;
}
export interface ConfidencePoint {
    regime: string;
    action: string;
    asset: string;
    timestamp: bigint;
    confidence: number;
}
export type Symbol = string;
export interface StrategyPerformance {
    totalTrades: bigint;
    wins: bigint;
    lastUpdated: bigint;
    avgConfidence: number;
    losses: bigint;
    totalPnl: number;
    winRate: number;
    strategyMode: StrategyMode;
}
export interface AssetBalance {
    asset: string;
    free: number;
    locked: number;
}
export interface NoTradeDecision {
    marketRegime: MarketCondition;
    confidenceAtTime: number;
    thresholdAtTime: number;
    timestamp: Timestamp;
    symbol: Symbol;
    reason: NoTradeReason;
}
export interface TradeSnapshot {
    netImpactPct: number;
    marketRegimeAtEntry: MarketCondition;
    simulatedSpread: number;
    simulatedLatencyMs: bigint;
    tags: Array<TradeTag>;
    aiReasoningText: string;
    tradeId: TradeId;
    indicatorsAtEntry: TechnicalIndicators;
    simulatedFees: number;
    simulatedSlippage: number;
    volatilityRatio: number;
    confidenceFactors: ConfidenceFactors;
}
export interface MarketSnapshot {
    btcDominance: number;
    totalMarketCap: number;
    markets: Array<MarketData>;
    timestamp: bigint;
    fearGreedIndex?: number;
}
export interface SimulationStats {
    avgSlippagePct: number;
    avgFeePct: number;
    totalSlippageCost: number;
    totalSpreadCost: number;
    totalFeeCost: number;
}
export enum BacktestStatus {
    Failed = "Failed",
    Running = "Running",
    Completed = "Completed"
}
export enum BotStatus {
    Stopped = "Stopped",
    Paused = "Paused",
    EmergencyStopped = "EmergencyStopped",
    Running = "Running"
}
export enum MarketCondition {
    StrongBearish = "StrongBearish",
    LowLiquidityDanger = "LowLiquidityDanger",
    HighVolatility = "HighVolatility",
    ManipulationRisk = "ManipulationRisk",
    Ranging = "Ranging",
    Neutral = "Neutral",
    WeakBearish = "WeakBearish",
    StrongBullish = "StrongBullish",
    Bullish = "Bullish"
}
export enum NoTradeReason {
    OvertradingFlag = "OvertradingFlag",
    ExistingPosition = "ExistingPosition",
    DrawdownProtection = "DrawdownProtection",
    VolatilityTooHigh = "VolatilityTooHigh",
    RegimeMismatch = "RegimeMismatch",
    CorrelationLimit = "CorrelationLimit",
    LiquidityTooLow = "LiquidityTooLow",
    LowConfidence = "LowConfidence"
}
export enum RiskEventType {
    EmergencyStop = "EmergencyStop",
    VolatilityPause = "VolatilityPause",
    DailyLossLimitHit = "DailyLossLimitHit",
    ManualPause = "ManualPause",
    ConsecutiveLossesAutopaused = "ConsecutiveLossesAutopaused",
    ResumeTrade = "ResumeTrade"
}
export enum RiskSeverity {
    Info = "Info",
    Critical = "Critical",
    Warning = "Warning"
}
export enum TradeTag {
    GoodScaling = "GoodScaling",
    GoodDiscipline = "GoodDiscipline",
    TextbookWin = "TextbookWin",
    OvertradeLoss = "OvertradeLoss",
    RegimeMismatch = "RegimeMismatch",
    PrematureExit = "PrematureExit",
    TightStop = "TightStop"
}
export enum TradingMode {
    Autonomous = "Autonomous",
    SignalOnly = "SignalOnly",
    Manual = "Manual"
}
export enum UserRole {
    admin = "admin",
    user = "user",
    guest = "guest"
}
export enum Variant_Bearish_Cross_Bullish {
    Bearish = "Bearish",
    Cross = "Cross",
    Bullish = "Bullish"
}
export enum Variant_Bearish_Neutral_Bullish {
    Bearish = "Bearish",
    Neutral = "Neutral",
    Bullish = "Bullish"
}
export enum Variant_Buy_Hold_Sell_Skip {
    Buy = "Buy",
    Hold = "Hold",
    Sell = "Sell",
    Skip = "Skip"
}
export enum Variant_Defensive_Observation_TrendFollowing_Scalping_MeanReversion {
    Defensive = "Defensive",
    Observation = "Observation",
    TrendFollowing = "TrendFollowing",
    Scalping = "Scalping",
    MeanReversion = "MeanReversion"
}
export enum Variant_Open_Closed_TakeProfitHit_StopLossHit_Cancelled {
    Open = "Open",
    Closed = "Closed",
    TakeProfitHit = "TakeProfitHit",
    StopLossHit = "StopLossHit",
    Cancelled = "Cancelled"
}
export enum Variant_Skipped_Failed_Executed_Pending {
    Skipped = "Skipped",
    Failed = "Failed",
    Executed = "Executed",
    Pending = "Pending"
}
export interface backendInterface {
    applyTradeToTraining(trade: Trade, decision: TradeDecision): Promise<void>;
    assignCallerUserRole(user: Principal, role: UserRole): Promise<void>;
    backtestTransform(input: TransformationInput): Promise<TransformationOutput>;
    botTransform(input: TransformationInput): Promise<TransformationOutput>;
    closePosition(symbol: string): Promise<{
        __kind__: "ok";
        ok: Trade;
    } | {
        __kind__: "err";
        err: string;
    }>;
    emergencyStopBot(): Promise<BotState>;
    executeManualTrade(symbol: string, action: string, quantity: number): Promise<{
        __kind__: "ok";
        ok: Trade;
    } | {
        __kind__: "err";
        err: string;
    }>;
    executePendingDecisions(): Promise<Array<Trade>>;
    fetchAndStoreHistoricalCandles(symbol: string, days: bigint): Promise<{
        __kind__: "ok";
        ok: bigint;
    } | {
        __kind__: "err";
        err: string;
    }>;
    fetchMarketData(): Promise<Array<MarketData>>;
    getAIStatus(): Promise<{
        mode: string;
        lastRunTime: bigint;
        nextRunTime: bigint;
        isRunning: boolean;
        cycleCount: bigint;
    }>;
    getAITrainingState(): Promise<AITrainingState>;
    getAllConfidenceTimeline(limit: bigint): Promise<Array<ConfidencePoint>>;
    getArenaResults(sessionId: string): Promise<ArenaSession | null>;
    getArenaSessions(): Promise<Array<ArenaSession>>;
    getBacktestSession(id: string): Promise<BacktestSession | null>;
    getBotConfig(): Promise<BotConfig>;
    getBotState(): Promise<BotState>;
    getCallerUserRole(): Promise<UserRole>;
    getConfidenceTimeline(asset: string, limit: bigint): Promise<Array<ConfidencePoint>>;
    getCurrentEquity(): Promise<EquitySnapshot | null>;
    getCurrentMarketCondition(): Promise<MarketCondition | null>;
    getDataFeedStatus(): Promise<DataFeedStatus>;
    getDecisionCycleStats(): Promise<DecisionCycleStats>;
    getDecisionsByAsset(asset: string, limit: bigint): Promise<Array<AIDecisionLog>>;
    getEquityHistory(limit: bigint): Promise<Array<EquitySnapshot>>;
    getExchangeBalances(exchangeId: string): Promise<Array<AssetBalance>>;
    getExchangeConnections(): Promise<Array<ExchangeStatus>>;
    getExchangeOrderHistory(exchangeId: string): Promise<Array<OrderRecord>>;
    getHistoricalCandles(symbol: string, days: bigint): Promise<Array<Candle>>;
    getLatestDecisions(limit: bigint): Promise<Array<AIDecisionLog>>;
    getLatestSnapshot(): Promise<MarketSnapshot | null>;
    getLiveActivityFeed(limit: bigint): Promise<Array<ActivityItem>>;
    getMarketCandles(symbol: string): Promise<Array<Candle>>;
    getMarketMemory(): Promise<Array<StrategyPerformanceByRegime>>;
    getNoTradeLog(): Promise<Array<NoTradeDecision>>;
    getOpenPositions(): Promise<Array<Position>>;
    getPortfolio(): Promise<Portfolio>;
    getRecentDecisions(limit: bigint): Promise<Array<AIDecisionLog>>;
    getRiskEvents(limit: bigint): Promise<Array<RiskEvent>>;
    getRiskSettings(): Promise<RiskSettings>;
    getRiskStatus(): Promise<RiskStatus>;
    getSimulationStats(): Promise<SimulationStats>;
    getStrategyPerformances(): Promise<Array<StrategyPerformance>>;
    getTopSetups(): Promise<Array<StrategyPerformanceByRegime>>;
    getTradeHistory(limit: bigint): Promise<Array<Trade>>;
    getTradeSnapshot(tradeId: string): Promise<TradeSnapshot | null>;
    isCallerAdmin(): Promise<boolean>;
    listBacktestSessions(): Promise<Array<BacktestSession>>;
    pauseBot(): Promise<BotState>;
    refreshGlobalData(): Promise<[number, number]>;
    removeExchangeConnection(exchangeId: string): Promise<boolean>;
    resetBot(): Promise<BotState>;
    resetTrainingData(): Promise<boolean>;
    resumeBot(): Promise<BotState>;
    resumeTrading(): Promise<boolean>;
    runAIAnalysis(): Promise<Array<AIDecisionLog>>;
    runDecisionCycle(): Promise<{
        __kind__: "ok";
        ok: {
            skipped: bigint;
            reasoning: string;
            decisionsGenerated: bigint;
            positionsUpdated: bigint;
            tradesExecuted: bigint;
        };
    } | {
        __kind__: "err";
        err: string;
    }>;
    runMarketCycle(): Promise<{
        __kind__: "ok";
        ok: string;
    } | {
        __kind__: "err";
        err: string;
    }>;
    saveExchangeConnection(exchangeId: string, apiKey: string, apiSecret: string): Promise<boolean>;
    setAIMode(mode: string): Promise<boolean>;
    startArena(symbol: string, startDate: string, endDate: string): Promise<string>;
    startBacktest(name: string, symbols: Array<string>, startDate: bigint, endDate: bigint, initialBalance: number): Promise<BacktestSession>;
    startBot(): Promise<{
        __kind__: "ok";
        ok: BotState;
    } | {
        __kind__: "err";
        err: string;
    }>;
    testExchangeConnection(exchangeId: string): Promise<boolean>;
    transform(input: TransformationInput): Promise<TransformationOutput>;
    triggerEmergencyStop(): Promise<boolean>;
    updateBotConfig(cfg: BotConfig): Promise<{
        __kind__: "ok";
        ok: BotConfig;
    } | {
        __kind__: "err";
        err: string;
    }>;
    updateRiskSettings(settings: RiskSettings): Promise<boolean>;
}

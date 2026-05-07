import { useQuery } from "@tanstack/react-query";
import { useClient } from "../lib/backend-client";

export function useRecentDecisions(limit = 30) {
  const client = useClient();
  return useQuery({
    queryKey: ["decisions", limit],
    queryFn: () => client.getRecentDecisions(BigInt(limit)),
    refetchInterval: 10000,
  });
}

export function useLatestDecisions(limit = 30) {
  const client = useClient();
  return useQuery({
    queryKey: ["latestDecisions", limit],
    queryFn: () => client.getLatestDecisions(BigInt(limit)),
    refetchInterval: 10000,
  });
}

export function useLiveActivityFeed(limit = 20) {
  const client = useClient();
  return useQuery({
    queryKey: ["activity", limit],
    queryFn: () => client.getLiveActivityFeed(BigInt(limit)),
    refetchInterval: 5000,
  });
}

export function useAIStatus() {
  const client = useClient();
  return useQuery({
    queryKey: ["aiStatus"],
    queryFn: () => client.getAIStatus(),
    refetchInterval: 10000,
  });
}

export function useAITrainingState() {
  const client = useClient();
  return useQuery({
    queryKey: ["trainingState"],
    queryFn: () => client.getAITrainingState(),
    refetchInterval: 30000,
  });
}

export function useStrategyPerformances() {
  const client = useClient();
  return useQuery({
    queryKey: ["stratPerf"],
    queryFn: () => client.getStrategyPerformances(),
    refetchInterval: 30000,
  });
}

export function useMarketMemory() {
  const client = useClient();
  return useQuery({
    queryKey: ["marketMemory"],
    queryFn: () => client.getMarketMemory(),
    refetchInterval: 30000,
  });
}

export function useNoTradeLog() {
  const client = useClient();
  return useQuery({
    queryKey: ["noTradeLog"],
    queryFn: () => client.getNoTradeLog(),
    refetchInterval: 30000,
  });
}

export function useConfidenceTimeline(asset: string, limit = 50) {
  const client = useClient();
  return useQuery({
    queryKey: ["confTimeline", asset, limit],
    queryFn: () => client.getConfidenceTimeline(asset, BigInt(limit)),
    refetchInterval: 15000,
  });
}

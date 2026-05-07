import { useQuery } from "@tanstack/react-query";
import { useClient } from "../lib/backend-client";

export function useLatestSnapshot() {
  const client = useClient();
  return useQuery({
    queryKey: ["snapshot"],
    queryFn: () => client.getLatestSnapshot(),
    refetchInterval: 30000,
  });
}

export function useCurrentMarketCondition() {
  const client = useClient();
  return useQuery({
    queryKey: ["marketCondition"],
    queryFn: () => client.getCurrentMarketCondition(),
    refetchInterval: 15000,
  });
}

export function useFetchMarketData() {
  const client = useClient();
  return useQuery({
    queryKey: ["marketData"],
    queryFn: () => client.fetchMarketData(),
    refetchInterval: 60000,
  });
}

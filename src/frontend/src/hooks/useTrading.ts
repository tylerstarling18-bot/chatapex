import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useClient } from "../lib/backend-client";

export function usePortfolio() {
  const client = useClient();
  return useQuery({
    queryKey: ["portfolio"],
    queryFn: () => client.getPortfolio(),
    refetchInterval: 10000,
  });
}

export function useOpenPositions() {
  const client = useClient();
  return useQuery({
    queryKey: ["positions"],
    queryFn: () => client.getOpenPositions(),
    refetchInterval: 10000,
  });
}

export function useTradeHistory(limit = 50) {
  const client = useClient();
  return useQuery({
    queryKey: ["trades", limit],
    queryFn: () => client.getTradeHistory(BigInt(limit)),
    refetchInterval: 15000,
  });
}

export function useClosePosition() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (symbol: string) => client.closePosition(symbol),
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["portfolio"] });
      qc.invalidateQueries({ queryKey: ["positions"] });
      qc.invalidateQueries({ queryKey: ["trades"] });
    },
  });
}

export function useExecuteManualTrade() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      symbol,
      action,
      quantity,
    }: { symbol: string; action: string; quantity: number }) =>
      client.executeManualTrade(symbol, action, quantity),
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["portfolio"] });
      qc.invalidateQueries({ queryKey: ["positions"] });
      qc.invalidateQueries({ queryKey: ["trades"] });
    },
  });
}

export function useEquityHistory(limit = 100) {
  const client = useClient();
  return useQuery({
    queryKey: ["equity", limit],
    queryFn: () => client.getEquityHistory(BigInt(limit)),
    refetchInterval: 15000,
  });
}

export function useCurrentEquity() {
  const client = useClient();
  return useQuery({
    queryKey: ["currentEquity"],
    queryFn: () => client.getCurrentEquity(),
    refetchInterval: 10000,
  });
}

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useClient } from "../lib/backend-client";

export function useExchangeConnections() {
  const client = useClient();
  return useQuery({
    queryKey: ["exchangeConnections"],
    queryFn: () => client.getExchangeConnections(),
    refetchInterval: 30000,
  });
}

export function useSaveExchange() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      exchangeId,
      apiKey,
      apiSecret,
    }: {
      exchangeId: string;
      apiKey: string;
      apiSecret: string;
    }) => client.saveExchangeConnection(exchangeId, apiKey, apiSecret),
    onSettled: () =>
      qc.invalidateQueries({ queryKey: ["exchangeConnections"] }),
  });
}

export function useRemoveExchange() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (exchangeId: string) =>
      client.removeExchangeConnection(exchangeId),
    onSettled: () =>
      qc.invalidateQueries({ queryKey: ["exchangeConnections"] }),
  });
}

export function useTestExchange() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (exchangeId: string) =>
      client.testExchangeConnection(exchangeId),
    onSettled: () =>
      qc.invalidateQueries({ queryKey: ["exchangeConnections"] }),
  });
}

export function useExchangeBalances(exchangeId: string | null) {
  const client = useClient();
  return useQuery({
    queryKey: ["exchangeBalances", exchangeId],
    queryFn: () => client.getExchangeBalances(exchangeId!),
    enabled: !!exchangeId,
  });
}

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useClient } from "../lib/backend-client";

export function useBacktestSessions() {
  const client = useClient();
  return useQuery({
    queryKey: ["backtestSessions"],
    queryFn: () => client.listBacktestSessions(),
  });
}

export function useStartBacktest() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      name,
      symbols,
      startDate,
      endDate,
      initialBalance,
    }: {
      name: string;
      symbols: string[];
      startDate: bigint;
      endDate: bigint;
      initialBalance: number;
    }) =>
      client.startBacktest(name, symbols, startDate, endDate, initialBalance),
    onSettled: () => qc.invalidateQueries({ queryKey: ["backtestSessions"] }),
  });
}

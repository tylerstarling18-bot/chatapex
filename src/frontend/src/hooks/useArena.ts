import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useClient } from "../lib/backend-client";

export function useArenaSessions() {
  const client = useClient();
  return useQuery({
    queryKey: ["arenaSessions"],
    queryFn: () => client.getArenaSessions(),
    refetchInterval: 30000,
  });
}

export function useStartArena() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      symbol,
      startDate,
      endDate,
    }: { symbol: string; startDate: string; endDate: string }) =>
      client.startArena(symbol, startDate, endDate),
    onSettled: () => qc.invalidateQueries({ queryKey: ["arenaSessions"] }),
  });
}

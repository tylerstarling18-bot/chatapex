import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useClient } from "../lib/backend-client";

export function useBotState() {
  const client = useClient();
  return useQuery({
    queryKey: ["botState"],
    queryFn: () => client.getBotState(),
    refetchInterval: 5000,
  });
}

export function useBotConfig() {
  const client = useClient();
  return useQuery({
    queryKey: ["botConfig"],
    queryFn: () => client.getBotConfig(),
  });
}

export function useStartBot() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => client.startBot(),
    onSettled: () => qc.invalidateQueries({ queryKey: ["botState"] }),
  });
}

export function usePauseBot() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => client.pauseBot(),
    onSettled: () => qc.invalidateQueries({ queryKey: ["botState"] }),
  });
}

export function useResumeBot() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => client.resumeBot(),
    onSettled: () => qc.invalidateQueries({ queryKey: ["botState"] }),
  });
}

export function useEmergencyStop() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => client.emergencyStopBot(),
    onSettled: () => qc.invalidateQueries({ queryKey: ["botState"] }),
  });
}

export function useResetBot() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => client.resetBot(),
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["botState"] });
      qc.invalidateQueries({ queryKey: ["portfolio"] });
      qc.invalidateQueries({ queryKey: ["trades"] });
      qc.invalidateQueries({ queryKey: ["decisions"] });
      qc.invalidateQueries({ queryKey: ["equity"] });
    },
  });
}

export function useRunMarketCycle() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => client.runMarketCycle(),
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["snapshot"] });
      qc.invalidateQueries({ queryKey: ["botState"] });
    },
  });
}

export function useRunDecisionCycle() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => client.runDecisionCycle(),
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["decisions"] });
      qc.invalidateQueries({ queryKey: ["portfolio"] });
      qc.invalidateQueries({ queryKey: ["botState"] });
      qc.invalidateQueries({ queryKey: ["equity"] });
      qc.invalidateQueries({ queryKey: ["activity"] });
    },
  });
}

export function useDataFeedStatus() {
  const client = useClient();
  return useQuery({
    queryKey: ["dataFeed"],
    queryFn: () => client.getDataFeedStatus(),
    refetchInterval: 10000,
  });
}

export function useDecisionCycleStats() {
  const client = useClient();
  return useQuery({
    queryKey: ["cycleStats"],
    queryFn: () => client.getDecisionCycleStats(),
    refetchInterval: 10000,
  });
}

export function useSimulationStats() {
  const client = useClient();
  return useQuery({
    queryKey: ["simStats"],
    queryFn: () => client.getSimulationStats(),
    refetchInterval: 30000,
  });
}

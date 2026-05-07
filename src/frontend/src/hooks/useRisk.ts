import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { RiskSettings } from "../backend";
import { useClient } from "../lib/backend-client";

export function useRiskStatus() {
  const client = useClient();
  return useQuery({
    queryKey: ["riskStatus"],
    queryFn: () => client.getRiskStatus(),
    refetchInterval: 5000,
  });
}

export function useRiskSettings() {
  const client = useClient();
  return useQuery({
    queryKey: ["riskSettings"],
    queryFn: () => client.getRiskSettings(),
  });
}

export function useRiskEvents(limit = 20) {
  const client = useClient();
  return useQuery({
    queryKey: ["riskEvents", limit],
    queryFn: () => client.getRiskEvents(BigInt(limit)),
    refetchInterval: 10000,
  });
}

export function useUpdateRiskSettings() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (settings: RiskSettings) => client.updateRiskSettings(settings),
    onSettled: () => qc.invalidateQueries({ queryKey: ["riskSettings"] }),
  });
}

export function useTriggerEmergencyStop() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => client.triggerEmergencyStop(),
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["riskStatus"] });
      qc.invalidateQueries({ queryKey: ["riskSettings"] });
      qc.invalidateQueries({ queryKey: ["riskEvents"] });
    },
  });
}

export function useResumeTrading() {
  const client = useClient();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => client.resumeTrading(),
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["riskStatus"] });
      qc.invalidateQueries({ queryKey: ["riskEvents"] });
    },
  });
}

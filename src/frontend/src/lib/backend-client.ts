import { useActor } from "@caffeineai/core-infrastructure";
import { createActor } from "../backend";
import type { Backend } from "../backend";

export function useClient(): Backend {
  const { actor } = useActor(createActor);
  return actor as unknown as Backend;
}

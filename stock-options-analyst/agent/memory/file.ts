import { fileMemory } from "eve/memory/file";
import { defineMemory } from "eve/memory";
import { byPrincipal } from "eve/memory/scope";

export default defineMemory({
  description:
    "Remember durable investor preferences: capital currency, risk tolerance, sector limits, brokers, and recurring constraints. Do not store secrets or full trade tickets here — use record_recommendation for journaled setups.",
  provider: fileMemory(),
  scope: byPrincipal,
});

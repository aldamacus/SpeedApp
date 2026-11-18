import { defineTool } from "eve/tools";
import { z } from "zod";
import { maxLossBudget, tradingConfig } from "../lib/config";

export default defineTool({
  description:
    "Read the current trading configuration: capital, risk limits, horizons, and preferred strategies.",
  inputSchema: z.object({}),
  async execute() {
    const config = tradingConfig.get();
    return {
      config,
      maxLossBudget: maxLossBudget(config),
    };
  },
});

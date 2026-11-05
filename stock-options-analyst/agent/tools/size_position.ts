import { defineTool } from "eve/tools";
import { z } from "zod";
import { tradingConfig } from "../lib/config";
import { sizePosition } from "../lib/scoring";

export default defineTool({
  description:
    "Calculate max contracts allowed from trading capital, per-trade risk %, and the strategy's maximum loss per contract. Always size from maximum loss, not expected loss.",
  inputSchema: z.object({
    maxLossPerContract: z
      .number()
      .positive()
      .describe("Maximum loss in currency units for one options contract/package"),
    contractsRequested: z.number().int().positive().optional(),
    tradingCapitalOverride: z.number().positive().optional(),
    maxRiskPerTradePctOverride: z.number().min(0.1).max(5).optional(),
  }),
  async execute(input) {
    const config = tradingConfig.get();
    const result = sizePosition({
      tradingCapital: input.tradingCapitalOverride ?? config.tradingCapital,
      maxRiskPerTradePct:
        input.maxRiskPerTradePctOverride ?? config.maxRiskPerTradePct,
      maxLossPerContract: input.maxLossPerContract,
      contractsRequested: input.contractsRequested,
    });

    return {
      currency: config.currency,
      ...result,
    };
  },
});

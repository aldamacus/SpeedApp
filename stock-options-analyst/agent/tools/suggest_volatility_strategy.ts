import { defineTool } from "eve/tools";
import { z } from "zod";
import { suggestStrategyFramework } from "../lib/scoring";

export default defineTool({
  description:
    "Map directional outlook + IV regime to a preferred options approach (starting framework only). Separates investment thesis quality from options pricing attractiveness.",
  inputSchema: z.object({
    direction: z.enum(["bullish", "bearish", "neutral"]),
    ivEnvironment: z.enum(["low", "high"]),
    investmentHorizon: z
      .string()
      .optional()
      .describe("e.g. 3-year fundamental outlook"),
    optionsHorizon: z
      .string()
      .optional()
      .describe("e.g. 45-90 DTE trade window"),
  }),
  async execute(input) {
    const framework = suggestStrategyFramework({
      direction: input.direction,
      ivEnvironment: input.ivEnvironment,
    });

    return {
      ...framework,
      investmentHorizon: input.investmentHorizon ?? null,
      optionsHorizon: input.optionsHorizon ?? null,
      separationRule:
        "A strong multi-year company outlook does not justify buying expensive near-term options. Keep investment watchlist and options trading watchlist separate.",
    };
  },
});

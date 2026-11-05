import { defineTool } from "eve/tools";
import { z } from "zod";
import {
  DEFAULT_TRADING_CONFIG,
  maxLossBudget,
  tradingConfig,
  type TradingConfig,
} from "../lib/config";

export default defineTool({
  description:
    "Update trading capital, risk tolerance, currency, or risk limits for this session. Omit fields you do not want to change.",
  inputSchema: z.object({
    tradingCapital: z.number().positive().optional(),
    currency: z.enum(["EUR", "USD"]).optional(),
    riskTolerance: z
      .enum(["conservative", "moderate", "aggressive"])
      .optional(),
    maxRiskPerTradePct: z.number().min(0.1).max(5).optional(),
    maxCorrelatedRiskPct: z.number().min(0.5).max(20).optional(),
    topOpportunities: z.number().int().min(1).max(10).optional(),
    resetToDefaults: z.boolean().optional(),
  }),
  async execute(input) {
    if (input.resetToDefaults) {
      tradingConfig.update(() => ({ ...DEFAULT_TRADING_CONFIG }));
    } else {
      tradingConfig.update((current) => {
        const next: TradingConfig = { ...current };
        if (input.tradingCapital !== undefined) {
          next.tradingCapital = input.tradingCapital;
        }
        if (input.currency !== undefined) next.currency = input.currency;
        if (input.riskTolerance !== undefined) {
          next.riskTolerance = input.riskTolerance;
          if (input.maxRiskPerTradePct === undefined) {
            next.maxRiskPerTradePct =
              input.riskTolerance === "conservative"
                ? 1
                : input.riskTolerance === "aggressive"
                  ? 2
                  : 1.5;
          }
        }
        if (input.maxRiskPerTradePct !== undefined) {
          next.maxRiskPerTradePct = input.maxRiskPerTradePct;
        }
        if (input.maxCorrelatedRiskPct !== undefined) {
          next.maxCorrelatedRiskPct = input.maxCorrelatedRiskPct;
        }
        if (input.topOpportunities !== undefined) {
          next.topOpportunities = input.topOpportunities;
        }
        return next;
      });
    }

    const config = tradingConfig.get();
    return {
      config,
      maxLossBudget: maxLossBudget(config),
    };
  },
});

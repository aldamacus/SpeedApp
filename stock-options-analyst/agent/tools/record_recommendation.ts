import { defineTool } from "eve/tools";
import { z } from "zod";
import { recordRecommendation } from "../lib/journal";

export default defineTool({
  description:
    "Persist a recommended trade or watchlist entry to the trade journal. Never rewrite historical recommendations; record new entries only.",
  inputSchema: z.object({
    ticker: z.string().min(1).max(12),
    direction: z.enum(["bullish", "bearish", "neutral"]),
    strategy: z.string().min(1),
    thesis: z.string().min(10),
    stockPriceAtRecommendation: z.number().positive().optional(),
    expiration: z.string().optional(),
    strikes: z.string().optional(),
    entryPremium: z.number().optional(),
    maxRisk: z.number().optional(),
    targetPrice: z.number().optional(),
    exitConditions: z.string().optional(),
    score: z.number().min(0).max(100).optional(),
    classification: z
      .enum([
        "STRONG_BUY_SETUP",
        "BUY_SETUP",
        "WATCHLIST",
        "WAIT_FOR_BETTER_ENTRY",
        "AVOID",
        "NO_TRADE",
      ])
      .optional(),
    status: z.enum(["open", "watchlist"]).optional(),
  }),
  async execute(input) {
    return recordRecommendation({
      ...input,
      ticker: input.ticker.toUpperCase(),
    });
  },
});

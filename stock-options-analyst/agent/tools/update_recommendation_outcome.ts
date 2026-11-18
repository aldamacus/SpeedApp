import { defineTool } from "eve/tools";
import { z } from "zod";
import { updateRecommendationOutcome } from "../lib/journal";

export default defineTool({
  description:
    "Attach an actual outcome to an existing recommendation (close, invalidate). Never rewrite the original thesis fields.",
  inputSchema: z.object({
    id: z.string().min(1),
    status: z.enum(["closed", "invalidated", "open"]),
    exitPremium: z.number().optional(),
    returnOnCapitalPct: z.number().optional(),
    realizedPnl: z.number().optional(),
    lessons: z.string().optional(),
  }),
  async execute(input) {
    return updateRecommendationOutcome(input);
  },
});

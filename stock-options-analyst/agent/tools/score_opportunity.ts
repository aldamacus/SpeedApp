import { defineTool } from "eve/tools";
import { z } from "zod";
import { scoreOpportunity } from "../lib/scoring";

export default defineTool({
  description:
    "Compute the composite opportunity score (0–100) from the six weighted pillars. Use after you have judged each pillar; the score is a screen, not a win probability.",
  inputSchema: z.object({
    ticker: z.string().min(1).max(12),
    fundamentalQuality: z.number().min(0).max(100),
    businessCycleAlignment: z.number().min(0).max(100),
    technicalSetup: z.number().min(0).max(100),
    optionsValuation: z.number().min(0).max(100),
    riskReward: z.number().min(0).max(100),
    liquidity: z.number().min(0).max(100),
  }),
  async execute(input) {
    const scored = scoreOpportunity(input);
    return {
      ticker: input.ticker.toUpperCase(),
      ...scored,
      disclaimer:
        "Score is a screening tool only. It is not a probability of success or a substitute for a full thesis.",
    };
  },
});

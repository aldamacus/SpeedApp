import { defineTool } from "eve/tools";
import { z } from "zod";
import { listRecommendations } from "../lib/journal";

export default defineTool({
  description:
    "List previously recorded trade recommendations and outcomes for performance review. Do not alter historical theses.",
  inputSchema: z.object({
    ticker: z.string().optional(),
    status: z.enum(["open", "closed", "invalidated", "watchlist"]).optional(),
    limit: z.number().int().min(1).max(100).optional(),
  }),
  async execute(input) {
    const { recommendations, source, diskPath } = await listRecommendations();
    let rows = recommendations;
    if (input.ticker) {
      const ticker = input.ticker.toUpperCase();
      rows = rows.filter((r) => r.ticker === ticker);
    }
    if (input.status) {
      rows = rows.filter((r) => r.status === input.status);
    }
    const limit = input.limit ?? 25;
    return {
      count: rows.length,
      recommendations: rows.slice(0, limit),
      source,
      diskPath,
    };
  },
});

import { defineTool } from "eve/tools";
import { z } from "zod";
import { fetchFredMacroSnapshot } from "../lib/market-data";

export default defineTool({
  description:
    "Fetch a US business-cycle macro snapshot from FRED (GDP, CPI/PCE, unemployment, Fed funds, yield curve, credit spreads, etc.). Requires FRED_API_KEY for live values; otherwise returns the series checklist and an explicit data gap.",
  inputSchema: z.object({}),
  async execute(_input, ctx) {
    return fetchFredMacroSnapshot(ctx.abortSignal);
  },
});

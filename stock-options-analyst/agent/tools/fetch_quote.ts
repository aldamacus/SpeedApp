import { defineTool } from "eve/tools";
import { z } from "zod";
import { fetchYahooQuote } from "../lib/market-data";

export default defineTool({
  description:
    "Fetch a US-listed stock quote and basic valuation fields (price, PE, market cap, 52-week range). Uses delayed/unofficial market data; never invent missing fields.",
  inputSchema: z.object({
    symbol: z
      .string()
      .min(1)
      .max(12)
      .describe("Ticker symbol, e.g. AAPL or MSFT"),
  }),
  async execute({ symbol }, ctx) {
    return fetchYahooQuote(symbol, ctx.abortSignal);
  },
});

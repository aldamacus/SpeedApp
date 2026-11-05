import { defineTool } from "eve/tools";
import { z } from "zod";
import { fetchYahooOptionsChain } from "../lib/market-data";

export default defineTool({
  description:
    "Fetch a live listed-options chain for a US ticker (calls/puts, strikes, bid/ask, volume, open interest, IV when available). Optionally pin an expiration YYYY-MM-DD. Never invent premiums or Greeks.",
  inputSchema: z.object({
    symbol: z.string().min(1).max(12),
    expiration: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional()
      .describe("Optional expiration date YYYY-MM-DD"),
    maxContractsPerSide: z
      .number()
      .int()
      .min(5)
      .max(80)
      .optional()
      .describe("Trim returned strikes nearest the money for token efficiency"),
  }),
  async execute({ symbol, expiration, maxContractsPerSide }, ctx) {
    const chain = await fetchYahooOptionsChain(
      symbol,
      expiration,
      ctx.abortSignal,
    );
    const limit = maxContractsPerSide ?? 25;
    const underlying = chain.underlyingPrice;

    const trim = <T extends { strike: number }>(rows: T[]): T[] => {
      if (!underlying || rows.length <= limit) return rows.slice(0, limit);
      return [...rows]
        .sort(
          (a, b) =>
            Math.abs(a.strike - underlying) - Math.abs(b.strike - underlying),
        )
        .slice(0, limit)
        .sort((a, b) => a.strike - b.strike);
    };

    return {
      ...chain,
      calls: trim(chain.calls),
      puts: trim(chain.puts),
      trimmed: true,
      trimLimit: limit,
    };
  },
});

import { defineState } from "eve/context";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

export type RecommendationStatus =
  | "open"
  | "closed"
  | "invalidated"
  | "watchlist";

export type TradeRecommendation = {
  id: string;
  recordedAt: string;
  ticker: string;
  direction: "bullish" | "bearish" | "neutral";
  strategy: string;
  thesis: string;
  stockPriceAtRecommendation?: number;
  expiration?: string;
  strikes?: string;
  entryPremium?: number;
  maxRisk?: number;
  targetPrice?: number;
  exitConditions?: string;
  score?: number;
  classification?:
    | "STRONG_BUY_SETUP"
    | "BUY_SETUP"
    | "WATCHLIST"
    | "WAIT_FOR_BETTER_ENTRY"
    | "AVOID"
    | "NO_TRADE";
  status: RecommendationStatus;
  outcome?: {
    closedAt: string;
    exitPremium?: number;
    returnOnCapitalPct?: number;
    lessons?: string;
    realizedPnl?: number;
  };
};

type JournalState = {
  recommendations: TradeRecommendation[];
};

export const tradeJournal = defineState(
  "stock-options-analyst.trade-journal",
  (): JournalState => ({ recommendations: [] }),
);

function journalPath(): string {
  return (
    process.env.TRADE_JOURNAL_PATH ??
    path.join(process.cwd(), "data", "trade-journal.json")
  );
}

async function readDiskJournal(): Promise<TradeRecommendation[]> {
  try {
    const raw = await readFile(journalPath(), "utf8");
    const parsed = JSON.parse(raw) as { recommendations?: TradeRecommendation[] };
    return Array.isArray(parsed.recommendations) ? parsed.recommendations : [];
  } catch {
    return [];
  }
}

async function writeDiskJournal(
  recommendations: TradeRecommendation[],
): Promise<{ persisted: boolean; path: string; error?: string }> {
  const filePath = journalPath();
  try {
    await mkdir(path.dirname(filePath), { recursive: true });
    await writeFile(
      filePath,
      JSON.stringify({ recommendations }, null, 2),
      "utf8",
    );
    return { persisted: true, path: filePath };
  } catch (error) {
    return {
      persisted: false,
      path: filePath,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

export async function listRecommendations(): Promise<{
  recommendations: TradeRecommendation[];
  source: "session+disk";
  diskPath: string;
}> {
  const disk = await readDiskJournal();
  const session = tradeJournal.get().recommendations;
  const byId = new Map<string, TradeRecommendation>();
  for (const row of disk) byId.set(row.id, row);
  for (const row of session) byId.set(row.id, row);
  return {
    recommendations: [...byId.values()].sort((a, b) =>
      a.recordedAt < b.recordedAt ? 1 : -1,
    ),
    source: "session+disk",
    diskPath: journalPath(),
  };
}

export async function recordRecommendation(
  input: Omit<TradeRecommendation, "id" | "recordedAt" | "status"> & {
    status?: RecommendationStatus;
  },
): Promise<{
  recommendation: TradeRecommendation;
  persistence: { persisted: boolean; path: string; error?: string };
}> {
  const recommendation: TradeRecommendation = {
    ...input,
    id: `rec_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`,
    recordedAt: new Date().toISOString(),
    status: input.status ?? "open",
  };

  tradeJournal.update((state) => ({
    recommendations: [recommendation, ...state.recommendations],
  }));

  const current = await listRecommendations();
  const persistence = await writeDiskJournal(current.recommendations);

  return { recommendation, persistence };
}

export async function updateRecommendationOutcome(input: {
  id: string;
  status: Exclude<RecommendationStatus, "watchlist">;
  exitPremium?: number;
  returnOnCapitalPct?: number;
  realizedPnl?: number;
  lessons?: string;
}): Promise<{
  recommendation?: TradeRecommendation;
  found: boolean;
  persistence: { persisted: boolean; path: string; error?: string };
}> {
  const current = await listRecommendations();
  const index = current.recommendations.findIndex((r) => r.id === input.id);
  if (index < 0) {
    return {
      found: false,
      persistence: { persisted: false, path: journalPath() },
    };
  }

  const existing = current.recommendations[index]!;
  const updated: TradeRecommendation = {
    ...existing,
    status: input.status,
    outcome: {
      closedAt: new Date().toISOString(),
      exitPremium: input.exitPremium,
      returnOnCapitalPct: input.returnOnCapitalPct,
      realizedPnl: input.realizedPnl,
      lessons: input.lessons,
    },
  };

  const next = [...current.recommendations];
  next[index] = updated;
  tradeJournal.update(() => ({ recommendations: next }));
  const persistence = await writeDiskJournal(next);
  return { recommendation: updated, found: true, persistence };
}

import {
  clearYahooSession,
  getYahooSession,
  yahooHeaders,
} from "./yahoo-session";

export type DataProvenance = {
  retrievedAt: string;
  source: string;
  realtime: boolean;
  currency: string;
  notes: string[];
};

export type QuoteSnapshot = {
  symbol: string;
  shortName?: string;
  price?: number;
  previousClose?: number;
  changePct?: number;
  marketCap?: number;
  trailingPE?: number;
  forwardPE?: number;
  fiftyTwoWeekHigh?: number;
  fiftyTwoWeekLow?: number;
  averageVolume?: number;
  provenance: DataProvenance;
};

export type OptionContract = {
  contractSymbol: string;
  strike: number;
  expiration: string;
  type: "call" | "put";
  bid?: number;
  ask?: number;
  lastPrice?: number;
  volume?: number;
  openInterest?: number;
  impliedVolatility?: number;
  inTheMoney?: boolean;
};

export type OptionsChainSnapshot = {
  symbol: string;
  underlyingPrice?: number;
  expirations: string[];
  selectedExpiration?: string;
  calls: OptionContract[];
  puts: OptionContract[];
  provenance: DataProvenance;
};

export type MacroObservation = {
  seriesId: string;
  title: string;
  date?: string;
  value?: number;
  units?: string;
};

export type MacroSnapshot = {
  observations: MacroObservation[];
  provenance: DataProvenance;
};

function nowIso(): string {
  return new Date().toISOString();
}

async function fetchJson(url: string, init?: RequestInit): Promise<unknown> {
  const response = await fetch(url, {
    ...init,
    headers: {
      ...yahooHeaders(),
      ...(init?.headers ?? {}),
    },
    signal: init?.signal,
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} for ${url}`);
  }
  return response.json();
}

export async function fetchYahooQuote(
  symbol: string,
  signal?: AbortSignal,
): Promise<QuoteSnapshot> {
  const normalized = symbol.trim().toUpperCase();
  const url =
    `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(normalized)}` +
    `?range=5d&interval=1d`;
  const json = (await fetchJson(url, { signal })) as {
    chart?: {
      result?: Array<{
        meta?: Record<string, unknown>;
      }>;
      error?: { description?: string };
    };
  };

  const meta = json.chart?.result?.[0]?.meta;
  if (!meta) {
    throw new Error(
      json.chart?.error?.description ??
        `No chart/quote data returned for ${normalized}`,
    );
  }

  const price = optionalNumber(meta.regularMarketPrice);
  const previousClose =
    optionalNumber(meta.chartPreviousClose) ??
    optionalNumber(meta.previousClose);
  const changePct =
    price !== undefined && previousClose !== undefined && previousClose !== 0
      ? ((price - previousClose) / previousClose) * 100
      : optionalNumber(meta.regularMarketChangePercent);

  return {
    symbol: String(meta.symbol ?? normalized),
    shortName: optionalString(meta.shortName ?? meta.longName),
    price,
    previousClose,
    changePct,
    marketCap: optionalNumber(meta.marketCap),
    trailingPE: optionalNumber(meta.trailingPE),
    forwardPE: optionalNumber(meta.forwardPE),
    fiftyTwoWeekHigh: optionalNumber(meta.fiftyTwoWeekHigh),
    fiftyTwoWeekLow: optionalNumber(meta.fiftyTwoWeekLow),
    averageVolume: optionalNumber(
      meta.averageDailyVolume3Month ?? meta.regularMarketVolume,
    ),
    provenance: {
      retrievedAt: nowIso(),
      source: "Yahoo Finance chart API (delayed/unofficial)",
      realtime: false,
      currency: optionalString(meta.currency) ?? "USD",
      notes: [
        "Delayed or unofficial market data. Verify before any live decision.",
        "Valuation fields may be sparse on the chart endpoint; enrich via filings/web_fetch when needed.",
      ],
    },
  };
}

export async function fetchYahooOptionsChain(
  symbol: string,
  expiration?: string,
  signal?: AbortSignal,
): Promise<OptionsChainSnapshot> {
  const normalized = symbol.trim().toUpperCase();

  const load = async (retry: boolean): Promise<OptionsChainSnapshot> => {
    const session = await getYahooSession(signal);
    const base = `https://query2.finance.yahoo.com/v7/finance/options/${encodeURIComponent(normalized)}`;
    const params = new URLSearchParams({ crumb: session.crumb });
    if (expiration) {
      params.set("date", String(Math.floor(new Date(expiration).getTime() / 1000)));
    }
    const response = await fetch(`${base}?${params.toString()}`, {
      headers: yahooHeaders({ Cookie: session.cookieHeader }),
      signal,
    });

    if ((response.status === 401 || response.status === 403) && !retry) {
      clearYahooSession();
      return load(true);
    }
    if (!response.ok) {
      throw new Error(`HTTP ${response.status} for Yahoo options ${normalized}`);
    }

    const json = (await response.json()) as {
      optionChain?: {
        result?: Array<{
          quote?: { regularMarketPrice?: number };
          expirationDates?: number[];
          options?: Array<{
            expirationDate?: number;
            calls?: Array<Record<string, unknown>>;
            puts?: Array<Record<string, unknown>>;
          }>;
        }>;
        error?: { description?: string };
      };
    };

    const result = json.optionChain?.result?.[0];
    if (!result) {
      throw new Error(
        json.optionChain?.error?.description ??
          `No options chain returned for ${normalized}`,
      );
    }

    const expirations = (result.expirationDates ?? []).map((unix) =>
      new Date(unix * 1000).toISOString().slice(0, 10),
    );
    const optionBlock = result.options?.[0];
    const selectedExpiration = optionBlock?.expirationDate
      ? new Date(optionBlock.expirationDate * 1000).toISOString().slice(0, 10)
      : expirations[0];

    return {
      symbol: normalized,
      underlyingPrice: optionalNumber(result.quote?.regularMarketPrice),
      expirations,
      selectedExpiration,
      calls: (optionBlock?.calls ?? []).map((c) => mapContract(c, "call")),
      puts: (optionBlock?.puts ?? []).map((p) => mapContract(p, "put")),
      provenance: {
        retrievedAt: nowIso(),
        source: "Yahoo Finance options API (delayed/unofficial, crumb auth)",
        realtime: false,
        currency: "USD",
        notes: [
          "Never invent premiums, Greeks, open interest, or IV. If a field is missing, say so.",
          "Prefer liquid strikes with tight bid/ask, meaningful open interest, and adequate volume.",
        ],
      },
    };
  };

  return load(false);
}

/** Common US macro series. Requires FRED_API_KEY for live values. */
const DEFAULT_FRED_SERIES: Array<{ id: string; title: string }> = [
  { id: "GDP", title: "US Real GDP" },
  { id: "CPIAUCSL", title: "CPI All Urban Consumers" },
  { id: "PCEPI", title: "PCE Price Index" },
  { id: "UNRATE", title: "Unemployment Rate" },
  { id: "PAYEMS", title: "Nonfarm Payrolls" },
  { id: "FEDFUNDS", title: "Federal Funds Effective Rate" },
  { id: "T10Y2Y", title: "10Y-2Y Treasury Spread" },
  { id: "INDPRO", title: "Industrial Production" },
  { id: "UMCSENT", title: "U of Michigan Consumer Sentiment" },
  { id: "BAMLH0A0HYM2", title: "ICE BofA US High Yield OAS" },
];

export async function fetchFredMacroSnapshot(
  signal?: AbortSignal,
): Promise<MacroSnapshot> {
  const apiKey = process.env.FRED_API_KEY;
  const notes: string[] = [];

  if (!apiKey) {
    return {
      observations: DEFAULT_FRED_SERIES.map((s) => ({
        seriesId: s.id,
        title: s.title,
      })),
      provenance: {
        retrievedAt: nowIso(),
        source: "FRED (not queried — set FRED_API_KEY)",
        realtime: false,
        currency: "n/a",
        notes: [
          "FRED_API_KEY is unset. Macro values were not fetched. Use web_search/web_fetch for public releases, or set FRED_API_KEY.",
        ],
      },
    };
  }

  const observations: MacroObservation[] = [];
  for (const series of DEFAULT_FRED_SERIES) {
    try {
      const url =
        `https://api.stlouisfed.org/fred/series/observations` +
        `?series_id=${encodeURIComponent(series.id)}` +
        `&api_key=${encodeURIComponent(apiKey)}` +
        `&file_type=json&sort_order=desc&limit=1`;
      const json = (await fetchJson(url, { signal })) as {
        observations?: Array<{ date?: string; value?: string }>;
      };
      const obs = json.observations?.[0];
      const raw = obs?.value;
      const value =
        raw && raw !== "." && Number.isFinite(Number(raw))
          ? Number(raw)
          : undefined;
      observations.push({
        seriesId: series.id,
        title: series.title,
        date: obs?.date,
        value,
      });
    } catch (error) {
      notes.push(
        `Failed to load ${series.id}: ${error instanceof Error ? error.message : String(error)}`,
      );
      observations.push({ seriesId: series.id, title: series.title });
    }
  }

  return {
    observations,
    provenance: {
      retrievedAt: nowIso(),
      source: "FRED API",
      realtime: false,
      currency: "n/a",
      notes:
        notes.length > 0
          ? notes
          : ["Observations are the latest available FRED prints, not forecasts."],
    },
  };
}

function mapContract(
  row: Record<string, unknown>,
  type: "call" | "put",
): OptionContract {
  const expirationUnix = optionalNumber(row.expiration);
  return {
    contractSymbol: String(row.contractSymbol ?? ""),
    strike: optionalNumber(row.strike) ?? 0,
    expiration: expirationUnix
      ? new Date(expirationUnix * 1000).toISOString().slice(0, 10)
      : "",
    type,
    bid: optionalNumber(row.bid),
    ask: optionalNumber(row.ask),
    lastPrice: optionalNumber(row.lastPrice),
    volume: optionalNumber(row.volume),
    openInterest: optionalNumber(row.openInterest),
    impliedVolatility: optionalNumber(row.impliedVolatility),
    inTheMoney: typeof row.inTheMoney === "boolean" ? row.inTheMoney : undefined,
  };
}

function optionalNumber(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "" && Number.isFinite(Number(value))) {
    return Number(value);
  }
  return undefined;
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() !== "" ? value : undefined;
}

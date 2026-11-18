type YahooSession = {
  cookieHeader: string;
  crumb: string;
  fetchedAtMs: number;
};

let cached: YahooSession | null = null;
const SESSION_TTL_MS = 30 * 60 * 1000;

const YAHOO_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

export function yahooHeaders(extra?: HeadersInit): HeadersInit {
  return {
    Accept: "application/json,text/plain,*/*",
    "User-Agent": YAHOO_UA,
    ...(extra ?? {}),
  };
}

function collectSetCookies(response: Response): string[] {
  const headers = response.headers as Headers & {
    getSetCookie?: () => string[];
  };
  if (typeof headers.getSetCookie === "function") {
    return headers.getSetCookie();
  }
  const single = response.headers.get("set-cookie");
  return single ? [single] : [];
}

function mergeCookieJar(existing: string, setCookies: string[]): string {
  const jar = new Map<string, string>();
  for (const part of existing.split(";")) {
    const trimmed = part.trim();
    if (!trimmed) continue;
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    jar.set(trimmed.slice(0, eq), trimmed.slice(eq + 1));
  }
  for (const raw of setCookies) {
    const first = raw.split(";", 1)[0] ?? "";
    const eq = first.indexOf("=");
    if (eq <= 0) continue;
    jar.set(first.slice(0, eq).trim(), first.slice(eq + 1).trim());
  }
  return [...jar.entries()].map(([k, v]) => `${k}=${v}`).join("; ");
}

export async function getYahooSession(
  signal?: AbortSignal,
): Promise<YahooSession> {
  if (cached && Date.now() - cached.fetchedAtMs < SESSION_TTL_MS) {
    return cached;
  }

  let cookieHeader = "";
  const consent = await fetch("https://fc.yahoo.com", {
    headers: yahooHeaders(),
    redirect: "manual",
    signal,
  });
  cookieHeader = mergeCookieJar(cookieHeader, collectSetCookies(consent));

  const crumbResponse = await fetch(
    "https://query2.finance.yahoo.com/v1/test/getcrumb",
    {
      headers: yahooHeaders({
        Cookie: cookieHeader,
      }),
      signal,
    },
  );
  cookieHeader = mergeCookieJar(cookieHeader, collectSetCookies(crumbResponse));
  if (!crumbResponse.ok) {
    throw new Error(`Yahoo crumb HTTP ${crumbResponse.status}`);
  }
  const crumb = (await crumbResponse.text()).trim();
  if (!crumb || crumb.toLowerCase().includes("unauthorized")) {
    throw new Error("Yahoo crumb unavailable");
  }

  cached = { cookieHeader, crumb, fetchedAtMs: Date.now() };
  return cached;
}

export function clearYahooSession(): void {
  cached = null;
}

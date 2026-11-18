# Stock & Options Trading Analyst Agent

Claude-powered [eve](https://eve.dev) agent that finds **decision-support** US equity options opportunities with a top-down process:

**Macro → business cycle → sector rotation → fundamentals → technicals → options structure → risk.**

It does **not** place trades. It separates a long-term **investment watchlist** from a near-term **options trading watchlist**, and it will recommend **NO TRADE** when evidence is weak.

## What it does

- Classifies the US business cycle with confidence and conflicts
- Ranks sectors for the current cycle (not theme hype)
- Screens liquid NYSE/NASDAQ names
- Inspects real options chains when available (never invents premiums/Greeks/IV)
- Chooses defined-risk strategies from a volatility-regime framework
- Scores opportunities and sizes positions from **maximum loss**
- Journals recommendations for later review
- Runs weekday **daily scanner** and Monday **weekly cycle** schedules

## Requirements

- **Node.js 24.x**
- AI Gateway credentials for `anthropic/claude-sonnet-4.5` (via Vercel / eve deploy, or local provider env)
- Optional: `FRED_API_KEY` for live macro series
- Optional: link Vercel + Blob for durable `memory/file` in production

## Quick start

```bash
cd stock-options-analyst
npm install
cp .env.example .env   # then fill keys you have
npm run typecheck
npm run check:scoring
npm exec -- eve dev --no-ui
```

Interactive TUI:

```bash
npm exec -- eve dev
```

Example prompts:

- “Full market analysis: cycle, sectors, dual watchlists, top options setups.”
- “Set trading capital to €25,000 and risk to 1%.”
- “Analyze NVDA as an options candidate for the current cycle — challenge the thesis.”

## Tools

| Tool | Role |
| --- | --- |
| `get_trading_config` / `set_trading_config` | Capital, risk, horizons |
| `fetch_macro_snapshot` | FRED cycle indicators |
| `fetch_quote` | Equity snapshot |
| `fetch_options_chain` | Listed options |
| `suggest_volatility_strategy` | IV × direction framework |
| `score_opportunity` | Weighted 0–100 screen |
| `size_position` | Max-loss position sizing |
| `record_recommendation` / `list_recommendations` / `update_recommendation_outcome` | Trade journal |
| `web_search` / `web_fetch` | Primary releases & filings |

## Schedules (UTC)

| Schedule | Cron | Purpose |
| --- | --- | --- |
| `daily-market-scanner` | `0 13 * * 1-5` | Weekday options scanner |
| `weekly-business-cycle` | `0 7 * * 1` | Weekly cycle + investment watchlist |

In `eve dev`, fire once with:

```bash
curl -X POST http://localhost:2000/eve/v1/dev/schedules/daily-market-scanner
curl -X POST http://localhost:2000/eve/v1/dev/schedules/weekly-business-cycle
```

## Evals

```bash
npm exec -- eve eval
```

Model-backed evals need a working Claude / AI Gateway credential.

## Deploy

```bash
npm exec -- eve link --non-interactive --project stock-options-analyst
npm exec -- eve add memory/file --non-interactive --skip-install   # after link, for Blob memory
npm exec -- eve deploy --non-interactive --yes
```

## Disclaimer

This agent is analytical decision support only. It is not personalized financial advice, a broker, or an execution system. Market data may be delayed or incomplete. You are responsible for verifying figures and for compliance with applicable law.

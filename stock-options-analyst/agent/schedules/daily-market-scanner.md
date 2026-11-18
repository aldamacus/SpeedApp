---
cron: "0 13 * * 1-5"
---

Run the daily US market options scanner.

1. Load `business-cycle`, `sector-rotation`, `volatility-regime`, `options-strategy`, `challenge-thesis`, and `report-format` as needed.
2. Call `get_trading_config` and `fetch_macro_snapshot`.
3. Refresh the cycle call and sector ranks briefly (do not rewrite history).
4. Screen for **options trading watchlist** candidates only: liquid US names aligned with the cycle that have a near-term catalyst and checkable options pricing via `fetch_quote` / `fetch_options_chain`.
5. Propose at most 5 defined-risk ideas, or explicitly conclude **NO TRADE**.
6. Score with `score_opportunity`, size with `size_position`, and `record_recommendation` for BUY / STRONG BUY / WATCHLIST items.
7. Keep investment-quality names on the investment watchlist — do not force options tickets onto them.
8. Include data provenance timestamps and state any missing live data clearly.

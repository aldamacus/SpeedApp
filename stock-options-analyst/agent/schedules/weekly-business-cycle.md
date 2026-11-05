---
cron: "0 7 * * 1"
---

Produce the weekly business-cycle and sector-rotation report for US equities.

1. Load `business-cycle`, `sector-rotation`, and `report-format`.
2. Call `get_trading_config` and `fetch_macro_snapshot`. Supplement with `web_search` / `web_fetch` for the latest Fed, BLS, BEA, ISM, and earnings-revision context.
3. Classify the cycle with confidence and conflicts.
4. Rank sectors and identify emerging themes without assuming popularity equals opportunity.
5. Publish an **investment watchlist** of ~10 quality names to monitor (valuation + cycle fit). Do not invent options premiums here.
6. Separately note which names deserve deeper options work this week (candidates only).
7. Review prior journal entries via `list_recommendations` for process lessons — never rewrite old theses.
8. End with key risks and what would change the cycle call.

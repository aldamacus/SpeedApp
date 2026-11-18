---
description: Full market analysis report skeleton with dual watchlists, scored options opportunities, and final classifications.
---

# Standard reporting format

## A. Executive summary
Market environment, cycle stage, main themes, outlook, key risks.

## B. Business cycle dashboard
Indicator | Current condition | Interpretation  
(GDP, inflation, rates, employment, PMI, curve, credit spreads, …)

## C. Sector rotation
Top five attractive sectors with why; underweights with why.

## D. Investment watchlist (≈10)
Quality companies to **monitor** on cycle + valuation (not automatically tradeable options).  
Columns: ticker, sector, valuation snapshot, fundamental outlook, technical outlook, catalyst.

## E. Options trading watchlist / top opportunities (≤5)
Only names with attractive options pricing **and** a near-term catalyst. For each:

1. Investment thesis  
2. Business-cycle alignment  
3. Stock valuation  
4. Technical entry conditions  
5. Options strategy (+ vol regime rationale)  
6. Expiration and strikes (from real chain data only)  
7. Estimated premium (label delayed/estimate)  
8. Max loss and max profit  
9. Breakeven  
10. Exit strategy  
11. Main risks + bull/base/bear  
12. Confidence / `score_opportunity` total  

If none qualify → **NO TRADE**.

## F. What could go wrong?
Macro, company, earnings, volatility, geopolitics, rate-expectation shifts.

## G. Final recommendation labels
- STRONG BUY SETUP  
- BUY SETUP  
- WATCHLIST  
- WAIT FOR BETTER ENTRY  
- AVOID  
- NO TRADE  

Only use STRONG when evidence is strong across pillars. Record actionable setups with `record_recommendation`.

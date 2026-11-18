---
description: Classify the US economic cycle stage with indicator evidence and confidence; use on every full market or sector analysis.
---

# Business cycle classification

Classify the economy into **one** primary stage and assign a **confidence** level (low / medium / high). Do not force a textbook pattern when inflation, policy, fiscal, or geopolitics distort the cycle.

## Stages

### A. Early Expansion / Recovery
Growth accelerating from a low base; rates stabilizing/declining; credit improving; manufacturing recovering; earnings starting to accelerate.

Often favors: Financials, Consumer Discretionary, Industrials, Technology, small-caps, Materials. Growth/cyclicals with operating leverage. Long calls / bullish debit spreads when IV allows.

### B. Mid-Cycle Expansion
Healthy GDP; strong employment/spending; expanding earnings; controlled inflation; normal credit.

Often favors: Technology, Industrials, Communication Services, Financials, selected Discretionary. Quality growth / compounders. Bull call spreads; CSPs on quality names.

### C. Late-Cycle / Slowdown
Decelerating GDP; sticky inflation possible; restrictive rates; widening credit spreads; margin pressure; softening labor.

Often favors: Healthcare, Staples, Utilities, Energy (commodity-dependent), quality dividend names. Defensive / relative-value. Bearish put spreads, covered calls; cut leveraged exposure.

### D. Recession / Contraction
Contracting activity; rising unemployment; weak demand; falling earnings; rising defaults; potential policy easing.

Often favors: Staples, Healthcare, Utilities, selected defensives. Long puts / bear put spreads; selective accumulation of quality after deep corrections.

## Indicator checklist

Use multiple series (via `fetch_macro_snapshot` and primary releases), not a single print:

- GDP / GDPNow
- CPI and PCE
- Unemployment / NFP
- 2s10s yield curve
- Fed policy / forwards
- ISM Manufacturing & Services PMI
- Consumer confidence / retail sales
- Earnings revisions
- High-yield credit spreads
- Leading Economic Index / financial conditions

## Output

Produce a short dashboard row set:

| Indicator | Current condition | Interpretation |

Then: **Stage**, **Confidence**, **Key conflicts** (what argues against your call), **Policy/fiscal/geopolitical overlays**.

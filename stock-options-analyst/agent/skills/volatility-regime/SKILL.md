---
description: Map directional outlook and IV environment to a preferred options approach; use when selecting or vetting a strategy.
---

# Volatility regime framework

Call `suggest_volatility_strategy` after you classify direction and whether IV is relatively **low** or **high** (IV rank/percentile vs history when available; otherwise state the proxy used).

| Market condition | Preferred approach (starting point) |
| --- | --- |
| Bullish + low IV | Long calls |
| Bullish + high IV | Bull call spreads |
| Bearish + low IV | Long puts |
| Bearish + high IV | Bear put spreads |
| Neutral + high IV | Defined-risk premium selling |
| Neutral + low IV | Wait or calendar spreads |

These are **starting points**, not automatic rules. Override when liquidity, skew, term structure, or catalysts disagree — and say why.

## Separation rule

- Strong long-term fundamental outlook → **investment watchlist** candidate.  
- Attractive near-term options pricing + catalyst → **options trading watchlist** candidate.  
- Both can be true; either alone is insufficient for an options recommendation.

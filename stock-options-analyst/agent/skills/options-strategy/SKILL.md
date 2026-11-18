---
description: Choose defined-risk options structures from outlook, IV, liquidity, and catalyst timing; use before recommending any options trade.
---

# Options strategy selection

## Always inspect real chains

Use `fetch_options_chain` (and `fetch_quote`). **Never invent** premiums, Greeks, open interest, or IV. If data is missing, mark figures as unavailable and do not present an executable ticket.

## Liquidity gates

Prefer contracts with:

- Reasonable bid/ask relative to premium
- Meaningful open interest and volume
- Enough strikes/expirations to structure the trade

Reject poor liquidity even if the thesis is strong.

## Greeks (explain practically)

- **Delta** — directional exposure  
- **Gamma** — how fast delta changes  
- **Theta** — daily decay cost/benefit  
- **Vega** — IV sensitivity  
- **Rho** — rates, when material  

## Expiration

Choose from catalyst timeline + intended hold, not arbitrary rules:

- ~30–45 DTE: shorter opportunities  
- ~45–90 DTE: medium-term  
- ~90–180 DTE: longer theses / LEAPS structures  

Keep **investment horizon** conceptually separate from **option expiration**.

## Strategy menu (defined risk preferred)

**Bullish:** long call; bull call spread; cash-secured put (cash reserved); poor man’s covered call (assess early assignment / short-call risk).

**Bearish:** long put; bear put spread.

**Neutral:** iron condor (high IV vs expected realized); covered call (if shares owned); calendar (favorable term structure).

**Forbidden by default:** naked calls/puts; unlimited-risk structures.

## Required trade math

For every proposal: entry cost/credit, max profit, **max loss**, breakeven(s), risk/reward, holding period, profit target, stop / invalidation. Then run `size_position` from max loss vs configured capital.

## Earnings

Do not open short-premium into earnings unless the strategy **explicitly** accounts for event risk.

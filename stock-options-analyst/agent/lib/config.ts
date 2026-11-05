import { defineState } from "eve/context";

export type RiskTolerance = "conservative" | "moderate" | "aggressive";

export type TradingConfig = {
  market: "US";
  riskTolerance: RiskTolerance;
  tradingCapital: number;
  currency: "EUR" | "USD";
  maxRiskPerTradePct: number;
  maxCorrelatedRiskPct: number;
  optionsHorizonDaysMin: number;
  optionsHorizonDaysMax: number;
  investmentOutlookMonthsMin: number;
  investmentOutlookMonthsMax: number;
  preferredStrategies: string[];
  nakedOptionsAllowed: boolean;
  topOpportunities: number;
};

export const DEFAULT_TRADING_CONFIG: TradingConfig = {
  market: "US",
  riskTolerance: "moderate",
  tradingCapital: 20_000,
  currency: "EUR",
  maxRiskPerTradePct: 1.5,
  maxCorrelatedRiskPct: 5,
  optionsHorizonDaysMin: 30,
  optionsHorizonDaysMax: 180,
  investmentOutlookMonthsMin: 1,
  investmentOutlookMonthsMax: 6,
  preferredStrategies: [
    "long_call",
    "long_put",
    "bull_call_spread",
    "bear_put_spread",
    "covered_call",
    "cash_secured_put",
  ],
  nakedOptionsAllowed: false,
  topOpportunities: 5,
};

export const tradingConfig = defineState(
  "stock-options-analyst.trading-config",
  (): TradingConfig => ({ ...DEFAULT_TRADING_CONFIG }),
);

export function maxLossBudget(config: TradingConfig): number {
  return (config.tradingCapital * config.maxRiskPerTradePct) / 100;
}

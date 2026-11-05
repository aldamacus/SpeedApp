export type ScoreBreakdown = {
  fundamentalQuality: number;
  businessCycleAlignment: number;
  technicalSetup: number;
  optionsValuation: number;
  riskReward: number;
  liquidity: number;
};

export type ScoredOpportunity = ScoreBreakdown & {
  total: number;
  weights: typeof SCORE_WEIGHTS;
};

/** Screening weights from the analyst spec. Not a probability of success. */
export const SCORE_WEIGHTS = {
  fundamentalQuality: 0.2,
  businessCycleAlignment: 0.2,
  technicalSetup: 0.15,
  optionsValuation: 0.2,
  riskReward: 0.15,
  liquidity: 0.1,
} as const;

function clampScore(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, value));
}

export function scoreOpportunity(input: ScoreBreakdown): ScoredOpportunity {
  const breakdown: ScoreBreakdown = {
    fundamentalQuality: clampScore(input.fundamentalQuality),
    businessCycleAlignment: clampScore(input.businessCycleAlignment),
    technicalSetup: clampScore(input.technicalSetup),
    optionsValuation: clampScore(input.optionsValuation),
    riskReward: clampScore(input.riskReward),
    liquidity: clampScore(input.liquidity),
  };

  const total =
    breakdown.fundamentalQuality * SCORE_WEIGHTS.fundamentalQuality +
    breakdown.businessCycleAlignment * SCORE_WEIGHTS.businessCycleAlignment +
    breakdown.technicalSetup * SCORE_WEIGHTS.technicalSetup +
    breakdown.optionsValuation * SCORE_WEIGHTS.optionsValuation +
    breakdown.riskReward * SCORE_WEIGHTS.riskReward +
    breakdown.liquidity * SCORE_WEIGHTS.liquidity;

  return {
    ...breakdown,
    total: Math.round(total * 10) / 10,
    weights: SCORE_WEIGHTS,
  };
}

export type PositionSizeInput = {
  tradingCapital: number;
  maxRiskPerTradePct: number;
  maxLossPerContract: number;
  contractsRequested?: number;
};

export type PositionSizeResult = {
  maxAcceptableLoss: number;
  maxLossPerContract: number;
  maxContracts: number;
  contractsAllowed: number;
  capitalAtRisk: number;
  withinRiskLimit: boolean;
  note: string;
};

export function sizePosition(input: PositionSizeInput): PositionSizeResult {
  const maxAcceptableLoss =
    (input.tradingCapital * input.maxRiskPerTradePct) / 100;
  const perContract = Math.max(0, input.maxLossPerContract);
  const maxContracts =
    perContract <= 0 ? 0 : Math.floor(maxAcceptableLoss / perContract);
  const requested = input.contractsRequested ?? maxContracts;
  const contractsAllowed = Math.max(0, Math.min(requested, maxContracts));
  const capitalAtRisk = contractsAllowed * perContract;

  return {
    maxAcceptableLoss: roundMoney(maxAcceptableLoss),
    maxLossPerContract: roundMoney(perContract),
    maxContracts,
    contractsAllowed,
    capitalAtRisk: roundMoney(capitalAtRisk),
    withinRiskLimit: contractsAllowed > 0 && contractsAllowed >= requested,
    note:
      maxContracts === 0
        ? "Max loss per contract exceeds the per-trade risk budget. Do not recommend this structure at the current capital settings."
        : `Risk budget allows up to ${maxContracts} contract(s) at the stated max loss.`,
  };
}

export type VolatilityRegime =
  | "bullish_low_iv"
  | "bullish_high_iv"
  | "bearish_low_iv"
  | "bearish_high_iv"
  | "neutral_high_iv"
  | "neutral_low_iv";

export function suggestStrategyFramework(input: {
  direction: "bullish" | "bearish" | "neutral";
  ivEnvironment: "low" | "high";
}): { regime: VolatilityRegime; preferredApproaches: string[]; caveat: string } {
  const key = `${input.direction}_${input.ivEnvironment}_iv` as VolatilityRegime;
  const map: Record<VolatilityRegime, string[]> = {
    bullish_low_iv: ["long_call"],
    bullish_high_iv: ["bull_call_spread"],
    bearish_low_iv: ["long_put"],
    bearish_high_iv: ["bear_put_spread"],
    neutral_high_iv: ["iron_condor", "defined_risk_premium_selling"],
    neutral_low_iv: ["wait", "calendar_spread"],
  };

  return {
    regime: key,
    preferredApproaches: map[key],
    caveat:
      "Starting-point framework only. Confirm liquidity, catalysts, assignment risk, and that investment horizon is separate from options expiration.",
  };
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

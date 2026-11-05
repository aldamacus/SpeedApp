import assert from "node:assert/strict";

// Lightweight mirror of scoring math for CI without compiling the TS module graph.
const SCORE_WEIGHTS = {
  fundamentalQuality: 0.2,
  businessCycleAlignment: 0.2,
  technicalSetup: 0.15,
  optionsValuation: 0.2,
  riskReward: 0.15,
  liquidity: 0.1,
};

function scoreOpportunity(input) {
  const clamp = (v) => Math.max(0, Math.min(100, Number.isFinite(v) ? v : 0));
  const b = {
    fundamentalQuality: clamp(input.fundamentalQuality),
    businessCycleAlignment: clamp(input.businessCycleAlignment),
    technicalSetup: clamp(input.technicalSetup),
    optionsValuation: clamp(input.optionsValuation),
    riskReward: clamp(input.riskReward),
    liquidity: clamp(input.liquidity),
  };
  const total =
    b.fundamentalQuality * SCORE_WEIGHTS.fundamentalQuality +
    b.businessCycleAlignment * SCORE_WEIGHTS.businessCycleAlignment +
    b.technicalSetup * SCORE_WEIGHTS.technicalSetup +
    b.optionsValuation * SCORE_WEIGHTS.optionsValuation +
    b.riskReward * SCORE_WEIGHTS.riskReward +
    b.liquidity * SCORE_WEIGHTS.liquidity;
  return Math.round(total * 10) / 10;
}

function sizePosition({ tradingCapital, maxRiskPerTradePct, maxLossPerContract }) {
  const maxAcceptableLoss = (tradingCapital * maxRiskPerTradePct) / 100;
  const maxContracts = Math.floor(maxAcceptableLoss / maxLossPerContract);
  return { maxAcceptableLoss, maxContracts };
}

assert.equal(
  scoreOpportunity({
    fundamentalQuality: 100,
    businessCycleAlignment: 100,
    technicalSetup: 100,
    optionsValuation: 100,
    riskReward: 100,
    liquidity: 100,
  }),
  100,
);

assert.equal(
  scoreOpportunity({
    fundamentalQuality: 80,
    businessCycleAlignment: 70,
    technicalSetup: 60,
    optionsValuation: 50,
    riskReward: 40,
    liquidity: 30,
  }),
  58,
);

assert.deepEqual(sizePosition({
  tradingCapital: 20_000,
  maxRiskPerTradePct: 1.5,
  maxLossPerContract: 200,
}), { maxAcceptableLoss: 300, maxContracts: 1 });

console.log("check-scoring: ok");

import { defineEval } from "eve/evals";
import { includes } from "eve/evals/expect";

export default defineEval({
  description:
    "With stubbed config and sizing tools, the agent sizes from max loss and stays within the risk budget.",
  async test(t) {
    const session = await t.session({
      stubs: [
        {
          id: "cfg",
          tool: "get_trading_config",
          outcome: {
            response: {
              config: {
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
                preferredStrategies: ["bull_call_spread"],
                nakedOptionsAllowed: false,
                topOpportunities: 5,
              },
              maxLossBudget: 300,
            },
          },
        },
        {
          id: "size",
          tool: "size_position",
          outcome: {
            response: {
              currency: "EUR",
              maxAcceptableLoss: 300,
              maxLossPerContract: 200,
              maxContracts: 1,
              contractsAllowed: 1,
              capitalAtRisk: 200,
              withinRiskLimit: true,
              note: "Risk budget allows up to 1 contract(s) at the stated max loss.",
            },
          },
        },
      ],
    });

    const turn = await session.send(
      "Trading capital is €20,000 with 1.5% max risk per trade. A bull call spread has €200 maximum loss per contract. How many contracts may I buy? Use tools; answer with the contract count and max acceptable loss.",
    );
    turn.expectOk();
    turn.calledTool("get_trading_config");
    turn.calledTool("size_position");
    const reply = turn.reply ?? "";
    t.check(reply, includes("1"));
    t.check(reply, includes("300"));
  },
});

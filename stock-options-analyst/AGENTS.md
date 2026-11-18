# eve Agent App — Stock & Options Trading Analyst

This project uses the eve framework. Agent behavior lives under `agent/`.

## Content-only edits

- Identity / workflow: `agent/instructions.md`
- Model: `agent/agent.ts` (currently `anthropic/claude-sonnet-4.5`, reasoning `high`)
- Procedures: `agent/skills/*/SKILL.md`
- Schedules: `agent/schedules/*.md`

## Code-owned logic

Deterministic scoring, sizing, market fetchers, and the trade journal live in `agent/lib/` and are exposed as tools under `agent/tools/`. Prefer changing those for math and data correctness; keep prose in instructions/skills.

## Docs

Bundled docs: `node_modules/eve/docs/README.md`. Public: https://eve.dev/docs.

## Validation

```bash
npm run typecheck
npm run check:scoring
npm exec -- eve build
npm exec -- eve eval
```

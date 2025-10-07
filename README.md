# AI Single-Run with Cursor CLI (Plan → Implement + Claude Reviews)

This repo runs a single end-to-end cycle when manually triggered: it creates a Planning PR, iterates with AI reviews until merged, then creates an Implementation PR, iterates with reviews until merged, and completes. There is no background loop or multi-PR batching.

## What you get
- Planning and implementation guidance via `.cursor/rules/*` consumed by Cursor agent
- Headless scripts to plan, implement, and review PRs
- GitHub Actions to loop between planning and implementation and to auto-review/merge PRs

## Prerequisites
- GitHub repository with Actions enabled
- `CURSOR_API_KEY` secret set in GitHub → Settings → Secrets and variables → Actions
- Optional: branch protection requiring checks (e.g., `AI PR Review (Claude)`)

## Folder layout
```
.cursor/
  rules/
    000-goal.mdc
    100-planning.mdc
    110-implementation.mdc
scripts/
  ai-plan.sh
  ai-implement.sh
  ai-review.sh
  ai-run.sh
.github/
  workflows/
    ai-run.yml
```

## How it works
- `ai-run.yml` (workflow-dispatch only) runs `scripts/ai-run.sh` once.
- `scripts/ai-run.sh` orchestrates:
  1. Create or update a Planning PR (`[PLAN]`, label `ai:planning`), then run `scripts/ai-review.sh` (Claude 4.5 Sonnet) and iterate: request changes → update PR via `scripts/ai-plan.sh`; approve → auto-merge.
  2. Create or update an Implementation PR (`[IMPL]`, label `ai:implementation`), then review and iterate similarly via `scripts/ai-implement.sh` until merged.
  3. Stop. To run again, manually trigger the workflow.

## Setup
1. Create a Cursor API key and add it as `CURSOR_API_KEY` repository secret.
2. Adjust `.cursor/rules/000-goal.mdc` to set your real project goal.
3. Commit and push.

## Usage
- Manual trigger: Actions → `AI Run (Plan → Implement)` → Run workflow.

## Notes
- The CLI is installed in CI from `https://cursor.com/install`.
- You can adjust models in scripts: `gpt-5` for builder, `sonnet-4.5-thinking` for reviews.
- Scripts expect `gh` and `jq` in the runner environment (present on `ubuntu-latest`).

## Safety and guardrails
- Small PRs (target ≤ ~200 changed lines)
- Never commit secrets
- Add/update tests and docs with changes

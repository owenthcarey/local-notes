# AI PR Loop with Cursor CLI (Planning ↔ Implementation + Claude Reviews)

This repo boots a headless AI loop using the Cursor CLI to alternate between planning and implementation PRs, and uses a Claude 4.5 model for automated code reviews. The system can run on a schedule or be triggered manually.

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
.github/
  workflows/
    ai-loop.yml
    ai-review.yml
```

## How it works
- `ai-loop.yml` decides whether to run planning or implementation:
  - `planning` when there are no open `ai/*` PRs
  - `implementation` when there is at least one open `ai/*` PR
- `ai-review.yml` triggers on PR updates. It runs a Claude 4.5 review via Cursor and, if no blockers are found, approves and auto-merges.

## Setup
1. Create a Cursor API key and add it as `CURSOR_API_KEY` repository secret.
2. (Optional) Configure branch protection to require the `AI PR Review (Claude)` job.
3. Adjust `.cursor/rules/000-goal.mdc` to set your real project goal.
4. Commit and push.

## Usage
- Manual trigger: Actions → `AI Loop (Plan ↔ Implement)` → Run workflow.
- Scheduled: runs every 6 hours by default.

## Notes
- The CLI is installed in CI from `https://cursor.com/install`.
- You can adjust models in scripts: `gpt-5-high` for builder, `claude-4.5-sonnet` for Claude 4.5.
- Scripts expect `gh` and `jq` in the runner environment (present on `ubuntu-latest`).

## Safety and guardrails
- Small PRs (target ≤ ~200 changed lines)
- Never commit secrets
- Add/update tests and docs with changes

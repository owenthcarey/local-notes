#!/usr/bin/env bash
set -euo pipefail

MODEL="gpt-5"                  # Builder
PR_URL="${1:-}"

if [ -n "${PR_URL}" ]; then
  export AI_TARGET_PR_URL="${PR_URL}"
fi

read -r -d '' PROMPT <<'EOF' || true
You are PLANNING a single, minimal PR to advance the top-level goal.

Do the following:
1) Open or update exactly ONE Planning PR. If AI_TARGET_PR_URL is provided, update that PR.
2) Title MUST start with [PLAN]. Add label ai:planning. Use branch name ai/<short-task-slug>.
3) Add or update planning docs only (e.g., docs/implementation-plan.md) with rationale, scope, acceptance criteria, and a concise test plan.
4) Keep it surgical (≤ ~200 changed lines). Do NOT implement the feature; focus on docs and any skeletal stubs needed for clarity.
5) Commit and push changes, and ensure the PR description matches the docs.
EOF

# Cursor CLI (headless). Reads .cursor/rules automatically.
cursor-agent chat \
  --model "$MODEL" \
  --print \
  "$PROMPT"

#!/usr/bin/env bash
set -euo pipefail

MODEL="gpt-5"                  # Builder
read -r -d '' PROMPT <<'EOF' || true
PLAN a single, minimal PR to advance the top-level goal.

Requirements:
- Provide PR body with rationale, scope, acceptance criteria, and test plan.
- Keep it surgical (<= ~200 changed lines). Include tests and docs.
- Use branch name ai/<short-task-slug> and title prefix [PLAN]. Add label ai:planning.
- Do not open multiple PRs; create or update a single planning PR as needed.
EOF

# Cursor CLI (headless). Reads .cursor/rules automatically.
cursor-agent chat \
  --model "$MODEL" \
  --print \
  "$PROMPT"

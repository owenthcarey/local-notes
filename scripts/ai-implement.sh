#!/usr/bin/env bash
set -euo pipefail

MODEL="gpt-5"                  # Builder
PR_URL="${1:-}"

read -r -d '' PROMPT <<'EOF' || true
You are implementing EXACTLY ONE planned task.

Rules:
- If there is an OPEN AI PR, update THAT PR's branch with new commits instead of opening a new PR.
- Read the PR description and the latest review comments; address required changes first.
- Keep edits surgical (<= ~200 changed lines). Update tests and docs in the same PR.
- Respect CODEOWNERS and do not include secrets.
- Use branch naming ai/<short-task-slug> if you need to create a branch.
- Title prefixes:
  - [IMPL] for implementation PRs and add label ai:implementation

Output: perform the changes directly via git. Do not print a long plan; make the commits.
EOF

if [ -n "${PR_URL}" ]; then
  export AI_TARGET_PR_URL="${PR_URL}"
fi

cursor-agent chat \
  --model "$MODEL" \
  --print \
  "$PROMPT"

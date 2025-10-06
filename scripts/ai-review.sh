#!/usr/bin/env bash
set -euo pipefail

MODEL="sonnet-4.5-thinking"        # Claude 4.5 Sonnet (thinking)
PR_URL="$1"

if [ -z "${PR_URL:-}" ]; then
  echo "Usage: $0 <PR_URL>" >&2
  exit 2
fi

# Fetch diff and context for the PR (requires GH CLI and jq)
gh pr view "$PR_URL" --json number,headRefName,baseRefName,body,author,url,files > /tmp/pr.json
git fetch origin "$(jq -r '.headRefName' /tmp/pr.json)"
git fetch origin "$(jq -r '.baseRefName' /tmp/pr.json)"
gh pr diff "$PR_URL" > /tmp/pr.diff

read -r -d '' REVIEW_PROMPT <<'EOF' || true
Act as a senior code reviewer.
- Blockers: security, correctness, perf regressions, broken tests, API breaks.
- Nitpicks: avoid; only suggest if trivial and high-impact.
- If changes are required, list exact diffs or small patches.

Return:
1) Summary
2) Blockers (if any) with file:line and why
3) ✅ Approve or ❌ Request changes
EOF

cursor-agent chat \
  --model "$MODEL" \
  --print \
  "$REVIEW_PROMPT

PR DIFF:
/* begin diff */
$(cat /tmp/pr.diff)
/* end diff */
" \
| tee /tmp/review.txt

# Post the review as a PR comment
gh pr comment "$PR_URL" --body-file /tmp/review.txt

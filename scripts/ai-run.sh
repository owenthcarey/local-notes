#!/usr/bin/env bash
set -euo pipefail

# Orchestrates a single Plan → Review loop until merged, then Implement → Review until merged.
# Requires GH CLI and jq. Uses Cursor via scripts/ai-plan.sh, scripts/ai-implement.sh, scripts/ai-review.sh.

ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

git_setup_identity() {
  # Ensure git identity for CI commits
  git config user.name  "github-actions[bot]" 1>/dev/null || true
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com" 1>/dev/null || true
}

ensure_label() {
  local label_name="$1"
  # Try to create; ignore error if exists
  gh label create "$label_name" 1>/dev/null 2>/dev/null || true
}

create_planning_pr() {
  local branch="ai/planning-$(date +%s)"
  local plan_file="PLAN-0001.md"

  echo "[AI RUN] Creating Planning PR via gh on branch $branch..." 1>&2
  git_setup_identity
  git switch -c "$branch"

  cat > "$plan_file" <<'EOF'
# PLAN-0001: Bootstrap localStorage storage module + minimal shell

This planning document outlines the first implementation PR for a client-only notes app with localStorage persistence.

## Goals
- Establish a small storage module backed by localStorage
- Provide a minimal HTML shell that renders notes

## Next steps (to be implemented in the next PR)
- Implement storage helpers (load/save/add/update/delete)
- Minimal UI wiring to storage; ≤ ~200 changed lines overall
EOF

  git add "$plan_file"
  git commit -m "docs(plan): add PLAN-0001 bootstrap storage outline"
  git push -u origin "$branch"

  ensure_label "ai:planning"
  gh pr create \
    --head "$branch" \
    --title "[PLAN] Bootstrap localStorage storage module + minimal app shell" \
    --body "See $plan_file for details." \
    --label "ai:planning"

  local url
  url=$(gh pr list --head "$branch" --state open --json url --jq '.[0].url')
  echo "$url"
}

create_implementation_pr() {
  local branch="ai/implementation-$(date +%s)"
  local stub_file=".ai/impl-stub.md"

  echo "[AI RUN] Creating Implementation PR via gh on branch $branch..." 1>&2
  git_setup_identity
  git switch -c "$branch"

  mkdir -p .ai
  cat > "$stub_file" <<'EOF'
# Implementation PR (stub)

This stub exists so automation can iterate on the Implementation PR without a human creating it.
EOF

  git add "$stub_file"
  git commit -m "chore: open implementation PR stub for automation"
  git push -u origin "$branch"

  ensure_label "ai:implementation"
  gh pr create \
    --head "$branch" \
    --title "[IMPL] Implementation PR (stub)" \
    --body "Automated stub PR to enable review/iteration; will be updated by agent." \
    --label "ai:implementation"

  local url
  url=$(gh pr list --head "$branch" --state open --json url --jq '.[0].url')
  echo "$url"
}

find_open_pr_by_kind() {
  local kind="$1" # planning | implementation
  local label prefix
  if [ "$kind" = "planning" ]; then
    label="ai:planning"; prefix="[PLAN]"
  else
    label="ai:implementation"; prefix="[IMPL]"
  fi

  # Prefer label match
  local url
  url=$(gh pr list --search "is:open label:${label}" --json url --jq '.[0].url' 2>/dev/null || true)
  if [ -n "${url}" ] && [ "${url}" != "null" ]; then
    echo "${url}"
    return 0
  fi

  # Fallback to title prefix
  url=$(gh pr list --search "is:open" --json url,title | jq -r --arg pfx "$prefix" '.[] | select(.title | startswith($pfx)) | .url' | head -n1 || true)
  if [ -n "${url}" ] && [ "${url}" != "null" ]; then
    echo "${url}"
    return 0
  fi

  return 1
}

ensure_planning_pr() {
  local url
  if url=$(find_open_pr_by_kind planning); then
    echo "${url}"
    return 0
  fi

  echo "[AI RUN] No open Planning PR found. Creating one via fallback..." 1>&2
  url=$(create_planning_pr)
  if [ -n "$url" ]; then
    echo "$url"
    return 0
  fi

  echo "[AI RUN] ERROR: Failed to create Planning PR via fallback." >&2
  exit 1
}

ensure_implementation_pr() {
  local url
  if url=$(find_open_pr_by_kind implementation); then
    echo "${url}"
    return 0
  fi

  echo "[AI RUN] No open Implementation PR found. Creating one via fallback..." 1>&2
  url=$(create_implementation_pr)
  if [ -n "$url" ]; then
    echo "$url"
    return 0
  fi

  echo "[AI RUN] ERROR: Failed to create Implementation PR via fallback." >&2
  exit 1
}

is_pr_merged() {
  local pr_url="$1"
  gh pr view "$pr_url" --json merged --jq '.merged' | grep -qi true && return 0 || return 1
}

review_cycle_until_merged() {
  local pr_url="$1"
  local kind="$2" # planning | implementation

  echo "[AI RUN] Starting review cycle for $kind PR: $pr_url"

  # Guard against excessive loops in case models disagree; cap to 20 cycles per PR.
  local max_cycles=20
  local i=1
  while [ "$i" -le "$max_cycles" ]; do
    echo "[AI RUN] Review cycle $i/$max_cycles for $kind"
    "${ROOT_DIR}/scripts/ai-review.sh" "$pr_url"

    if grep -q "❌ Request changes" /tmp/review.txt 2>/dev/null; then
      echo "[AI RUN] Reviewer requested changes. Asking GPT-5 to update the PR..."
      if [ "$kind" = "planning" ]; then
        "${ROOT_DIR}/scripts/ai-plan.sh" "$pr_url"
      else
        "${ROOT_DIR}/scripts/ai-implement.sh" "$pr_url"
      fi
    elif grep -q "✅ Approve" /tmp/review.txt 2>/dev/null; then
      echo "[AI RUN] Reviewer approved. Merging $kind PR..."
      local pr_number
      pr_number=$(gh pr view "$pr_url" --json number --jq '.number')
      # Approve (in case branch protection requires an approval), then merge
      gh pr review "$pr_number" --approve || true
      gh pr merge  "$pr_number" --squash --auto

      if is_pr_merged "$pr_url"; then
        echo "[AI RUN] $kind PR merged."
        break
      else
        echo "[AI RUN] Merge not yet completed. Waiting and re-checking..."
      fi
    else
      echo "[AI RUN] Reviewer response unclear; defaulting to request-changes loop."
      if [ "$kind" = "planning" ]; then
        "${ROOT_DIR}/scripts/ai-plan.sh" "$pr_url"
      else
        "${ROOT_DIR}/scripts/ai-implement.sh" "$pr_url"
      fi
    fi

    if is_pr_merged "$pr_url"; then
      echo "[AI RUN] $kind PR merged."
      break
    fi

    i=$((i+1))
    sleep 3
  done

  if ! is_pr_merged "$pr_url"; then
    echo "[AI RUN] WARNING: Exceeded max review cycles for $kind PR without merging." >&2
    exit 1
  fi
}

# --- Run ---
planning_url=$(ensure_planning_pr)
review_cycle_until_merged "$planning_url" planning

impl_url=$(ensure_implementation_pr)
review_cycle_until_merged "$impl_url" implementation

echo "[AI RUN] Completed Plan → Implement cycle."



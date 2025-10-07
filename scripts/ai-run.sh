#!/usr/bin/env bash
set -euo pipefail

# Orchestrates a single Plan → Review loop until merged, then Implement → Review until merged.
# Requires GH CLI and jq. Uses Cursor via scripts/ai-plan.sh, scripts/ai-implement.sh, scripts/ai-review.sh.

ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

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

  echo "[AI RUN] No open Planning PR found. Creating one..."
  "${ROOT_DIR}/scripts/ai-plan.sh"
  sleep 3
  if url=$(find_open_pr_by_kind planning); then
    echo "${url}"
    return 0
  fi

  echo "[AI RUN] ERROR: Failed to locate Planning PR after creation." >&2
  exit 1
}

ensure_implementation_pr() {
  local url
  if url=$(find_open_pr_by_kind implementation); then
    echo "${url}"
    return 0
  fi

  echo "[AI RUN] No open Implementation PR found. Creating one..."
  "${ROOT_DIR}/scripts/ai-implement.sh"
  sleep 3
  if url=$(find_open_pr_by_kind implementation); then
    echo "${url}"
    return 0
  fi

  echo "[AI RUN] ERROR: Failed to locate Implementation PR after creation." >&2
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



### Contributing to AI PR Loop (Cursor)

This repo uses Conventional Commits for all commits. Keep it simple: we do not use scopes.

## Conventional Commits

Use the form:

```
<type>: <subject>

[optional body]

[optional footer(s)]
```

Subject rules:

- Imperative mood, no trailing period, ≤ 72 characters
- UTF‑8 allowed; avoid emoji in the subject

Accepted types:

- `build` – build system or external dependencies (e.g., package.json, tooling)
- `chore` – maintenance (no app behavior change)
- `ci` – continuous integration configuration (workflows, pipelines)
- `docs` – documentation only
- `feat` – user-facing feature or capability
- `fix` – bug fix
- `perf` – performance improvements
- `refactor` – code change that neither fixes a bug nor adds a feature
- `revert` – revert of a previous commit
- `style` – formatting/whitespace (no code behavior)
- `test` – add/adjust tests only

Examples:

```text
feat: add daily cap inputs for AI loop
fix: correct gh search query for ai/* branches
docs: add CONTRIBUTING and update README usage
style: normalize YAML indentation in workflows
chore: update .gitignore for macOS artifacts
```

Breaking changes:

- Use `!` after the type or a `BREAKING CHANGE:` footer.

```text
feat!: rename workflow and change default schedule

BREAKING CHANGE: workflow file name and triggers changed; update any references.
```

## PR guidelines (repo-specific)

- Keep PRs small and focused (target ≤ ~200 changed lines).
- Include or update tests and documentation in the same PR when applicable.
- Do not commit secrets; follow repository `CODEOWNERS`, `LICENSE`, and security guidance.
- Prefer branch names like `ai/<short-task-slug>` to align with automation.
- Expect automated review via the "AI PR Review (Claude)" workflow; address any blockers it reports.
- If contributing manual changes, ensure all GitHub Actions pass before requesting human review.

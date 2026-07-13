---
description: git commit and push using scoped commits
model: opencode-go/deepseek-v4-flash
variant: high
subtask: true
---

commit and push using Scoped Commits (https://scopedcommits.com).

format: `<scope>: <description>` with optional body and trailers. keep the
description under 72 chars, imperative mood ("add" not "added").

scope = the subsystem, area, or module this commit touches. it is required and
goes first. derive it from the diff — the files and areas actually changed —
not from a fixed list. never use a conventional-commit type as the prefix (no
`feat`, `fix`, `chore`, `docs`, `refactor`, etc.); the description already
conveys the type.

multiple scopes: use a more general scope that covers them, list them
comma-separated, or use `treewide` / `all` / `global` if the whole tree is
touched. reverts, merges, and other special commits may be free-form.

ticket numbers (if any): put in parentheses after the scope, e.g.
`auth (PROJ-123): fix login`, or in a trailer.

prefer to explain WHY from an end-user perspective instead of WHAT was done.
be specific about user-facing changes — no generic messages like "improved
agent experience".

## staging

stage specific files, never `git add -A` or `git add .` blindly. if the diff
contains multiple unrelated logical changes, split into separate scoped
commits — one logical change per commit — instead of one mega-commit.

never commit secrets (.env, credentials, private keys, api tokens). if any
staged file looks like a secret, stop and notify me before proceeding.

## safety

- never update git config.
- never skip hooks (`--no-verify`) unless I explicitly ask.
- never force-push to main/master.
- if a commit fails due to hooks, fix the issue and create a NEW commit — do
  not amend the failed one.

## conflicts

if there are conflicts, fix them automatically by loading the
`resolving-merge-conflicts` skill and following its workflow. always notify me
of what was resolved, even on success — do not silently auto-resolve. only
escalate (stop and ask) if the conflicts cannot be resolved confidently.

## report

after commit and push, return a compact one-line report per commit:
`<short-sha> <scope>: <description> (<files-changed-count>)`. no verbose
narration.

$ARGUMENTS

## GIT DIFF

!`git diff`

## GIT DIFF --cached

!`git diff --cached`

## GIT STATUS --short

!`git status --short`
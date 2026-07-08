---
description: git commit and push using scoped commits
model: opencode-go/deepseek-v4-flash
subtask: true
---

commit and push using Scoped Commits (https://scopedcommits.com).

format: `<scope>: <description>` with optional body and trailers.

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

if there are conflicts DO NOT FIX THEM unless I explicitly ask. otherwise
notify me and I will fix them.

## GIT DIFF

!`git diff`

## GIT DIFF --cached

!`git diff --cached`

## GIT STATUS --short

!`git status --short`

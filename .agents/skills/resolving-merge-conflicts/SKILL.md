---
name: resolving-merge-conflicts
description: "Use when you need to resolve an in-progress git merge/rebase conflict."
---

1. **See the current state** of the merge/rebase. Check git history, and the conflicting files.

2. **Find the primary sources** for each conflict. Understand deeply why each change was made, and what the original intent was. Read the commit messages, check the PRs, check original issues/tickets.

3. **Resolve each hunk.** Preserve both intents where possible. Where incompatible, pick the one matching the merge's stated goal and note the trade-off. Do **not** invent new behaviour. Always resolve; never `--abort`.

4. Discover the project's **automated checks** and run them — typically typecheck, then tests, then format. Fix anything the merge broke.

5. **Finish the merge/rebase.** Stage everything and commit. If rebasing, continue the rebase process until all commits are rebased.

## Committing

The project's commit command lives at `/home/fomar/.config/opencode/command/commit.md` (an opencode command with `subtask: true`). It enforces commit-message conventions (Scoped Commits — scope derived from the diff, no conventional-commit types). Note its conflict-handling rule overrides the merge-resolver's: if the commit command itself hits conflicts, do **not** fix them — surface them to the user. This merge skill's "always resolve" rule applies only while a merge/rebase is already in progress at the time the skill is invoked.

---
name: handoff
description: Compact the current conversation into a handoff document so a fresh agent can continue the work. Use when ending a long session, handing off to another agent, saving context for later, or when asked to "handoff", "save state", or "write up what we did".
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Save a handoff document to the absolute path `/home/fomar/notes/handoff/`. Use this full path — other repos may invoke this skill, so do not use a relative path or the OS temp directory.

If the user passed arguments, treat them as a description of what the next session will focus on.

## Branch: resolved vs in-progress

If all work is complete and nothing needs continuation, prepend `RESOLVED <date>` to the title and skip the "Next session focus" section. The document becomes a historical record.

## Before saving, verify every yes

A handoff is **done** when you can answer yes to all of these:

- Can the next agent reproduce the current state without asking the user what happened?
- Is every necessary file path listed with its absolute path?
- Is every secret referenced by env var name or path only (never inline)?
- Are 1-3 verification commands included so the next agent can confirm the state hasn't changed on pickup?
- Is there a "Suggested skills" section with at least one skill and its full path?
- Are there no sections longer than 20 lines that duplicate content already in a referenced artifact?

## Footguns

Include a **Footguns** section: list things the next agent would get wrong on first attempt — wrong commands, missing env vars, stale assumptions — and the correct approach.

## Artifacts

Reference external artifacts (PRDs, plans, ADRs, issues, commits, diffs) by path or URL. Summarize only what the next agent needs to *continue* — not to replay the session.

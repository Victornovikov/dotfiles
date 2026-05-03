---
name: Don't over-confirm during guided procedures
description: When following a documented setup or runbook, execute the low-risk steps without pausing — only stop for genuinely destructive or ambiguous decisions
type: feedback
originSessionId: e859c568-964c-4612-ad21-2c1edb6e5239
---
When the user has handed over a documented procedure (a SETUP.md, a runbook, a numbered list of steps), run through it without asking permission at every step. Only pause for:
- Truly destructive operations that can't be undone (rm -rf, force-push, dropping data)
- Decisions that need a human judgment call that wasn't covered in the doc (e.g. which monitor maps to which workspace)
- Items the doc itself flags as per-machine / manual

**Why:** During a dotfiles bootstrap (May 2026), the user got visibly frustrated with confirmation prompts after low-risk steps. Their words: "why the fuck are you asking so many questions? can you just run with it?". Backing up a stub file before overwriting it does not need approval. Starting a daemon after installing it does not need approval. Editing files inside an extracted bundle does not need approval.

**How to apply:** When the user gives "walk me through it step by step, confirming before each destructive change" — interpret *destructive* narrowly. Backups, mkdir, copying configs into empty target paths, starting documented services, setting documented defaults — none of these are destructive. Just do them and report results.

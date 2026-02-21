# styrene-agent

Claude Code plugin providing skills, agents, commands, and statusline for styrene mesh network development.

## Tool Cache Divergence (Critical)

**The tool cache is not the filesystem.** After context compaction or session resumption, the Grep and Edit tools may operate on stale cached content from a previous session's uncommitted work. Bash subagents always read the real filesystem.

### Detection

If a Bash subagent returns different file content than Grep for the same path, **stop all edits immediately**. The subagent is correct. Do not attribute the discrepancy to caching, stale pyc, or subagent error — it means your indexed view of the codebase is wrong.

### Mandatory Verification

At the start of any session resumed from compaction or continued from a previous conversation:

1. Run `git status` and `git log --oneline -3` via Bash before making any edits
2. For every file you intend to edit, read it via Bash (`cat -n <file>`) and compare against what Grep returns
3. If they differ, trust the Bash output. Your Grep/Edit index is stale and every edit will silently fail

### Prevention

- Never end a session with significant uncommitted work. Commit to a WIP branch if context is running low.
- If the operator reports behavior inconsistent with your edits ("it's still doing X"), verify your edits landed: `git diff` via Bash, not by re-reading with Grep.

# Skills Development Guide

Conventions for creating Claude Code skills and tools for styrene-lab.

## Skill vs Tool Decision

**Use a Skill when:**
- Behavior guidance (how to approach problems)
- Workflow patterns (fleet operations, session tracking)
- Judgment-heavy operations (mesh troubleshooting, deployment decisions)

**Use a Tool when:**
- Deterministic transformation (input -> output)
- No interpretation required
- Pure function with predictable results
- Already implemented as executable script

## Tool Implementation: Bash Allow-List Pattern

**Preferred over MCP servers.** MCP adds 1-5k+ tokens per server to context before any work begins.

### Pattern

```json
// settings.local.json
{
  "permissions": {
    "allow": [
      "Bash(~/.claude/skills/<skill>/script.sh)",
      "Bash(~/.claude/skills/<skill>/script.sh:*)",
      "Bash(python3 ~/.claude/skills/<skill>/cli.py:*)"
    ]
  }
}
```

## Skill Structure

```
skills/<name>/
├── SKILL.md          # Required: frontmatter + documentation
├── script.sh         # Optional: Bash implementation
├── cli.py            # Optional: Python implementation
└── ...               # Supporting files
```

### SKILL.md Frontmatter

```yaml
---
name: skill-name
description: One-line description for skill discovery. Include invocation hints.
---
```

## Current Inventory

### Universal (ported from coe-agent)

| Skill | Type | Purpose |
|-------|------|---------|
| date-context | Tool-ready | Authoritative date from system clock |
| distill | Pure guidance | Session context distillation for handoff |
| python | Pure guidance | Python dev conventions: project setup, pytest, ruff, mypy, packaging, CI/CD |
| rust | Pure guidance | Rust dev conventions: Cargo, clippy, rustfmt, testing, Zellij WASM plugins |
| visualizer | Hybrid | Mermaid diagram management |
| cleave | Hybrid | Recursive task decomposition |

### Styrene-Specific

| Skill | Type | Purpose |
|-------|------|---------|
| bare-metal-ops | Pure guidance | SSH fleet operations, device registry, remote deployment |
| rns-operations | Pure guidance | Reticulum/LXMF config, mesh diagnostics, wire protocol |
| styrene-topology | Pure guidance | System architecture, component map, device fleet |
| session-log | Pure guidance | Append-only session tracking for memory continuity |

## Anti-Patterns

- **Don't use MCP for simple wrappers.** Context cost exceeds benefit for deterministic scripts.
- **Don't create skills for one-off tasks.** If it's not reusable across sessions, it's not a skill.
- **Don't duplicate what Bash does natively.** `ls`, `cat`, `grep` don't need skill wrappers.
- **Don't put execution logic in SKILL.md.** The skill file is documentation and behavioral guidance.

## Context Cost Awareness

| Component | Token Cost |
|-----------|------------|
| Skill invocation | ~size of SKILL.md |
| MCP server | ~1-5k per server (loaded at session start) |
| Bash allow-list | ~0 (no schema overhead) |
| Built-in tools | ~10-11k (always loaded) |

Keep SKILL.md concise. Move detailed docs to separate files if > 200 lines.

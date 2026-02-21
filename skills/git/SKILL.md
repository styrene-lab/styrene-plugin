---
name: git
description: Git conventions for styrene-lab. Conventional commits, semantic versioning, branch naming, tagging, changelogs, and release workflow. Use when committing, branching, tagging, or managing releases. Separate from GitHub operations (PRs, issues, Actions).
---

# Git Skill

Conventions for git operations across styrene-lab. Covers commit messages, versioning, branching, tagging, and changelogs.

For GitHub-specific operations (PRs, issues, Actions), see the github skill if available.

## Conventional Commits

All styrene-lab repos use [Conventional Commits](https://www.conventionalcommits.org/). Enforced in CI for cleave; followed by convention elsewhere.

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | When | Semver Impact |
|------|------|---------------|
| `feat` | New feature or capability | MINOR bump |
| `fix` | Bug fix | PATCH bump |
| `docs` | Documentation only | none |
| `style` | Formatting, whitespace (no logic change) | none |
| `refactor` | Code change that neither fixes nor adds | none |
| `perf` | Performance improvement | none |
| `test` | Adding or correcting tests | none |
| `chore` | Build process, deps, tooling, version bumps | none |
| `ci` | CI/CD configuration changes | none |
| `revert` | Reverts a previous commit | varies |

### Scope (optional)

Parenthetical hint narrowing what changed. Free-form but consistent within a repo:

```
feat(chat): add message history pagination
fix(rns): handle LocalInterface reconnection
test(ipc): add handler validation tests
chore(deps): bump serde to 1.0.200
fix(cli): add missing cmd_analytics function
```

### Breaking Changes

Mark with `!` after the type/scope, and explain in the footer:

```
feat(wire)!: change StyreneEnvelope to v3 format

BREAKING CHANGE: Wire protocol v2 messages are no longer accepted.
Nodes must upgrade to styrened >= 0.5.0.
```

### Commit Message Quality

**Good** — explains the *why*, not just the *what*:
```
fix: normalize truncated destination hashes in chat messages

Short hashes from Sideband clients caused lookup failures in NodeStore.
Now pads to full length before resolution.
```

**Bad** — restates the diff:
```
fix: change hash lookup code
```

### Validation Regex

Used in CI (from cleave's workflow):
```
^(feat|fix|docs|style|refactor|perf|test|chore|ci|revert)(\(.+\))?(!)?: .+
```

## Semantic Versioning

All repos follow [SemVer 2.0.0](https://semver.org/):

```
vMAJOR.MINOR.PATCH
```

| Component | Increment When |
|-----------|---------------|
| **MAJOR** | Breaking API/protocol change |
| **MINOR** | New feature, backward-compatible |
| **PATCH** | Bug fix, backward-compatible |

### Pre-1.0 Convention

During `0.x.y` development (most styrene-lab repos):
- MINOR bumps may include breaking changes
- PATCH bumps are bug fixes
- API stability is not guaranteed until `1.0.0`

### Version Locations

| Repo | Source of Truth |
|------|----------------|
| styrened | `src/styrened/__init__.py` (`__version__`), synced to `pyproject.toml` |
| cleave | `pyproject.toml` `[project] version` |
| styrene-agent | `.claude-plugin/plugin.json` + `marketplace.json` |
| Rust crates | `Cargo.toml` `[package] version` |

### Version Bump Commits

Use `chore` type:
```
chore: bump version to 0.4.0
```

## Branch Naming

Enforced in CI for cleave; followed by convention elsewhere:

```
<type>/<short-description>
```

| Type | Purpose |
|------|---------|
| `feature/` | New functionality |
| `fix/` | Bug fix |
| `patch/` | Small targeted fix |
| `chore/` | Tooling, deps, config |
| `refactor/` | Code restructuring |
| `perf/` | Performance work |
| `breaking/` | Known breaking change |
| `hotfix/` | Urgent production fix |

**Examples:**
```
feature/lxmf-chat-backend
fix/local-interface-reconnection
chore/bump-dependencies
refactor/split-discovery-api
```

**Main branch**: `main` (all repos). Tags and releases are cut from main only.

## Tagging

### Convention

```bash
git tag v0.4.0
git push origin v0.4.0
```

- Always prefix with `v`: `v0.4.0`, not `0.4.0`
- Tags must be on the `main` branch (validated in CI)
- Format must match `vMAJOR.MINOR.PATCH` exactly (no pre-release suffixes in current practice)
- Tag triggers release CI (build, publish, GitHub Release)

### Release Flow

```
1. Complete work on feature/fix branch
2. Merge to main via PR
3. Update version in source files
4. Commit: chore: bump version to X.Y.Z
5. Update CHANGELOG.md
6. Tag: git tag vX.Y.Z
7. Push: git push origin main --tags
8. CI validates tag is on main → builds → publishes
```

## Changelog

Repos with published releases maintain `CHANGELOG.md` using [Keep a Changelog](https://keepachangelog.com/) format.

### Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-02-03

### Added
- ConversationService for LXMF chat backend

### Changed
- Identity verification moved to async with retries

### Fixed
- LocalInterface reconnection duplicate destinations

### Security
- Terminal session authorization and rate limiting

### Removed
- Deprecated v1 wire protocol support
```

### Section Order

`Added` → `Changed` → `Deprecated` → `Removed` → `Fixed` → `Security`

Only include sections that have entries. `[Unreleased]` collects changes since the last tag.

## Quick Reference

```bash
# Feature branch
git checkout -b feature/my-feature main
git commit -m "feat(scope): add new capability"
git push -u origin feature/my-feature

# Fix branch
git checkout -b fix/the-bug main
git commit -m "fix: resolve crash on empty input"

# Release (from main)
git checkout main && git pull
# bump version, update CHANGELOG
git commit -m "chore: bump version to 0.5.0"
git tag v0.5.0
git push origin main --tags
```

See `_reference/ci-validation.md` for CI workflow templates that enforce these conventions.

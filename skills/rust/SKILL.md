---
name: rust
description: Rust development guidance including Zellij WASM plugin development. Covers project setup (Cargo.toml), testing, clippy, rustfmt, CI/CD patterns, and the zellij-tile plugin API. Use when creating, modifying, or debugging Rust code or Zellij plugins.
---

# Rust Development Skill

Conventions for Rust development in styrene-lab, with a dedicated section for Zellij WASM plugin development.

Detailed templates and examples are in `skills/rust/_reference/`.

## Core Conventions

- **Rust stable** toolchain (`rustup default stable`)
- **Cargo** for build, test, lint, format — no external build tools needed
- **clippy** for linting, **rustfmt** for formatting
- **Edition 2021** minimum
- Workspace layout for multi-crate projects, single `Cargo.toml` otherwise

## Project Scaffold

```
<project>/
├── Cargo.toml              # Package metadata, deps, lint config
├── rustfmt.toml            # max_width = 100
├── src/
│   ├── lib.rs              # Library root (or main.rs for binary)
│   └── ...
├── tests/
│   └── integration_test.rs
└── .github/workflows/ci.yml
```

See `_reference/templates.md` for full Cargo.toml templates (library, binary, WASM, workspace).

## Tooling Quick Reference

### Clippy (Linting)

```bash
cargo clippy                        # Lint
cargo clippy -- -D warnings         # Warnings as errors (CI)
cargo clippy --all-targets           # Include tests/benches
cargo clippy --fix                   # Auto-fix
```

Project config in `Cargo.toml`:
```toml
[lints.clippy]
pedantic = { level = "warn", priority = -1 }
unwrap_used = "warn"
```

### Rustfmt (Formatting)

```bash
cargo fmt                           # Format
cargo fmt -- --check                # Check only (CI)
```

### Build & Test

```bash
cargo build                         # Debug build
cargo build --release               # Release build
cargo test                          # All tests
cargo test -- --nocapture            # Show println output
cargo test test_name                 # Specific test
cargo test --lib                     # Unit tests only
cargo test --test integration_test   # Specific integration test
```

### Other Useful Commands

```bash
cargo doc --open                    # Generate and browse docs
cargo audit                         # Security vulnerability check
cargo tree                          # Dependency tree
cargo expand                        # Macro expansion
```

## Testing Patterns

### Unit Tests (in-module)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_valid() {
        let result = parse("input");
        assert_eq!(result, expected);
    }
}
```

### Integration Tests

```rust
// tests/integration_test.rs — accesses only public API
use crate_name::public_api;

#[test]
fn test_end_to_end() {
    let result = public_api("input");
    assert!(result.is_ok());
}
```

### Async Tests (tokio)

```rust
#[tokio::test]
async fn test_async_op() {
    let result = fetch_data().await;
    assert!(result.is_ok());
}
```

## Error Handling

| Context | Pattern |
|---------|---------|
| Libraries | `thiserror::Error` derive for custom error types |
| Applications | `anyhow::Result` for ergonomic error propagation |
| Unwrap | Never in library code; `expect("reason")` in main/tests only |

## Common Dependencies

| Crate | Purpose |
|-------|---------|
| `serde` + `serde_json` | Serialization |
| `tokio` | Async runtime |
| `anyhow` / `thiserror` | Error handling |
| `clap` | CLI parsing |
| `tracing` | Structured logging |

## CI/CD

```yaml
name: CI
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo fmt -- --check
      - run: cargo clippy -- -D warnings
      - run: cargo test
```

See `_reference/templates.md` for release and cross-compilation workflows.

---

## Zellij WASM Plugin Development

Zellij plugins are Rust crates compiled to `wasm32-wasip1`, loaded by the Zellij multiplexer. The `zellij-tile` crate provides the plugin API.

### Setup

```bash
rustup target add wasm32-wasip1
cargo build --release --target wasm32-wasip1
# Output: target/wasm32-wasip1/release/<name>.wasm
```

### Plugin Cargo.toml

```toml
[package]
name = "styrene-status"
version = "0.1.0"
edition = "2021"

[dependencies]
zellij-tile = "0.41"        # Match your Zellij version
serde = { version = "1", features = ["derive"] }
serde_json = "1"

[profile.release]
opt-level = "s"             # Optimize for WASM size
lto = true
strip = true
```

### Plugin Lifecycle

```rust
use zellij_tile::prelude::*;

#[derive(Default)]
struct MyPlugin { /* state */ }

impl ZellijPlugin for MyPlugin {
    fn load(&mut self, config: BTreeMap<String, String>) {
        // Subscribe to events, request permissions, set timers
        subscribe(&[EventType::Timer, EventType::Key]);
        request_permission(&[PermissionType::ReadApplicationState]);
        set_timeout(10.0);
    }

    fn update(&mut self, event: Event) -> bool {
        // Handle events. Return true to re-render.
        match event {
            Event::Timer(_) => { set_timeout(10.0); true }
            _ => false,
        }
    }

    fn render(&mut self, rows: usize, cols: usize) {
        // Use print!()/println!() for output to plugin pane
        print!("status: ok");
    }

    fn pipe(&mut self, pipe_message: PipeMessage) -> bool {
        // Handle `zellij pipe` messages from CLI/scripts
        false
    }
}

register_plugin!(MyPlugin);
```

### Permissions

Request in `load()`, user grants interactively:

| Permission | Allows |
|-----------|--------|
| `ReadApplicationState` | Query panes, tabs, session info |
| `ChangeApplicationState` | Create/close panes/tabs, switch focus |
| `RunCommands` | Execute commands in panes |
| `OpenFiles` | Open files in editor panes |
| `WriteToStdin` | Write to pane stdin |
| `ReadCliPipes` | Receive `zellij pipe` messages |

### External Communication

CLI scripts push data to running plugins via pipes:

```bash
echo '{"status":"ok"}' | zellij pipe --plugin "file:plugin.wasm" --name "update"
```

Plugin handles in `fn pipe()`. This is the primary pattern for bridging styrened
events into WASM plugins (since WASM can't open sockets directly).

### Workers (Async Tasks)

Offload blocking work to avoid stalling render:

```rust
struct FetchWorker;
impl ZellijWorker for FetchWorker {
    fn on_message(&mut self, message: String, payload: String) {
        let data = std::fs::read_to_string("/host/path").unwrap_or_default();
        post_message_to_plugin(message, data);  // → Event::CustomMessage
    }
}
register_worker!(FetchWorker, fetch_worker, FETCH_WORKER);
```

### Loading in KDL Layouts

```kdl
pane size=1 borderless=true {
    plugin location="file:/path/to/plugin.wasm"
}
```

### WASM Constraints

| Limitation | Workaround |
|-----------|------------|
| No sockets | `zellij pipe` bridge from external script |
| No threads | `ZellijWorker` for background work |
| Limited filesystem | Host fs via `/host/` prefix |
| No system clock | `set_timeout()` for time-based logic |
| Binary size | `opt-level = "s"`, LTO, strip |

See `_reference/zellij-patterns.md` for the full StyreneStatusPlugin example,
the two-layer event architecture, KDL layouts, and the bridge script pattern.

## Debugging

```bash
# Rust
cargo test -- --nocapture           # Show test output
RUST_BACKTRACE=1 cargo test         # Full backtraces
RUST_LOG=debug cargo run            # With tracing/env_logger

# WASM plugins — logs go to Zellij log file
tail -f /tmp/zellij-*/zellij-log/zellij.log
# Use eprintln!() in plugin code for debug output
```

## Common Gotchas

| Issue | Fix |
|-------|-----|
| `wasm32-wasip1` not found | `rustup target add wasm32-wasip1` |
| Plugin won't load | Check Zellij version matches `zellij-tile` crate version |
| Clippy too noisy | Tune via `[lints.clippy]` in Cargo.toml |
| WASM binary too large | `opt-level = "s"`, `lto = true`, `strip = true` |
| Can't open sockets in WASM | Use file reads or `zellij pipe` bridge pattern |
| Plugin doesn't re-render | Return `true` from `update()` or `pipe()` |
| `cargo test` hangs | Deadlock in async code — add timeouts |

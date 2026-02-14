# Zellij WASM Plugin Patterns

Detailed examples and reference for Zellij plugin development in the styrene ecosystem.

## StyreneStatusPlugin — Full Example

The reference implementation for a styrene mesh status bar plugin:

```rust
use zellij_tile::prelude::*;
use std::collections::BTreeMap;

#[derive(Default)]
struct StyreneStatusPlugin {
    status: Option<DeviceStatus>,
}

#[derive(serde::Deserialize)]
struct DeviceStatus {
    name: String,
    hash: String,
    rns: String,
    lxmf_queue: u32,
    uptime: u64,
}

impl ZellijPlugin for StyreneStatusPlugin {
    fn load(&mut self, _config: BTreeMap<String, String>) {
        set_timeout(10.0); // refresh every 10s
        request_permission(&[
            PermissionType::ReadApplicationState,
        ]);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::Timer(_) => {
                // Read status file from host filesystem
                if let Ok(data) = std::fs::read_to_string("/host/run/styrened/status.json") {
                    self.status = serde_json::from_str(&data).ok();
                }
                set_timeout(10.0);
                true // re-render
            }
            _ => false,
        }
    }

    fn render(&mut self, _rows: usize, _cols: usize) {
        match &self.status {
            Some(s) => {
                let mesh = if s.rns == "connected" { "✓" } else { "✗" };
                print!(
                    " styrene: {} [{}] MESH:{} Q:{}",
                    s.name,
                    &s.hash[..4.min(s.hash.len())],
                    mesh,
                    s.lxmf_queue
                );
            }
            None => print!(" styrene: LOADING..."),
        }
    }

    fn pipe(&mut self, pipe_message: PipeMessage) -> bool {
        match pipe_message.name.as_deref() {
            Some("mesh_status") => {
                if let Some(payload) = pipe_message.payload {
                    self.status = serde_json::from_str(&payload).ok();
                    return true;
                }
            }
            Some("notification") => {
                // Handle notifications from bridge script
                return true;
            }
            _ => {}
        }
        false
    }
}

register_plugin!(StyreneStatusPlugin);
```

## Event Bridge Pattern

External scripts push real-time events to the WASM plugin via `zellij pipe`:

```bash
#!/usr/bin/env bash
# zellij-bridge.sh — watches styrened events, forwards to WASM plugin

STATUS_FILE="/run/styrened/status.json"
PLUGIN="file:/run/current-system/sw/share/zellij/plugins/styrene-status.wasm"

inotifywait -m -e modify "$STATUS_FILE" | while read -r; do
    cat "$STATUS_FILE" | zellij pipe \
        --plugin "$PLUGIN" \
        --name "mesh_status"
done
```

This bridges the gap: WASM plugins can't open sockets, but they can receive
piped data from external processes.

## Two-Layer Event Architecture

```
Layer 0: Ground Truth (styrened writes files)
├── /run/styrened/control.sock   (Unix stream socket — CLI/TUI)
├── /run/styrened/status.json    (atomic write, full state snapshot)
├── /run/styrened/events.jsonl   (append-only event log)
└── journald structured logs

Layer 1: Zellij Plugins (consume events, render UI)
├── styrene-status.wasm          (reads status.json on timer + pipe messages)
└── zellij-bridge.sh             (systemd user service, watches files, calls zellij pipe)
```

**Why two layers?**
- WASM sandbox prevents direct socket access
- File-based status.json is the universal fallback (works without Zellij)
- `zellij pipe` provides real-time push without polling
- Bridge script is a thin adapter, not a daemon

## KDL Layout Integration

### Status Bar Plugin

Replace the default status bar:

```kdl
layout {
    pane size=1 borderless=true {
        plugin location="file:/path/to/styrene-status.wasm"
    }
    pane
    pane size=1 borderless=true {
        plugin location="zellij:status-bar"
    }
}
```

### Full Styrene Device Layout

```kdl
layout {
    // Styrene status bar (top)
    pane size=1 borderless=true {
        plugin location="file:styrene-status.wasm"
    }

    // Main content area
    pane split_direction="vertical" {
        // styrene-tui dashboard
        pane size="60%" {
            command "styrene-tui"
            args "dashboard"
        }
        // General terminal
        pane size="40%"
    }

    // Default Zellij status bar (bottom)
    pane size=1 borderless=true {
        plugin location="zellij:status-bar"
    }
}
```

## Plugin Events Reference

### Most Useful Events for Styrene Plugins

| Event | Use Case |
|-------|----------|
| `Timer` | Periodic status refresh (poll status.json) |
| `Key` | Interactive plugins (user presses key while focused) |
| `PipeMessage` | Real-time data from zellij-bridge.sh or CLI |
| `CustomMessage` | Worker thread results |
| `Visible` | Pause/resume polling when tab switches |
| `TabUpdate` | React to tab changes |
| `PaneUpdate` | React to pane changes |
| `BeforeClose` | Cleanup before plugin unload |

### Subscribing to Events

```rust
fn load(&mut self, _config: BTreeMap<String, String>) {
    subscribe(&[
        EventType::Timer,
        EventType::Key,
        EventType::Visible,
    ]);
    set_timeout(10.0);
}
```

### Handling Multiple Events

```rust
fn update(&mut self, event: Event) -> bool {
    match event {
        Event::Timer(_) => {
            self.refresh_status();
            set_timeout(10.0);
            true
        }
        Event::Key(Key::Char('r')) => {
            self.refresh_status();
            true
        }
        Event::Visible(visible) => {
            self.is_visible = visible;
            if visible {
                self.refresh_status();
                set_timeout(10.0);
            }
            true
        }
        _ => false,
    }
}
```

## Worker Pattern — Background Data Fetch

```rust
use zellij_tile::prelude::*;

// Worker definition
struct StatusWorker;

impl ZellijWorker for StatusWorker {
    fn on_message(&mut self, message: String, payload: String) {
        match message.as_str() {
            "fetch_status" => {
                // Heavy I/O here won't block the render loop
                let data = std::fs::read_to_string("/host/run/styrened/status.json")
                    .unwrap_or_default();
                post_message_to_plugin("status_result".into(), data);
            }
            _ => {}
        }
    }
}

register_worker!(StatusWorker, status_worker, STATUS_WORKER);

// In plugin update(), handle worker results:
Event::CustomMessage(name, payload) if name == "status_result" => {
    self.status = serde_json::from_str(&payload).ok();
    true
}
```

## WASM-Specific Constraints

| Limitation | Workaround |
|-----------|------------|
| No network sockets | Use `zellij pipe` bridge from external script |
| No threads | Use `ZellijWorker` for async work |
| Limited filesystem | Access host fs via `/host/` prefix |
| No system clock | Use `set_timeout` for time-based logic |
| Binary size matters | `opt-level = "s"`, LTO, strip |
| No `println!` to terminal | Use `print!()` in `render()`, `eprintln!()` for logs |

## Debugging WASM Plugins

```bash
# Plugin logs go to Zellij's log file
tail -f /tmp/zellij-*/zellij-log/zellij.log

# Use eprintln! in plugin code for debug output
eprintln!("DEBUG: status = {:?}", self.status);

# Quick iteration: rebuild and reload
cargo build --release --target wasm32-wasip1 && \
    cp target/wasm32-wasip1/release/plugin.wasm ~/.config/zellij/plugins/

# Reload plugin without restarting Zellij (from within Zellij)
# Use the plugin manager or reload keybinding
```

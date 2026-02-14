# Rust Project Templates

Copy-paste templates for new Rust projects.

## Cargo.toml — Library

```toml
[package]
name = "crate-name"
version = "0.1.0"
edition = "2021"
rust-version = "1.75"
description = "One-line description"
license = "MIT"
repository = "https://github.com/styrene-lab/crate-name"

[dependencies]
serde = { version = "1", features = ["derive"] }

[dev-dependencies]
pretty_assertions = "1"

[lints.clippy]
pedantic = { level = "warn", priority = -1 }
unwrap_used = "warn"
```

## Cargo.toml — Binary / Application

```toml
[package]
name = "app-name"
version = "0.1.0"
edition = "2021"
rust-version = "1.75"
description = "One-line description"
license = "MIT"

[dependencies]
anyhow = "1"
clap = { version = "4", features = ["derive"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

[dev-dependencies]
pretty_assertions = "1"

[lints.clippy]
pedantic = { level = "warn", priority = -1 }
unwrap_used = "warn"

[profile.release]
lto = true
strip = true
```

## Cargo.toml — Zellij WASM Plugin

```toml
[package]
name = "styrene-status"
version = "0.1.0"
edition = "2021"

[dependencies]
zellij-tile = "0.41"
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# No tokio, no networking crates — WASI sandbox limits apply

[profile.release]
opt-level = "s"
lto = true
strip = true
codegen-units = 1
```

## Cargo.toml — Workspace

```toml
[workspace]
members = [
    "crates/core",
    "crates/cli",
]
resolver = "2"

[workspace.package]
version = "0.1.0"
edition = "2021"
license = "MIT"

[workspace.dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
anyhow = "1"

[workspace.lints.clippy]
pedantic = { level = "warn", priority = -1 }
```

Member crate references workspace deps:
```toml
# crates/core/Cargo.toml
[package]
name = "project-core"
version.workspace = true
edition.workspace = true

[dependencies]
serde.workspace = true

[lints]
workspace = true
```

## rustfmt.toml

```toml
edition = "2021"
max_width = 100
use_field_init_shorthand = true
```

## Makefile (Optional)

Cargo is self-sufficient, but a Makefile provides discoverability:

```makefile
.PHONY: build test lint fmt check clean

build:
	cargo build

test:
	cargo test

lint:
	cargo clippy -- -D warnings

fmt:
	cargo fmt

check: fmt lint test

clean:
	cargo clean

# WASM plugin targets
.PHONY: wasm wasm-install

wasm:
	cargo build --release --target wasm32-wasip1

wasm-install: wasm
	cp target/wasm32-wasip1/release/*.wasm ~/.config/zellij/plugins/
```

## CI Workflow — Library

```yaml
name: CI
on: [push, pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy
      - uses: Swatinem/rust-cache@v2
      - run: cargo fmt -- --check
      - run: cargo clippy --all-targets -- -D warnings
      - run: cargo test
```

## CI Workflow — Release

```yaml
name: Release
on:
  push:
    tags: ["v*"]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo test

  build:
    needs: test
    strategy:
      matrix:
        include:
          - target: x86_64-unknown-linux-gnu
            os: ubuntu-latest
          - target: aarch64-unknown-linux-gnu
            os: ubuntu-latest
          - target: x86_64-apple-darwin
            os: macos-latest
          - target: aarch64-apple-darwin
            os: macos-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: ${{ matrix.target }}
      - run: cargo build --release --target ${{ matrix.target }}
      - uses: actions/upload-artifact@v4
        with:
          name: binary-${{ matrix.target }}
          path: target/${{ matrix.target }}/release/<binary-name>

  github-release:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v4
      - uses: softprops/action-gh-release@v2
        with:
          files: binary-*/*
          generate_release_notes: true
```

## CI Workflow — WASM Plugin

```yaml
name: Build Plugin
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: wasm32-wasip1
      - uses: Swatinem/rust-cache@v2
      - run: cargo clippy --target wasm32-wasip1 -- -D warnings
      - run: cargo build --release --target wasm32-wasip1
      - uses: actions/upload-artifact@v4
        with:
          name: plugin
          path: target/wasm32-wasip1/release/*.wasm
```

## Error Handling Templates

### Library Error Type (thiserror)

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("config not found: {path}")]
    ConfigNotFound { path: String },

    #[error("parse error: {0}")]
    Parse(#[from] serde_json::Error),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}
```

### Application Entry Point (anyhow)

```rust
use anyhow::{Context, Result};
use clap::Parser;

#[derive(Parser)]
struct Cli {
    #[arg(short, long)]
    config: Option<String>,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let config = load_config(cli.config.as_deref())
        .context("failed to load configuration")?;
    run(config)?;
    Ok(())
}
```

### Logging Setup (tracing)

```rust
use tracing_subscriber::EnvFilter;

fn init_logging() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();
}
```

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`envtpl` is a Crystal port of the Python `envtpl`: it renders [Crinja](https://github.com/straight-shoota/crinja) (Jinja2-like) templates using environment variables, reading from STDIN/`--in` and writing to STDOUT/`--out`. The whole implementation lives in `src/envtpl.cr`.

## Commands

The toolchain is pinned by `mise.toml` (Crystal + crystalline). Everything goes through `mise` tasks — CI calls the same tasks, so a local `mise dev:*` run is what the pipeline runs.

```sh
mise dev:deps          # shards install
mise dev:build         # dev binary -> bin/envtpl (override target with OUTPUT_FILE=...)
mise dev:spec          # full spec suite
mise dev:spec-mt       # same suite with -Dpreview_mt, CRYSTAL_WORKERS=4
mise dev:ameba         # static analysis (wrapped in `timeout 180`)
mise dev:format        # crystal tool format
mise dev:format-check  # crystal tool format --check (what CI runs)
mise dev:docs          # regenerate docs/
mise dev:clean         # rm -rf bin/* lib/
mise dev:docker-image  # local multi-arch dev image via docker buildx bake
```

Run a subset of specs by example name (Spectator honours the standard spec CLI flags):

```sh
crystal spec -e "can be piped to other functions"
crystal spec spec/envtpl_spec.cr
```

On macOS, `shards` may be missing from the Crystal install; `mise dev:fix-shards-command` copies it into place (workaround for crystal-lang/crystal#16746, also used in CI).

## Release pipeline

Two distinct build paths — do not conflate them:

- `mise release:build` — local release binary (`--release --error-trace`), then writes `.sha256` files next to the binaries in `bin/`.
- `mise release:static` — static musl binaries for linux/amd64 + linux/arm64. This does **not** use `mise.toml` tasks internally: `docker-bake.hcl` drives the multi-stage `Dockerfile`, which copies `Makefile.release` in as `Makefile` and runs `make release` inside Alpine. Output lands in `packages/`, then the task flattens the per-platform dirs and regenerates checksums. `Makefile.release` is therefore the authoritative compile options for released binaries — keep it in sync with `release:build` when changing flags.

The `docker-image` bake target produces a distroless image with `envtpl` as entrypoint, running as `nonroot`.

## Architecture notes

**Single file, dual role.** `src/envtpl.cr` is both the library (module `Envtpl`) and the CLI entrypoint. The CLI block at the bottom is guarded by `unless Crystal.env.test?`, so requiring the file from a spec does not parse ARGV or touch STDIN. `spec_helper.cr` requires `crystal-env/spec` to force the test environment — any new spec file must go through `spec_helper.cr`, otherwise requiring `src/envtpl` will start the CLI.

**Compile-time version stamping.** `VERSION` and `GIT_REF` are macro-expanded by running `shards version` and `git log` at compile time. Consequences: a build needs both `shards` on PATH and a real `.git/` directory — which is why the `Dockerfile` copies `.git/` into the build stage. Bumping the version means editing `shard.yml`; nothing reads a hardcoded string.

**Crinja extensions.** Two registrations happen at load time, before the module:

- `env()` function — no args returns the whole environment as a hash; one arg returns that variable (empty string if absent, or the `default=` kwarg); several args return a hash filtered to those keys, silently skipping missing ones.
- `json` filter — serialises a value with `Crinja::JsonBuilder`, `indent=2` by default.

Bare `{{ FOO }}` resolution works because `Envtpl.transform` passes `ENV` directly as the Crinja render context; `env()` reads `ENV` independently. Both behaviours are covered by specs and are part of the public contract.

**Error handling.** `parse_args!` exits with a usage message (status 0) when STDIN is a TTY and no `--in` was given; invalid options and unreadable input files exit 1. Rendering errors bubble up to the top-level `rescue` which prints `e.message` to STDERR and exits 1.

## Testing

Specs use [Spectator](https://gitlab.com/arctic-fox/spectator), not the stdlib spec DSL (`Spectator.describe`, `expect(...).to eq`). Environment mutation goes through the `with_env` helper in `spec/spec_helper.cr`, which restores previous values in an `ensure` block — never set `ENV` directly in a spec.

## CI

`.github/workflows/ci.yml` is a verbatim copy of the canonical Crystal CI template (`~/.claude/references/crystal-ci.yml`) — change the template first, then propagate. It runs format-check, ameba, docs, and the spec suite (single- and multi-threaded) on linux amd64/arm64, macOS arm64/intel, plus a `continue-on-error` nightly-compiler job. `MISE_DISABLE_TOOLS` skips crystalline, whose macOS binary would fail its post-install check on the runners.

`.github/workflows/release_binaries.yml` fires on any tag push: linux binaries come from `mise release:static` (QEMU + buildx), macOS arm64/intel from `mise release:build` with `OUTPUT_FILE` overridden to `bin/envtpl-darwin-<arch>`; all assets are published to the GitHub release via `ncipollo/release-action`. The `OUTPUT_FILE` env var override is the reason `mise.toml` computes that variable through a Crinja `get_env` expression.

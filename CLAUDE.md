# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`envtpl` is a Crystal port of the Python `envtpl`: it renders [Crinja](https://github.com/straight-shoota/crinja) (Jinja2-like) templates using environment variables, reading from STDIN/`--in` and writing to STDOUT/`--out`. The library lives in `src/envtpl.cr`; `src/cli.cr` is the CLI entrypoint and the only compilation target.

## Commands

The toolchain is pinned by `mise.toml` (Crystal + crystalline). Everything goes through `mise` tasks — CI calls the same tasks, so a local `mise dev:*` run is what the pipeline runs.

```sh
mise dev:deps          # shards install
mise dev:build         # dev binary -> bin/envtpl (override target with OUTPUT_FILE=...)
mise dev:spec          # full spec suite
mise dev:spec-mt       # same suite with -Dpreview_mt, CRYSTAL_WORKERS=4
mise dev:ameba         # static analysis (bounded by the task timeout, 180s)
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

- `mise release:build` — local release binary (`--release --error-trace`), then writes the `.sha256` next to it. It checksums only the binary it just built: the previous `cd bin; for f in *` also hashed the `.sha256` of the previous run (`envtpl.sha256.sha256`, one level deeper each time) and any other binary in `bin/`.
- `mise release:static` — static musl binaries for linux/amd64 + linux/arm64. This does **not** use `mise.toml` tasks internally: `docker-bake.hcl` drives the multi-stage `Dockerfile`, which copies `Makefile.release` in as `Makefile` and runs `make release` inside Alpine. Output lands in `packages/`, then the task flattens the per-platform dirs and regenerates checksums. `Makefile.release` is therefore the authoritative compile options for released binaries — keep it in sync with `release:build` when changing flags.

The `docker-image` bake target produces a distroless image with `envtpl` as entrypoint, running as `nonroot`.

## Architecture notes

**Library and entrypoint are separate files.** `src/envtpl.cr` is the library (module `Envtpl`) and contains no top-level statement that runs anything; `src/cli.cr` is the only place that parses ARGV, touches STDIN and calls `exit`. Requiring the library from a spec therefore starts nothing, and no runtime guard is needed.

This split is not cosmetic. The CLI used to live at the bottom of `src/envtpl.cr` behind `unless Crystal.env.test?`, and `crystal-env` reads `CRYSTAL_ENV` **at runtime**: any user whose environment happened to carry `CRYSTAL_ENV=test` got a binary that rendered nothing and exited 0 — in a `envtpl < tpl > out` pipeline, `out` was truncated to zero bytes, silently. `spec/cli_spec.cr` guards against a regression by rendering under several `CRYSTAL_ENV` values. Do not reintroduce a runtime environment gate around the entrypoint.

**Strict mode.** `--strict` swaps in `Envtpl::StrictContext`, which re-wraps a missing name into `Crinja::StrictUndefined` (the shared `Crinja::Undefined` carries no name, hence the re-wrapping — it is what makes the error say *which* variable is missing). `StrictUndefined` raises when printed, not when resolved, so `default()` and `is defined` keep working. Without `--strict` an undefined variable still renders as an empty string, which is the historical behaviour.

**Verbatim output.** `Envtpl::CONFIG` sets `keep_trailing_newline: true` and `render` uses `print`, not `puts`. Both are required together: Crinja otherwise eats the template's final newline, and `puts` would paper over it on STDOUT while `--out` kept the truncated bytes. Specs assert STDOUT and `--out` are byte-identical.

**Compile-time version stamping.** `VERSION` and `GIT_REF` are macro-expanded by running `shards version` and `git log` at compile time. Consequences: a build needs both `shards` on PATH and a real `.git/` directory — which is why the `Dockerfile` copies `.git/` into the build stage. Bumping the version means editing `shard.yml`; nothing reads a hardcoded string.

**Crinja extensions.** Two registrations happen at load time, before the module:

- `env()` function — no args returns the whole environment as a hash; one arg returns that variable (empty string if absent, or the `default=` kwarg); several args return a hash filtered to those keys, silently skipping missing ones.
- `json` filter — serialises a value with `Crinja::JsonBuilder`, `indent=2` by default. A non-numeric `indent` falls back to the default instead of aborting the render.

Bare `{{ FOO }}` resolution works because `Envtpl.transform` passes `ENV` directly as the Crinja render context; `env()` reads `ENV` independently. Both behaviours are covered by specs and are part of the public contract.

**Error handling.** `parse_args!` exits with a usage message (status 0) when STDIN is a TTY and no `--in` was given; invalid options and unreadable input files exit 1. Rendering errors bubble up to the top-level `rescue` in `src/cli.cr`, which prints `"#{e.class}: #{e.message}"` to STDERR and exits 1 — the class matters because `e.message` alone is a blank line whenever it is nil. `transform` passes the input path to Crinja as the template `filename`, so errors name the offending file instead of `<string>` (Crinja reports `filename`, not `name`).

## Testing

Specs use [Spectator](https://gitlab.com/arctic-fox/spectator), not the stdlib spec DSL (`Spectator.describe`, `expect(...).to eq`). Environment mutation goes through the `with_env` helper in `spec/spec_helper.cr`, which restores previous values in an `ensure` block — never set `ENV` directly in a spec.

`spec/cli_spec.cr` runs the real binary: exit codes, the exact bytes on STDOUT and the STDIN/`--in` split cannot be observed in-process. `spec_helper.cr` compiles `src/cli.cr` to `bin/envtpl-spec` (gitignored, rebuilt unconditionally on every run) and `run_cli` returns a `CLIResult` with the exit code and both streams. Do not move that binary to a temporary path cleaned up by `at_exit`: Spectator runs the suite from its own `at_exit` handler and handlers fire last-registered-first, so the cleanup would delete the binary before a single example runs.

## CI

`.github/workflows/ci.yml` is a verbatim copy of the canonical Crystal CI template for binary projects (`~/.claude/references/crystal-ci-binary.yml`) — change the template first, then propagate. That template is itself `crystal-ci.yml`, the library variant, plus the `build_static_binaries` job; anything common to both is edited in `crystal-ci.yml` first. It runs format-check, ameba, docs, and the spec suite (single- and multi-threaded) on linux amd64/arm64, macOS arm64/intel, plus a `continue-on-error` nightly-compiler job. `MISE_DISABLE_TOOLS` skips crystalline, whose macOS binary would fail its post-install check on the runners.

The `build_static_binaries` job runs `mise release:static` on every push and PR. Without it, `Dockerfile`, `Makefile.release` and `docker-bake.hcl` were only exercised on a tag push — that is, during the release itself, when a break ships a release short of a platform.

`.github/workflows/release_binaries.yml` fires on any tag push. `create_release` creates the release once, up front; the three build jobs then `needs:` it and only upload assets (`omitBodyDuringUpdate`/`omitNameDuringUpdate`), because when each job created the release itself they raced on the same tag. Linux binaries come from `mise release:static` (QEMU + buildx), macOS arm64/intel from `mise release:build` with `OUTPUT_FILE` overridden to `bin/envtpl-darwin-<arch>`; the artifact globs are pinned to that exact name so nothing else in `bin/` gets published. The `OUTPUT_FILE` env var override is the reason `mise.toml` computes that variable through a Crinja `get_env` expression.

Both workflows declare `permissions: {}` at the workflow level; only the jobs that publish opt into `contents: write`.

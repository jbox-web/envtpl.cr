# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`envtpl` is a Crystal port of the Python `envtpl`: it renders [Crinja](https://github.com/straight-shoota/crinja) (Jinja2-like) templates using environment variables, reading from STDIN/`--in` and writing to STDOUT/`--out`. The library lives in `src/envtpl.cr` (plus `src/envtpl/licenses.cr`, the embedded third-party notices); `src/cli.cr` is the CLI entrypoint and the only compilation target.

## Commands

The toolchain is pinned by `mise.toml` (Crystal, crystalline, crystalreleaser). Everything goes through `mise` tasks — CI calls the same tasks, so a local `mise dev:*` run is what the pipeline runs.

```sh
mise dev:deps          # shards install
mise dev:build         # dev binary -> bin/envtpl (override target with OUTPUT_FILE=...)
mise dev:spec          # full spec suite
mise dev:spec-mt       # same suite with -Dpreview_mt, CRYSTAL_WORKERS=4
mise dev:ameba         # static analysis (bounded by the task timeout, 180s)
mise dev:format        # crystal tool format
mise dev:format-check  # crystal tool format --check (what CI runs)
mise dev:docs          # regenerate docs/
mise dev:licenses      # assemble licenses/ from licenses.manifest (every compiling task depends on it)
mise dev:clean         # rm -rf bin/* lib/
mise release:static    # rehearse the release in dist/ with crystalreleaser (nothing published)
```

Run a subset of specs by example name (mise forwards the arguments, and Spectator honours the standard spec CLI flags):

```sh
mise dev:spec -e "can be piped to other functions"
mise dev:spec spec/envtpl_spec.cr
```

A bare `crystal spec` skips the `dev:licenses` dependency: on a checkout where `licenses/` was never assembled, it fails at compile time.

On macOS, `shards` may be missing from the Crystal install; `mise dev:fix-shards-command` copies it into place (workaround for crystal-lang/crystal#16746, also used in CI).

## Release pipeline

Releases are made by [crystalreleaser](https://github.com/jbox-web/crystalreleaser), a mise tool pinned in `mise.toml`, from `.crystalreleaser.yml`. No machine builds every platform, so a release is split: each runner builds its share with `crystalreleaser build --split`, then one job gathers the `dist/` folders and runs `crystalreleaser release --merge`, which checks that every platform is there and from the same commit, checksums and publishes without compiling.

- `mise release:static` runs those two steps on one machine, in snapshot mode (`--snapshot --allow-missing --skip=publish`): the docker linux platforms everywhere, plus the native darwin one on a Mac. Everything lands in `dist/` (gitignored, emptied by `--clean`); nothing is published.
- The four platforms: linux amd64/arm64 static (musl), built with docker, arm64 under QEMU; darwin arm64/amd64 built natively, each on a Mac of its own architecture. crystalreleaser checks with `otool -L` that a darwin binary only loads libraries macOS ships, and fails the build otherwise. envtpl links no OpenSSL, hence no `static_libs`.
- The linux binaries are built in the `crystal` stage of the `Dockerfile` (`docker.dockerfile` and `docker.target`): alpine:3.24, Alpine's own Crystal at the minor version mise pins, and the static libraries envtpl links. That stage is all the file holds: the project is mounted into it when the build runs. Its `crystal=~X.Y` follows the Crystal of `mise.toml`.
- The compile options of every platform are the `flags` of `.crystalreleaser.yml` (`--threads 4 --release --error-trace`); crystalreleaser adds `--static` to the linux ones.
- The assets keep the names every release has used: the bare binary `envtpl-<os>-<arch>` (`formats: [binary]`) and one `envtpl-<os>-<arch>.sha256` next to it (`checksum.split`).
- The `before` hooks run on every runner of a split build, on the host: `shards install --production`, then `bash scripts/harvest-licenses.sh`, which assembles `licenses/` before anything compiles. The docker builds find the folder in the mounted project.

## Architecture notes

**Library and entrypoint are separate files.** `src/envtpl.cr` is the library (module `Envtpl`) and contains no top-level statement that runs anything; `src/cli.cr` is the only place that parses ARGV, touches STDIN and calls `exit`. Requiring the library from a spec therefore starts nothing, and no runtime guard is needed.

This split is not cosmetic. The CLI used to live at the bottom of `src/envtpl.cr` behind `unless Crystal.env.test?`, and `crystal-env` reads `CRYSTAL_ENV` **at runtime**: any user whose environment happened to carry `CRYSTAL_ENV=test` got a binary that rendered nothing and exited 0 — in a `envtpl < tpl > out` pipeline, `out` was truncated to zero bytes, silently. `spec/cli_spec.cr` guards against a regression by rendering under several `CRYSTAL_ENV` values. Do not reintroduce a runtime environment gate around the entrypoint.

**Strict mode.** `--strict` swaps in `Envtpl::StrictContext`, which re-wraps a missing name into `Crinja::StrictUndefined` (the shared `Crinja::Undefined` carries no name, hence the re-wrapping — it is what makes the error say *which* variable is missing). `StrictUndefined` raises when printed, not when resolved, so `default()` and `is defined` keep working. Without `--strict` an undefined variable still renders as an empty string, which is the historical behaviour.

**Verbatim output.** `Envtpl::CONFIG` sets `keep_trailing_newline: true` and `render` uses `print`, not `puts`. Both are required together: Crinja otherwise eats the template's final newline, and `puts` would paper over it on STDOUT while `--out` kept the truncated bytes. Specs assert STDOUT and `--out` are byte-identical.

**Compile-time version stamping.** `VERSION` and `GIT_REF` are macro-expanded by running `shards version` and `git log` at compile time. Consequences: a build needs both `shards` on PATH and a real `.git/` directory — which the docker builds have, since crystalreleaser mounts the whole project, `.git/` included, into the `crystal` image. Bumping the version means editing `shard.yml`; nothing reads a hardcoded string.

**Crinja extensions.** Two registrations happen at load time, before the module:

- `env()` function — no args returns the whole environment as a hash; one arg returns that variable (empty string if absent, or the `default=` kwarg); several args return a hash filtered to those keys, silently skipping missing ones.
- `json` filter — serialises a value with `Crinja::JsonBuilder`, `indent=2` by default. A non-numeric `indent` falls back to the default instead of aborting the render.

Bare `{{ FOO }}` resolution works because `Envtpl.transform` passes `ENV` directly as the Crinja render context; `env()` reads `ENV` independently. Both behaviours are covered by specs and are part of the public contract.

**Embedded notices.** A released binary carries the code of what it links, so it carries the notices too: `envtpl --licenses` prints them. `licenses.manifest` declares them — the crinja shard, the C libraries of the static link line, the Crystal runtime, envtpl itself — and its header records how the list was confirmed (the link line of `crystal build --static --verbose` in the build image) and when to check it again. `scripts/harvest-licenses.sh` (the canonical template's, `mise dev:licenses`) assembles them into the gitignored `licenses/`: shard and project texts copied from disk, C libraries either from their own license file in `licenses-upstream/` (whenever the license requires the copyright notice to be reproduced) or grouped by SPDX id from `licenses-spdx/`. `src/envtpl/licenses.cr` embeds the folder at compile time with `read_file`; a missing or empty folder is a compile error on purpose, which is why every compiling mise task depends on `dev:licenses`. That file is required by `src/cli.cr`, never by `src/envtpl.cr`: the library has to stay compilable where no `licenses/` folder exists (as a shard under `lib/`), and `parse_args!` only refers to `Licenses` from the `--licenses` handler, which nothing but the CLI compiles. A new runtime shard or stdlib module means a new manifest line: nothing checks that for you.

**Error handling.** `parse_args!` exits with a usage message (status 0) when STDIN is a TTY and no `--in` was given; invalid options and unreadable input files exit 1. Rendering errors bubble up to the top-level `rescue` in `src/cli.cr`, which prints `"#{e.class}: #{e.message}"` to STDERR and exits 1 — the class matters because `e.message` alone is a blank line whenever it is nil. `transform` passes the input path to Crinja as the template `filename`, so errors name the offending file instead of `<string>` (Crinja reports `filename`, not `name`).

## Testing

Specs use [Spectator](https://gitlab.com/arctic-fox/spectator), not the stdlib spec DSL (`Spectator.describe`, `expect(...).to eq`). Environment mutation goes through the `with_env` helper in `spec/spec_helper.cr`, which restores previous values in an `ensure` block — never set `ENV` directly in a spec.

`spec/licenses_spec.cr` covers the embedded notices (the exact file list of the manifest, the copyright lines, the `--licenses` layout); it changes with `licenses.manifest`.

`spec/cli_spec.cr` runs the real binary: exit codes, the exact bytes on STDOUT and the STDIN/`--in` split cannot be observed in-process. `spec_helper.cr` compiles `src/cli.cr` to `bin/envtpl-spec` (gitignored, rebuilt unconditionally on every run) and `run_cli` returns a `CLIResult` with the exit code and both streams. Do not move that binary to a temporary path cleaned up by `at_exit`: Spectator runs the suite from its own `at_exit` handler and handlers fire last-registered-first, so the cleanup would delete the binary before a single example runs.

## CI

`.github/workflows/ci.yml` is the canonical Crystal CI template for binary projects (`~/.claude/templates/crystal/ci-binary.yml`) minus the `brew install openssl@4` step of the macOS legs of `build_static_binaries` (no `static_libs` here) — change the template first, then propagate. That template is itself `ci.yml`, the library variant, plus the `build_static_binaries` job; anything common to both is edited in `ci.yml` first. It runs format-check, ameba, docs, and the spec suite (single- and multi-threaded) on linux amd64/arm64, macOS arm64/intel, plus a `continue-on-error` nightly-compiler job. `MISE_DISABLE_TOOLS` skips crystalline, whose macOS binary would fail its post-install check on the runners.

The `build_static_binaries` job runs `mise release:static` on every push and PR, with one leg per runner of `release.yml` (ubuntu-24.04, macos-26, macos-26-intel), then runs the binaries it built (`--version`): the two static linux ones on the linux leg, the native darwin one of its own architecture on each macOS leg, which has no docker and goes through the same `otool -L` check as the real release. Without it, the release path would only be exercised on a tag push — that is, during the release itself, when a break ships a release short of a platform.

`.github/workflows/release.yml` fires on a `v*` tag push. It is the canonical `release.yml` minus the `brew install openssl@4` of the darwin jobs (no `static_libs` here). A `test` job runs the suite on the tagged sources first; then `linux` (QEMU + buildx), `darwin_arm64` (macos-26) and `darwin_amd64` (macos-26-intel) each run `crystalreleaser build --split --clean` and upload their `dist/`; `release` downloads the three, and `crystalreleaser release --merge` creates the release as a draft, uploads every asset and publishes it. A platform that fails to build fails the release instead of leaving it short of that platform.

Both workflows declare `permissions: {}` at the workflow level; only the `release` job opts into `contents: write`.

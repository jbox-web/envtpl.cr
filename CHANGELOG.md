# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries before 2.0.0 were reconstructed from the tag history.

## [2.0.0] - 2026-08-02

Outcome of a full code audit. The version is a major one for a single reason:
rendered output is now verbatim, so **every file written with `--out` gains the
trailing newline it used to lose**. Nothing is lost and no option changes, but
generated files differ by one byte and their checksums change.

### Upgrading from 1.x

```
template : "port = 5432\n"

1.x      : port = 5432      (33 bytes, no final newline)
2.0.0    : port = 5432\n    (34 bytes)
```

Pipelines that compare checksums or diffs of generated files will see one
change, once. Values captured with `$(envtpl …)` are unaffected: the shell
strips trailing newlines anyway.

### Added

- `--strict` (`-s`): rendering an undefined variable now fails instead of
  producing an empty string. `default()` and `is defined` keep working, so only
  actually *printing* an undefined value is an error.
- Integration specs that run the compiled binary, covering exit codes, the exact
  bytes written to STDOUT, and the equivalence between STDOUT and `--out`.
- CI now builds the static binaries on every push, instead of first exercising
  the Dockerfile during a release.

### Changed

- **Output is verbatim.** The template's trailing newline is preserved, and no
  newline is appended that the template does not contain. Previously the same
  command produced different bytes depending on the destination: 33 bytes to a
  file, 34 to STDOUT.
- Template errors name the offending file instead of `<string>`.
- Errors on STDERR carry the exception class, which used to leave a blank line
  whenever the message was nil.
- `env()` reads only the keys it was asked for. It used to copy the whole
  environment on every call — measured at 0.96 s versus 0.06 s over 20 000 calls.
- A non-numeric `indent` on the `json` filter falls back to the default instead
  of aborting the render with a bare `Invalid Int32`.
- The release workflow creates the GitHub release once, up front; the three
  build jobs then only upload their assets. They used to race on the same tag.
- Both workflows declare `permissions: {}`, with `contents: write` granted only
  to the jobs that publish.
- `mise release:build` checksums only the binary it just built, instead of also
  hashing the previous run's `.sha256` file.
- `crinja` is constrained to `~> 0.9.0`.

### Fixed

- **The binary was a silent no-op whenever `CRYSTAL_ENV=test` was set.** The CLI
  sat behind a guard evaluated at runtime, so in such an environment `envtpl`
  rendered nothing and exited 0 — truncating the destination of
  `envtpl < tpl > out` to zero bytes without a word. The entrypoint now lives in
  `src/cli.cr` and no environment variable can disable it.
- An unrecognised `CRYSTAL_ENV` value crashed with an unhandled exception and a
  raw backtrace, for a variable unrelated to `envtpl`.
- `env('MISSING', default=none)` rendered the literal string `none` instead of
  an empty value.

### Removed

- The `crystal-env` dependency, along with the runtime environment guard that
  was its only use.
- The `upx` package from the build image: nothing invoked it.

## [1.6.0] - 2026-03-22

### Changed

- Switched toolchain management from asdf to mise.
- Bumped to Crystal 1.18.2.

### Added

- `with_env` spec helper, restoring previous values in an `ensure` block.

## [1.5.0] - 2025-10-15

### Changed

- Switched the release pipeline from Earthly to Docker Bake.
- Build true arm64 binaries rather than emulated ones.
- Bumped to Crystal 1.18.0.

## [1.4.3] - 2023-12-18

### Fixed

- Keep the original binary when compressing the released executable.

## [1.4.2] - 2023-12-10

### Changed

- Bumped to Crystal 1.10.1.

## [1.4.1] - 2023-07-18

### Changed

- Bumped to Crystal 1.9.1.

## [1.4.0] - 2023-04-20

### Changed

- Compress the final executable with upx.
- Bumped to Crystal 1.8.0.

## [1.3.1] - 2023-04-01

### Fixed

- The input file was truncated when piping it in with `cat file | envtpl`.

## [1.3.0] - 2023-04-01

### Added

- `-v` / `--version` flags.
- arm64 binaries.

### Changed

- Bumped to Crystal 1.7.3.

## [1.2.0] - 2023-01-10

### Changed

- Bumped to Crystal 1.7.0.

## [1.1.0] - 2022-10-18

### Changed

- Bumped to Crystal 1.6.0.

## [1.0.0] - 2022-09-02

Initial release.

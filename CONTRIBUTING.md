# Contributing to go-nix-helpers

Thanks for your interest in contributing! This is a Nix flake-parts library for
LarsArtmann Go projects, so the development workflow is Nix-centric.

## Prerequisites

- [Nix](https://nixos.org/) with flakes enabled (Nix 2.18+)
- No other dependencies required — the dev shell provides everything

## Getting started

```bash
git clone git@github.com:LarsArtmann/go-nix-helpers.git
cd go-nix-helpers
nix develop    # enters the dev shell with nixfmt, nix, git
```

## Development workflow

### Format

```bash
nix fmt    # formats all .nix files with nixfmt
```

### Check

```bash
nix flake check    # runs all checks (format, autoDiscovery, explicitOnly, verify, moduleTest)
```

### Run specific tests

```bash
nix build .#checks.x86_64-linux.autoDiscovery
nix build .#checks.x86_64-linux.explicitOnly
nix build .#checks.x86_64-linux.verify
nix build .#checks.x86_64-linux.moduleTest
nix run .#verifyValidation    # negative-case test (run outside sandbox)
```

## Project structure

| Path                          | Purpose                                               |
| ----------------------------- | ----------------------------------------------------- |
| `modules/go-standard.nix`     | The main flake-parts module                           |
| `mkPreparedSource.nix`        | Core private-dep injection helper                     |
| `mkGoFlake.nix`               | Deprecated function-based predecessor                 |
| `flake.nix`                   | Self-hosting flake: checks, formatter, devShell, lib  |
| `test.nix`                    | Integration tests for mkPreparedSource                |
| `test-module.nix`             | Module-level tests for go-standard options/outputs    |
| `templates/`                  | Consumer-facing templates                             |
| `scripts/`                    | Helper scripts (lint, dashboard, generate-flake)     |
| `docs/`                       | Documentation and reference material                  |

## Making changes

1. **Read the code first** — understand `modules/go-standard.nix` and
   `mkPreparedSource.nix` before making changes
2. **Test your changes** — run `nix flake check` after every modification
3. **Format** — run `nix fmt` before committing
4. **Update docs** — if your change adds/changes an option, update:
   - `README.md` options table
   - `FEATURES.md` status
   - `CHANGELOG.md` under `[Unreleased]`
5. **Keep it focused** — one logical change per PR

## Adding a new module option

1. Add the option to `modules/go-standard.nix` in the `options.go-standard` block
2. Wire it into the `config` section
3. Add a test in `test-module.nix`
4. Update the README.md options table
5. Update FEATURES.md

## Code style

- Use `lib.mkOption` with explicit types for all options
- Use `lib.mkDefault` for low-priority defaults that consumers can override
- Use `lib.mkIf` for conditional outputs
- Format with `nixfmt` (run `nix fmt`)
- Keep the module comment header up to date with the usage example

## Reporting issues

Use the [GitHub issue tracker](https://github.com/LarsArtmann/go-nix-helpers/issues).
Include:
- Your `flake.nix` (or relevant snippet)
- The exact error message
- Output of `nix flake check` or `nix build`

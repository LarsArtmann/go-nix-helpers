# Nix Flake Standard — Contributing Guide

This document describes the standard flake.nix patterns used across all LarsArtmann projects. Follow these rules when creating new projects or updating existing ones.

## Standard Stack

Every Go project should use:

| Input                             | Purpose                                                                  |
| --------------------------------- | ------------------------------------------------------------------------ |
| `nixpkgs` (`nixos-unstable`)      | Package set — always `nixos-unstable`, never `nixpkgs-unstable`          |
| `flake-parts`                     | Module system for flakes — with `inputs.nixpkgs-lib.follows = "nixpkgs"` |
| `systems` (`nix-systems/default`) | Multi-arch support — never hardcode system lists                         |
| `treefmt-nix`                     | Code formatting — with `inputs.nixpkgs.follows = "nixpkgs"`              |
| `go-nix-helpers` (optional)       | Shared module + private dep helpers                                      |

## Recommended: go-standard module

For new Go projects, use the shared module for one-line adoption:

```nix
outputs = inputs@{ self, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];
    go-standard = {
      pname = "my-project";
      vendorHash = "sha256-...";
      description = "What it does";
    };
  };
```

This gives you: packages.default, apps.default/test/lint, devShells.default/ci, checks.format/build, treefmt, and overlays.default — all from ~5 lines of config.

## Manual flake.nix rules

If not using the shared module, follow these rules:

### Inputs

- All URLs quoted: `url = "github:..."` not `url = github:...`
- `follows = "nixpkgs"` on ALL inputs that have nixpkgs
- `inputs.nixpkgs-lib.follows = "nixpkgs"` on flake-parts

### Version

```nix
version = self.rev or self.dirtyRev or "dev";
```

Never hardcode versions like `"0.1.0"`. For published packages with semver tags, hardcoding is acceptable.

### Source filtering

Use `lib.fileset` for precise source control:

```nix
src = lib.fileset.toSource {
  root = ./.;
  fileset = lib.fileset.unions [ ./go.mod ./go.sum ./cmd ./internal ];
};
```

### Build

```nix
buildGoModule = pkgs.buildGoModule.override { go = pkgs.go_1_26; };
```

- `proxyVendor = true` — recommended for all projects (ensures sandbox compatibility)
- `vendorHash` — real hash (never empty string `""`, use `null` for committed vendor/)
- `ldflags` — inject version: `-X main.version=${version}`

### Meta

```nix
meta = {
  description = "...";
  license = lib.licenses.mit;
  mainProgram = "my-project";
  maintainers = [ lib.maintainers.larsartmann ];
};
```

Every package MUST have a complete meta section.

### Checks

```nix
checks = {
  format = config.treefmt.build.check self;
  build = config.packages.default;
};
```

Every package flake MUST have `checks.build`.

### Treefmt

```nix
treefmt = {
  projectRootFile = "go.mod";
  programs = {
    gofumpt.enable = true;
    goimports.enable = true;
    nixfmt.enable = true;
  };
};
```

Use `treefmt.programs.*.enable` — NOT the legacy `treefmt.settings.formatter` API.

### DevShells

```nix
devShells = {
  default = pkgs.mkShell {
    packages = [ goPkg pkgs.golangci-lint ];
    GOWORK = "off";
  };
  ci = pkgs.mkShellNoCC {
    packages = [ goPkg pkgs.golangci-lint ];
    GOWORK = "off";
  };
};
```

- Use `mkShellNoCC` for CI devShells (no C compiler needed)
- Use `packages` not `buildInputs` (modern convention)
- Env vars as attributes, not in shellHook

### Overlay

```nix
flake.overlays.default = final: _prev: {
  my-project = self.packages.${final.stdenv.system}.default;
};
```

- Overlay attr name MUST match the project directory name
- Use `self.packages` not `inputs.self.packages`

## Private Go Dependencies

### The 4 private repos

These repos require `GOPRIVATE` because `sum.golang.org` returns 404 for them:

| Repo                                         | Consumers                                                                                                                        |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `github.com/larsartmann/go-cqrs-lite`        | cqrs-htmx, SwettySwipperWeb, DiscordSync                                                                                         |
| `github.com/larsartmann/go-finding`          | BuildFlow, library-policy, go-auto-upgrade, Code-Quality-Agent, go-functional-fixer, go-business-rules, md-go-validator, +others |
| `github.com/larsartmann/go-structure-linter` | go-structure-linter (self)                                                                                                       |
| `github.com/LarsArtmann/go-commit`           | auto-deduplicate, projects-management-automation                                                                                 |

All other LarsArtmann repos are public and work fine without GOPRIVATE.

### In devShells

```nix
GOPRIVATE = "github.com/larsartmann/*";
```

### In buildGoModule

`GOPRIVATE` is silently dropped by nixpkgs' buildGoModule env whitelist. For builds that need private deps, use `mkPreparedSource` from `go-nix-helpers` instead.

### Deprecated: GONOSUMCHECK

`GONOSUMCHECK` was deprecated in Go 1.14. Use `GOPRIVATE` (which implies `GONOSUMDB`) instead. Never use `GONOSUMCHECK`.

## Formatting

- Formatter: `nixfmt` (RFC 166 style) — NOT alejandra or nixpkgs-fmt
- Run: `nix fmt`
- Check: `nix flake check --no-build`

## Anti-patterns to avoid

- `inputs.self.packages` — use `self.packages` directly
- `treefmt.settings.formatter` — use `treefmt.programs.*.enable`
- `treefmt.config` — use `treefmt` directly (no `.config` wrapper)
- `buildInputs` in mkShell — use `packages`
- `mkShell` for CI — use `mkShellNoCC`
- `vendorHash = ""` — use `null` or a real hash
- `GONOSUMCHECK` — use `GOPRIVATE`
- Unquoted URLs — always quote
- Missing `follows` — all shared inputs must follow nixpkgs

# go-nix-helpers

[![nix flake check](https://img.shields.io/badge/nix%20flake%20check-passing-5277C3?logo=nixos&style=flat-square)](https://nixos.org)
[![Go](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go&style=flat-square)](https://go.dev)
[![flake-parts](https://img.shields.io/badge/flake--parts-module-blueviolet?style=flat-square)](https://flake.parts)

**One flake-parts module. Three inputs. ~20 lines. Full Go packaging, dev shells, formatting, linting, CI, overlays, and private-dependency injection.**

Stop hand-writing the same `flake.nix` boilerplate for every Go repo. `go-nix-helpers` gives you a typed, batteries-included [`flake-parts`](https://flake.parts) module that turns a short config block into a complete developer and build environment — including the trickiest part: building Go projects that depend on private GitHub modules inside the Nix sandbox.

---

## Quick start

```nix
{
  description = "My project — what it does";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    go-nix-helpers = {
      url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];

      go-standard = {
        pname = "my-project";
        vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # run `nix build` to compute
        description = "What this project does";
      };
    };
}
```

That is the whole flake. `treefmt-nix` and `systems` are bundled inside the module, so you do not declare them as inputs.

After copying it in:

```bash
nix build      # produces the package
nix run        # runs the default app
nix develop    # enters the full dev shell
nix flake check # formats, builds, and runs checks
```

---

## What you get

| Output              | What it gives you                                        |
| ------------------- | -------------------------------------------------------- |
| `packages.default`  | Compiled binary via `buildGoModule` (Go 1.26)            |
| `packages.<pname>`  | Same package under its own name                          |
| `apps.default`      | `nix run .#<pname>`                                      |
| `apps.test`         | `go test -race -v ./...`                                 |
| `apps.lint`         | `golangci-lint run ./...`                                |
| `devShells.default` | Go + gopls + gofumpt + golangci-lint (+ optional extras) |
| `devShells.ci`      | Minimal CI shell                                         |
| `checks.format`     | `treefmt` formatting check                               |
| `checks.build`      | Package build verification                               |
| `overlays.default`  | Exposes `pkgs.<pname>` to other flakes                   |

`GOWORK = "off"` and `GOTOOLCHAIN = "local"` are set by default in every shell to keep the build deterministic.

---

## Private dependencies, solved

The Nix sandbox has no SSH and no network, so `go` cannot fetch private modules. `go-nix-helpers` solves this transparently:

```nix
go-standard = {
  pname = "my-project";
  vendorHash = "sha256-...";
  description = "What it does";

  deps = {
    "github.com/larsartmann/go-cqrs-lite" = inputs.go-cqrs-lite;
  };
  # Sub-modules are auto-discovered. GOPRIVATE is auto-injected.
  # Build fails with a clear message if a private require lacks a replace.
};
```

Add the dep as a `flake = false` input, list it in `deps`, and the module does the rest:

- Copies each dependency into `_local_deps/`
- Auto-discovers every sub-module at any depth (no manual `subModules` list)
- Injects `replace` directives into `go.mod`
- Strips stale absolute/relative replace directives
- Handles `/vN` major-version paths correctly
- Validates that every private `require` has a matching `replace`

If you need the lower-level helper directly, import `mkPreparedSource.nix` instead.

---

## Before and after

| Concern              | Manual flake.nix                           | `go-standard` module                 |
| -------------------- | ------------------------------------------ | ------------------------------------ |
| Inputs required      | nixpkgs, flake-parts, treefmt-nix, systems | nixpkgs, flake-parts, go-nix-helpers |
| Lines to maintain    | ~80–120                                    | ~20                                  |
| Private deps         | Hand-rolled `mkPreparedSource` wiring      | One `deps` attrset                   |
| Sub-module discovery | Manual list                                | Automatic                            |
| Validation           | Cryptic SSH errors at build time           | Clear pre-build validation           |
| Formatting           | Manual `treefmt` wiring                    | Auto-configured                      |

---

## Configuration options

See the full option table below, or copy one of the [templates](#templates).

| Option                  | Default                      | Description                                                          |
| ----------------------- | ---------------------------- | -------------------------------------------------------------------- |
| `pname`                 | (required)                   | Package name, overlay attr, and `mainProgram`                        |
| `vendorHash`            | `null`                       | Vendor hash for `buildGoModule` (`null` = committed `vendor/`)       |
| `src`                   | `self.outPath`               | Source path (use `lib.fileset` to filter)                            |
| `description`           | `"A LarsArtmann Go project"` | Short description for package meta                                   |
| `subPackages`           | `[ "." ]`                    | Subpackages to build                                                 |
| `goPkgAttr`             | `"go_1_26"`                  | Go package attribute in nixpkgs                                      |
| `enableTempl`           | `false`                      | Include `templ` in devShells and treefmt                             |
| `enableGovulncheck`     | `true`                       | Include `govulncheck` in the default devShell                        |
| `enableGopls`           | `true`                       | Include `gopls` in the default devShell                              |
| `deps`                  | `{}`                         | Private Go deps for `mkPreparedSource`                               |
| `subModules`            | `{}`                         | Explicit sub-modules (merged with auto-discovered)                   |
| `postPatchExtra`        | `""`                         | Extra `postPatch` commands for `mkPreparedSource`                    |
| `autoGoPrivate`         | `true`                       | Auto-inject `GOPRIVATE` when deps are set                            |
| `validatePrivateDeps`   | `true`                       | Fail build if a private `require` lacks a `replace`                  |
| `proxyVendor`           | `true`                       | Pass `proxyVendor` to `buildGoModule`                                |
| `ldflags`               | `null` (auto)                | Custom ldflags (`null` = `["-s" "-w" "-X main.version=${version}"]`) |
| `extraMeta`             | `{}`                         | Extra attributes merged into package meta                            |
| `extraBuildAttrs`       | `{}`                         | Extra attributes merged into `buildGoModule`                         |
| `devShellExtraPackages` | `_: []`                      | Function receiving `pkgs`, returns extra devShell packages           |
| `shellExtraEnv`         | `{}`                         | Extra env vars for devShells                                         |

---

## Lower-level helpers

### `mkPreparedSource.nix`

Use this when you want to wire `buildGoModule` yourself but still need private-dependency injection and sub-module auto-discovery.

```nix
mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
  inherit pkgs lib;
  goPkg = pkgs.go_1_26;
};

preparedSrc = mkPreparedSource {
  name = "my-app";
  version = "1.0.0";
  src = ./.;
  deps = {
    "github.com/larsartmann/go-cqrs-lite" = go-cqrs-lite;
  };
};
```

| Parameter             | Default                             | Description                                         |
| --------------------- | ----------------------------------- | --------------------------------------------------- |
| `name`                | (required)                          | Derivation name prefix                              |
| `src`                 | (required)                          | Source derivation or path                           |
| `deps`                | (required)                          | Attrset of `{ "import/path" = flake-input; }`       |
| `version`             | `"dev"`                             | Version string                                      |
| `autoSubModules`      | `true`                              | Auto-discover sub-modules from dep source trees     |
| `subModules`          | `{}`                                | Explicit sub-modules (merged with auto-discovered)  |
| `requireDeps`         | `{}`                                | Manually inject `require` lines                     |
| `subModuleVersion`    | `"v0.0.0"`                          | Version for pseudo-version normalization            |
| `stripLocalReplaces`  | `true`                              | Strip stale `replace X => /home/...` directives     |
| `validatePrivateDeps` | `true`                              | Verify every private `require` has a `replace`      |
| `privateDepPattern`   | `"github\\.com/[Ll]ars[Aa]rtmann/"` | ERE regex matching private module paths to validate |
| `postPatchExtra`      | `""`                                | Additional shell commands appended to `postPatch`   |

### `mkGoFlake.nix` (deprecated)

The function-based predecessor to `flakeModules.go-standard`. It is kept for backwards compatibility; new projects should use the module.

---

## Templates

| Template                                                                   | Use when...                                                          |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| [`templates/go-standard/flake.nix`](templates/go-standard/flake.nix)       | Starting a new project — recommended, minimal setup                  |
| [`templates/go-flake-parts/flake.nix`](templates/go-flake-parts/flake.nix) | You need full manual control over packages, apps, shells, and checks |

---

## Development

```bash
nix flake check                    # all checks (autoDiscovery, explicitOnly, verify, treefmt)
nix build .#verifyValidation       # build the validation test runner
nix run .#verifyValidation         # run the negative-case validation outside the sandbox
nix fmt                            # format all .nix files
```

---

## Related projects

Used across LarsArtmann Go repositories including `go-structure-linter`, `go-output`, `go-atomic-write`, `gogenfilter`, and `samber-do-auditlog`.

See [`docs/flake-patterns.md`](docs/flake-patterns.md) for detailed patterns and anti-patterns when writing flake.nix files for Go projects.

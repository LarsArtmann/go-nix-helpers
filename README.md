# go-nix-helpers

Shared Nix helpers for LarsArtmann Go repositories.

**3 inputs. ~20 lines. Full build, test, lint, format, devShell, CI shell, overlay, and private-dep injection.**

---

## `flakeModules.go-standard` (recommended)

A flake-parts module that generates standard flake outputs from a single config block.
Bundles `treefmt-nix` internally — consumers do **not** need `treefmt-nix` or `systems` inputs.

### What you get

- `packages.default` + `packages.<pname>` — buildGoModule with Go 1.26
- `apps.default`, `apps.test`, `apps.lint` — CLI entrypoints
- `devShells.default`, `devShells.ci` — Go + golangci-lint (+ optional gopls, govulncheck, templ)
- `checks.format` (treefmt), `checks.build` (package build)
- `treefmt` — gofumpt + goimports + nixfmt (+ optional templ)
- `formatter` — `nix fmt`
- `flake.overlays.default` — expose package for other flakes
- Private dep injection via `mkPreparedSource` (when `deps = { ... }`)
- `GOPRIVATE` auto-injection (when deps are set)
- `GOWORK = "off"` and `GOTOOLCHAIN = "local"` in all devShells

### Minimal flake.nix (3 inputs, ~20 lines)

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
        vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # nix build to compute
        description = "What this project does";
      };
    };
}
```

### With private dependencies

```nix
inputs = {
  # ... nixpkgs, flake-parts, go-nix-helpers as above ...

  go-cqrs-lite = {
    url = "git+ssh://git@github.com/LarsArtmann/go-cqrs-lite?ref=master";
    flake = false;
  };
};

outputs = inputs@{ self, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];

    go-standard = {
      pname = "my-project";
      vendorHash = "sha256-...";
      description = "What it does";
      deps = {
        "github.com/larsartmann/go-cqrs-lite" = inputs.go-cqrs-lite;
      };
      # GOPRIVATE is auto-injected. mkPreparedSource auto-wired.
      # Sub-modules are auto-discovered — no manual subModules list needed.
    };
  };
```

### All options

| Option                 | Default                             | Description                                                                        |
| ---------------------- | ----------------------------------- | ---------------------------------------------------------------------------------- |
| `pname`                | (required)                          | Package name (also overlay attr and mainProgram)                                   |
| `vendorHash`           | `null`                              | Vendor hash for buildGoModule (null = committed vendor/)                           |
| `src`                  | `self.outPath`                      | Source path (use `lib.fileset` for filtering)                                      |
| `description`          | `"A LarsArtmann Go project"`        | Short description for package meta                                                 |
| `subPackages`          | `[ "." ]`                           | Subpackages to build                                                               |
| `goPkgAttr`            | `"go_1_26"`                         | Go package attribute in nixpkgs                                                    |
| `enableTempl`          | `false`                             | Include templ in devShells and treefmt                                             |
| `enableGovulncheck`    | `true`                              | Include govulncheck in the default devShell                                        |
| `enableGopls`          | `true`                              | Include gopls in the default devShell                                              |
| `deps`                 | `{}`                                | Private Go deps for mkPreparedSource (empty = no prepared source)                  |
| `subModules`           | `{}`                                | Explicit sub-modules for mkPreparedSource (merged with auto-discovered)            |
| `postPatchExtra`       | `""`                                | Extra postPatch commands for mkPreparedSource                                      |
| `autoGoPrivate`        | `true`                              | Auto-inject GOPRIVATE when deps are set                                            |
| `validatePrivateDeps`  | `true`                              | Fail build if a private require lacks a replace                                    |
| `proxyVendor`          | `true`                              | Pass proxyVendor to buildGoModule                                                  |
| `ldflags`              | `null` (auto)                       | Custom ldflags (null = `["-s" "-w" "-X main.version=${version}"]`)                 |
| `extraMeta`            | `{}`                                | Extra attributes merged into package meta                                          |
| `extraBuildAttrs`      | `{}`                                | Extra attributes merged into buildGoModule                                         |
| `devShellExtraPackages`| `_: []`                             | Function receiving pkgs, returns extra devShell packages                           |
| `shellExtraEnv`        | `{}`                                | Extra env vars for devShells (e.g. `{ GOPRIVATE = "..."; }`)                       |

---

## `mkPreparedSource.nix` (lower-level)

Prepares Go source with local dependency replacement for Nix sandbox builds.

Go repos with private dependencies can't fetch them inside the Nix sandbox (no SSH, no network).
This helper copies flake-input deps into `_local_deps/` and injects `replace` directives into `go.mod`.

### Key features

- **Auto-discovers sub-modules** — scans each dep source for subdirectories containing `go.mod`
  and generates replace directives automatically. No manual `subModules` list needed.
- **Build-time validation** — verifies every private module require in go.mod has a corresponding
  replace directive. Fails with a clear error message instead of the cryptic
  "could not read Username for 'https://github.com'" SSH error.
- **`/vN` major version handling** — the `/vN` suffix is kept in the module path but stripped
  from the local directory path automatically.

### Usage (in a manual flake.nix)

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
    "github.com/larsartmann/go-branded-id" = go-branded-id;
  };
  # subModules omitted — auto-discovered from dep sources.
};
```

### Parameters

| Parameter             | Default                             | Description                                                                                                             |
| --------------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `name`                | (required)                          | Derivation name prefix                                                                                                  |
| `src`                 | (required)                          | Source derivation or path                                                                                               |
| `deps`                | (required)                          | Attrset of `{ "import/path" = flake-input; }`                                                                           |
| `version`             | `"dev"`                             | Version string                                                                                                          |
| `autoSubModules`      | `true`                              | Auto-discover sub-modules from dep source trees                                                                         |
| `subModules`          | `{}`                                | Explicit sub-modules (merged with auto-discovered)                                                                      |
| `requireDeps`         | `{}`                                | Manually inject require lines (rarely needed)                                                                           |
| `subModuleVersion`    | `"v0.0.0"`                          | Version for pseudo-version normalization                                                                                |
| `stripLocalReplaces`  | `true`                              | Strip stale `replace X => /home/...` directives                                                                         |
| `validatePrivateDeps` | `true`                              | Verify every private require has a replace directive                                                                    |
| `privateDepPattern`   | `"github\\.com/[Ll]ars[Aa]rtmann/"` | ERE regex matching private module paths that must have a replace. Override to validate deps outside the LarsArtmann org |
| `postPatchExtra`      | `""`                                | Additional shell commands appended to postPatch                                                                         |

---

## `mkGoFlake.nix` (deprecated)

Superseded by `flakeModules.go-standard`. Use the module instead — it provides the same
functionality via typed options with better IDE support and discoverability.

Migration: replace the `import ... mkGoFlake.nix` call with:

```nix
imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];
go-standard = { pname = "..."; vendorHash = "..."; ... };
```

---

## Testing

```bash
nix flake check                    # all checks (autoDiscovery, explicitOnly, verify, treefmt)
nix-build test.nix -A autoDiscovery -o result-auto    # verify auto-discovery
nix run .#verifyValidation         # negative-case validation (run outside sandbox)
```

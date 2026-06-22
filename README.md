# go-nix-helpers

Shared Nix helpers for LarsArtmann Go repositories.

## `mkPreparedSource.nix`

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

### Usage

Add as a flake input:

```nix
inputs = {
  go-nix-helpers = {
    url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
    flake = false;
  };
};
```

Then in outputs:

```nix
mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
  inherit pkgs lib;
  goPkg = pkgs.go_1_26;
};
```

### Full example (recommended — auto-discovery)

```nix
preparedSrc = mkPreparedSource {
  name = "my-app";
  version = "1.0.0";
  src = ./.;
  deps = {
    "github.com/larsartmann/go-cqrs-lite" = go-cqrs-lite;
    "github.com/larsartmann/go-branded-id" = go-branded-id;
  };
  # subModules omitted — auto-discovered from dep sources.
  # All subdirectories with go.mod are found and replace directives generated.
};
```

That's it. No manual `subModules` list to maintain. When go-cqrs-lite adds a new sub-module,
the next `nix flake update` picks it up automatically.

### Major version suffixes (`/v2`, `/v3`, ...)

Go modules at v2+ use a `/vN` suffix in the import path. `mkPreparedSource` handles
this automatically — the repo name is extracted from the path, stripping the version
suffix so the local directory name is always the repo name (not `v2`, `v3`, etc.).

```nix
deps = {
  "github.com/larsartmann/go-output" = go-output;
  "github.com/larsartmann/go-filewatcher/v2" = go-filewatcher;
  "github.com/LarsArtmann/gogenfilter/v3" = gogenfilter;
};
```

This produces `_local_deps/go-output`, `_local_deps/go-filewatcher`,
`_local_deps/gogenfilter` — no collisions even with multiple `/v2` deps from
different repos.

### Auto-discovery

When `autoSubModules` is `true` (the default), `mkPreparedSource` scans each dep
source for subdirectories containing `go.mod`. For each one, it:

1. Reads the module path from `go.mod` line 1
2. Generates a replace directive pointing to the local copy

This means you no longer need to maintain a manual list of sub-modules. When a
dependency repo adds a new sub-module (e.g., go-cqrs-lite adds `kv/v2`), it's
picked up automatically on the next `nix flake update`.

Extra replace directives for unused sub-modules are harmless — `go mod tidy`
ignores them.

To disable auto-discovery for a specific dep, set `autoSubModules = false` and
use the explicit `subModules` parameter instead.

### Explicit sub-modules (optional, for edge cases)

If auto-discovery doesn't work for your case (e.g., non-standard directory layout),
you can specify sub-modules explicitly. These are **merged** with auto-discovered
entries — no duplication.

```nix
subModules = {
  "github.com/larsartmann/go-output" = [ "enum" "escape" ];
};
```

Versioned sub-paths (ending in `/vN`) are handled automatically: the `/vN` suffix
is kept in the module path but stripped from the local directory path.

e.g. `"codec/v2"` → replace directive: `.../codec/v2 => ./_local_deps/<repo>/codec`

### Build-time validation

When `validatePrivateDeps` is `true` (the default), the build checks that every
`github.com/larsartmann/*` module in go.mod's `require` block has a corresponding
`replace` directive. If any are missing, the build fails with a clear message:

```
mkPreparedSource: private modules without local replace:

  github.com/larsartmann/new-private-dep

These modules are required in go.mod but have no replace directive.
Add the missing repos to your flake.nix inputs and deps map.
```

This eliminates the cryptic `could not read Username for 'https://github.com'`
error that occurs when a private dep is in go.mod but not in the flake inputs.

### Testing

```bash
nix-build test.nix -A autoDiscovery -o result-auto    # verify auto-discovery
cat result-auto/go.mod                                  # inspect generated go.mod
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

## `mkGoFlake.nix`

Shared flake-parts module that generates standard flake outputs from a single config attrset.
Eliminates ~150 lines of duplicated flake.nix boilerplate per project.

### What it generates

- `packages.default` + `packages.<pname>` — buildGoModule with private deps via mkPreparedSource
- `apps.default`, `apps.test`, `apps.lint` — standard CLI entrypoints
- `devShells.default`, `devShells.ci` — Go + golangci-lint, with optional extras
- `checks.format` (treefmt), `checks.build` (package build)
- `treefmt` — gofumpt + goimports + nixfmt
- `flake.overlays.default` — expose package for other flakes

### Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = { url = "github:hercules-ci/flake-parts"; inputs.nixpkgs-lib.follows = "nixpkgs"; };
    systems.url = "github:nix-systems/default";
    treefmt-nix = { url = "github:numtide/treefmt-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    go-nix-helpers = {
      url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
      flake = false;
    };
    # Private deps (flake = false)
    go-cqrs-lite = {
      url = "git+ssh://git@github.com/LarsArtmann/go-cqrs-lite?ref=master";
      flake = false;
    };
  };

  outputs = inputs@{ self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; }
      (import (inputs.go-nix-helpers + "/mkGoFlake.nix") {
        inherit inputs self;
        pname = "my-project";
        version = "0.1.0";
        vendorHash = "sha256-AAA...";
        description = "What this project does";
        src = ./.;
        deps = {
          "github.com/larsartmann/go-cqrs-lite" = inputs.go-cqrs-lite;
        };
      });
}
```

That's the entire flake.nix. No perSystem boilerplate, no manual devShell/checks/treefmt config.

### Parameters

| Parameter             | Default                              | Description                                                        |
| --------------------- | ------------------------------------ | ------------------------------------------------------------------ |
| `inputs`              | (required)                           | Consumer's full flake inputs attrset                               |
| `self`                | (required)                           | Consumer's flake self reference                                    |
| `pname`               | (required)                           | Package name (e.g. `"my-project"`)                                 |
| `version`             | (required)                           | Version string                                                     |
| `vendorHash`          | (required)                           | Vendor hash for buildGoModule                                      |
| `description`         | (required)                           | Short description for `meta.description`                           |
| `src`                 | (required)                           | Source path (usually `./.`)                                        |
| `deps`                | `{}`                                 | Private dep map for mkPreparedSource (empty = no prepared source)  |
| `subModules`          | `{}`                                 | Sub-module overrides for mkPreparedSource                          |
| `postPatchExtra`      | `""`                                 | Extra postPatch commands for mkPreparedSource                      |
| `doCheck`             | `true`                               | Whether to run Go tests in buildGoModule                           |
| `ldflags`             | `null` (auto-computed)              | Custom ldflags (default: `["-s" "-w" "-X main.version=${version}"]`) |
| `goPkgAttr`           | `"go_1_26"`                          | Which nixpkgs Go attribute to use                                  |
| `buildGoModuleOverrides` | `{}`                             | Extra/override attrs merged into buildGoModule                     |
| `devShellExtraPackages` | `_pkgs: []`                       | Function receiving pkgs, returns extra devShell packages           |
| `devShellShellHook`   | `""` (auto: echoes pname + version) | Custom shell hook text                                             |
| `shellExtraEnv`       | `{}`                                 | Extra env vars in both devShells (e.g. `{ GOTOOLCHAIN = "local"; }`) |
| `extraApps`           | `_: {}`                              | Function receiving `{config, pkgs, lib, goPkg, package}`, returns extra apps |
| `extraChecks`         | `_: {}`                              | Function receiving `{config, pkgs, lib, goPkg, package}`, returns extra checks |
| `extraFlake`          | `{}`                                 | Extra flake-level outputs (e.g. nixosModules)                      |

### Project-specific customisation

For projects that need extra apps, NixOS modules, or custom build flags:

```nix
(import (inputs.go-nix-helpers + "/mkGoFlake.nix") {
  inherit inputs self;
  pname = "crush-daily";
  version = "0.1.0";
  vendorHash = "sha256-...";
  description = "Daily AI-powered insights";
  src = ./.;
  deps = { ... };

  # Extra env for both devShells
  shellExtraEnv = { GOTOOLCHAIN = "local"; };

  # Extra devShell packages
  devShellExtraPackages = pkgs: [ pkgs.gotools pkgs.trash-cli ];

  # Custom build overrides
  buildGoModuleOverrides = {
    env = { CGO_ENABLED = "0"; };
    preBuild = ''export HOME=$TMPDIR; go mod tidy'';
  };

  # Extra checks (e.g. a separate test check)
  extraChecks = { config, ... }: {
    test = config.packages.default.overrideAttrs (_: { doCheck = true; });
  };

  # NixOS module
  extraFlake = {
    nixosModules.my-project = { ... };
  };
})
```

# Migration Guide: mkGoFlake / manual setup to go-standard

This guide covers migrating from the deprecated `mkGoFlake.nix` function, the
`go-flake-parts` template, or a manual `mkPreparedSource` setup to the
recommended `flakeModules.go-standard` module.

---

## Why migrate?

| Before (mkGoFlake / manual)      | After (go-standard module)            |
| -------------------------------- | ------------------------------------- |
| 5 flake inputs required          | 3 flake inputs required               |
| ~80-120 lines of flake.nix       | ~20 lines                             |
| Manual `treefmt-nix` wiring      | Bundled internally                    |
| Manual `systems` input           | Hardcoded defaults (overridable)      |
| Manual `mkPreparedSource` wiring | `deps` attrset — auto-wired           |
| Sub-module discovery by hand     | Recursive auto-discovery at any depth |
| Cryptic SSH errors at build      | Clear pre-build validation            |

---

## From mkGoFlake.nix

### Before (mkGoFlake.nix)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = { ... };
    systems.url = "github:nix-systems/default";
    treefmt-nix = { ... };
    go-nix-helpers = {
      url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
      flake = false;
    };
  };

  outputs = inputs@{ self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; }
      (import (inputs.go-nix-helpers + "/mkGoFlake.nix") {
        inherit inputs self;
        pname = "my-project";
        version = "0.1.0";
        vendorHash = "sha256-...";
        description = "What it does";
        src = ./.;
        deps = {
          "github.com/larsartmann/go-cqrs-lite" = inputs.go-cqrs-lite;
        };
      });
}
```

### After (go-standard module)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = { ... };
    go-nix-helpers = {
      url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";  # real flake input, NOT flake = false
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
      };
    };
}
```

### Key changes

1. **Remove `flake = false`** from the go-nix-helpers input — the module needs to be a real flake input so it can export `flakeModules.go-standard`.
2. **Remove `systems` and `treefmt-nix` inputs** — bundled inside the module.
3. **Add `inputs.nixpkgs.follows = "nixpkgs"`** to keep nixpkgs versions in sync.
4. **Move config from function args to `go-standard` attrset** — the option names are the same.

### Parameter mapping

| mkGoFlake parameter      | go-standard option                  | Notes                                             |
| ------------------------ | ----------------------------------- | ------------------------------------------------- |
| `pname`                  | `go-standard.pname`                 | Same                                              |
| `version`                | `go-standard.version`               | Defaults to `self.rev or "dev"` — usually omit    |
| `vendorHash`             | `go-standard.vendorHash`            | Same                                              |
| `description`            | `go-standard.description`           | Same                                              |
| `src`                    | `go-standard.src`                   | Defaults to `self.outPath` — usually omit         |
| `deps`                   | `go-standard.deps`                  | Same                                              |
| `subModules`             | `go-standard.subModules`            | Rarely needed — auto-discovery handles it         |
| `doCheck`                | `go-standard.enableCheck`           | Renamed, default `true`                           |
| `ldflags`                | `go-standard.ldflags`               | Same                                              |
| `goPkgAttr`              | `go-standard.goPkgAttr`             | Same                                              |
| `buildGoModuleOverrides` | `go-standard.extraBuildAttrs`       | Renamed                                           |
| `devShellExtraPackages`  | `go-standard.devShellExtraPackages` | Same                                              |
| `shellExtraEnv`          | `go-standard.shellExtraEnv`         | Same                                              |
| `extraApps`              | (add in consumer flake)             | No equivalent — add apps directly in your flake   |
| `extraChecks`            | (add in consumer flake)             | No equivalent — add checks directly in your flake |
| `extraFlake`             | (add in consumer flake)             | No equivalent — add flake attrs directly          |

---

## From the go-flake-parts template

The `templates/go-flake-parts/flake.nix` template uses the old 5-input manual
pattern. To migrate:

1. Follow the same steps as the mkGoFlake migration above
2. Copy the `templates/go-standard/flake.nix` template instead
3. Replace any manual `treefmt`, `checks`, `overlays` config with the module defaults

---

## From manual mkPreparedSource

If you currently import `mkPreparedSource.nix` directly:

```nix
mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
  inherit pkgs lib;
  goPkg = pkgs.go_1_26;
};

preparedSrc = mkPreparedSource {
  name = "my-app";
  src = ./.;
  deps = { ... };
};
```

You can keep this low-level approach (it still works with `flake = false`), or
migrate to the module which auto-wires everything. The module also adds:

- Auto-injected `GOPRIVATE` in devShells
- `go mod tidy` in the FOD to resolve transitive deps
- Build-time validation of private requires
- `subModules` auto-discovery (no manual list needed)

---

## Troubleshooting

### "cannot coerce a function to a string"

You likely still have `flake = false` on the go-nix-helpers input. Remove it
and add `inputs.nixpkgs.follows = "nixpkgs"` instead.

### "input 'go-nix-helpers' has unsupported attribute 'flakeModules'"

Same cause — the input must be a real flake (not `flake = false`) to access
`flakeModules.go-standard`.

### Build fails after migration

Run `nix build` once to get the new vendor hash — the module changes how
deps are prepared, which may change the hash.

---

## Need help?

Open an [issue](https://github.com/LarsArtmann/go-nix-helpers/issues) if you
run into problems during migration.

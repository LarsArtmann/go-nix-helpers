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
| `buildGoModuleOverrides` | `go-standard.extraBuildAttrs`       | Renamed — 6 attrs now concatenate (nativeBuildInputs, buildInputs, checkInputs, configureFlags, preBuild, postInstall) |
| `enableNixfmt`           | `go-standard.enableNixfmt`           | New — controls nixfmt in treefmt (default: true)  |
| (new)                    | `go-standard.enableShfmt`            | New — controls shfmt in treefmt (default: false) |
| (new)                    | `go-standard.enableTempl`            | New — includes templ in devShells and treefmt (default: false) |
| (new)                    | `go-standard.enableGopls`            | New — includes gopls in devShell (default: true) |
| (new)                    | `go-standard.enableGovulncheck`      | New — includes govulncheck in devShell (default: true) |
| `devShellExtraPackages`  | `go-standard.devShellExtraPackages` | Same                                              |
| `shellExtraEnv`          | `go-standard.shellExtraEnv`         | Same                                              |
| `extraApps`              | (add in consumer flake)             | No equivalent — add apps directly in your flake   |
| `extraChecks`            | (add in consumer flake)             | No equivalent — add checks directly in your flake |
| `extraFlake`             | (add in consumer flake)             | No equivalent — add flake attrs directly          |

### Migrating `extraApps`, `extraChecks`, `extraFlake`

`go-standard` intentionally does not provide these options. Add extra
outputs directly in your flake alongside the module import:

```nix
outputs = inputs@{ self, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];

    go-standard = { /* ... */ };

    # Replace extraApps: add perSystem apps directly
    perSystem = { pkgs, ... }: {
      apps.deploy = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "deploy" "kubectl deploy"}/bin/deploy";
      };
    };

    # Replace extraChecks: add perSystem checks directly
    # (already merged with go-standard's checks via flake-parts)

    # Replace extraFlake: add top-level flake attrs directly
    flake.lib = { myHelper = import ./my-helper.nix; };
  };
```

flake-parts merges `perSystem` and `flake` from all modules, so your
additions coexist with go-standard's outputs seamlessly.

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

## Common migration patterns

These patterns were proven across 10+ consumer repo migrations.

### GOEXPERIMENT=jsonv2

Most LarsArtmann Go projects use `encoding/json/v2` behind the `jsonv2`
experiment flag. Set it in three places:

```nix
go-standard = {
  # 1. Build-time: set as a buildGoModule attribute
  extraBuildAttrs.GOEXPERIMENT = "jsonv2";

  # OR via preBuild (if you need it in the shell environment of the build)
  extraBuildAttrs.preBuild = "export GOEXPERIMENT=jsonv2";

  # 2. DevShell-time: set as env var in devShells
  shellExtraEnv.GOEXPERIMENT = "jsonv2";

  # 3. Build tags (if the code uses build constraints)
  buildFlags = [ "-tags=goexperiment.jsonv2" ];
};
```

### proxyVendor behavior change

The module forces `proxyVendor = false` when `deps` are set (private deps
require vendoring via local copies, not the Go proxy). If your manual setup
used `proxyVendor = true`, the vendor hash **will change** after migration.

**Fix:** Run `nix build .#default` once after migration. Copy the `got:`
hash from the mismatch error and update `vendorHash`.

### Cobra completions (not urfave/cli)

The module's `enableCompletions` calls `binary --completion bash` (urfave/cli
style). Cobra uses `binary completion bash` (subcommand style). If your CLI
uses Cobra:

```nix
go-standard = {
  enableCompletions = false;  # disable module's completion logic
};

perSystem = { config, pkgs, ... }: {
  # Custom postInstall for cobra-style completions
  packages.default = pkgs.lib.mkForce (
    config.packages.default.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        installShellCompletion --cmd myapp \
          --bash <($out/bin/myapp completion bash) \
          --zsh <($out/bin/myapp completion zsh) \
          --fish <($out/bin/myapp completion fish)
      '';
    })
  );
};
```

### requireDeps for sub-module version pins

When a dependency has sub-modules (separate `go.mod` files) that need
explicit `require` entries in your `go.mod`, use `requireDeps`:

```nix
go-standard = {
  deps = {
    "github.com/LarsArtmann/project-discovery-sdk" = inputs.project-discovery-sdk;
  };
  subModules = {
    "github.com/LarsArtmann/project-discovery-sdk" = [
      "detection" "discovery" "domain"
    ];
  };
  requireDeps = {
    "github.com/LarsArtmann/project-discovery-sdk/detection" = "v0.0.0";
    "github.com/LarsArtmann/project-discovery-sdk/discovery" = "v0.0.0";
  };
};
```

### Custom apps overriding module defaults

The module generates `apps.default`, `apps.test`, `apps.lint`, `apps.fmt`.
If you need custom versions, use `lib.mkForce`:

```nix
perSystem = { config, pkgs, lib, ... }: {
  apps.lint = lib.mkForce {
    type = "app";
    program = "${pkgs.writeShellApplication { ... }}/bin/my-lint";
  };
};
```

### Dual treefmt (treefmt-nix + treefmt-flake)

go-standard bundles treefmt-nix for Go formatting. For multi-language
formatting (web, python, rust, yaml, markdown, json), add treefmt-flake
as a separate import:

```nix
imports = [
  inputs.go-nix-helpers.flakeModules.go-standard
  inputs.treefmt-flake.flakeModule
];
```

Set `enableShfmt = true` if treefmt-flake's `shell.enable` conflicts with
the module's default `enableShfmt = false`.

---

## Need help?

Open an [issue](https://github.com/LarsArtmann/go-nix-helpers/issues) if you
run into problems during migration.

---

## Post-migration verification

Use the [consumer audit checklist](consumer-audit-checklist.md) to verify a
migrated repo uses go-standard correctly and idiomatically — 8 sections
covering module adoption, input minimalism, private deps wiring, redundant
overrides, verification commands, and flake.lock hygiene. It includes a quick
triage script for a fast first pass.

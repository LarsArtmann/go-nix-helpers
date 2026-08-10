# Flake.nix Correct Patterns Reference

All LarsArtmann Go projects use the **flake-parts** + **go-nix-helpers** (which bundles treefmt-nix + systems) standard stack.

## Table of Contents

1. [Common Error Patterns](#common-error-patterns)
2. [Correct Template Structure](#correct-template-structure)
3. [Unfree Packages Pattern](#unfree-packages-pattern)
4. [Private Go Dependencies](#private-go-dependencies)
5. [Checks Placement Rules](#checks-placement-rules)
6. [treefmt Configuration Rules](#treefmt-configuration-rules)
7. [extraBuildAttrs Merge Rules](#extrabuildattrs-merge-rules)
8. [CI-friendly options](#ci-friendly-options)

---

## Common Error Patterns

### 1. Checks inside treefmt block

**Wrong:**

```nix
treefmt = {
  projectRootFile = "go.mod";
  programs.gofumpt.enable = true;
};
checks.format = config.treefmt.build.check self;  # ← This is INSIDE treefmt's scope!
};
```

**Right:**

```nix
treefmt = {
  projectRootFile = "go.mod";
  programs.gofumpt.enable = true;
};

checks = {
  format = config.treefmt.build.check self;
  build = config.packages.default;
};
```

### 2. config/self outside perSystem

**Wrong:** `config` and `self` only exist inside `perSystem`.

**Right:** Always place `checks`, `packages`, etc. inside the `perSystem` block:

```nix
perSystem = { config, pkgs, lib, system, ... }: {
  # `self` is the module-scope binding (from `inputs@{ self, ... }`), not a
  # perSystem argument — do NOT destructure it here.
  checks = { format = config.treefmt.build.check self; };
};
```

### 3. goPkg = goPkg self-reference

**Wrong:**

```nix
let goPkg = goPkg; in
```

**Right:**

```nix
let goPkg = pkgs.go_1_26; in
```

### 4. Duplicate checks attributes

**Wrong:**

```nix
checks.build = config.packages.default;
checks = { format = ...; };  # ← Overwrites the build check!
```

**Right:**

```nix
checks = {
  format = config.treefmt.build.check self;
  build = config.packages.default;
};
```

### 5. Formatter outside programs

**Wrong:**

```nix
treefmt = {
  nixfmt.enable = true;  # ← Wrong level
};
```

**Right:**

```nix
treefmt = {
  programs.nixfmt.enable = true;
};
```

### 6. Missing pkgs. prefix

**Wrong:** `packages = [ templ gotools ];`

**Right:** `packages = [ pkgs.templ pkgs.gotools ];`

### 7. outputs = inputs: missing self

**Wrong:**

```nix
outputs = inputs: flake-parts.lib.mkFlake { inherit inputs; } {
```

**Right:**

```nix
outputs = inputs@{ self, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
```

---

## Correct Template Structure

See `templates/go-flake-parts/flake.nix` for the gold standard. Key sections in order:

1. `inputs` — nixpkgs, flake-parts, go-nix-helpers (treefmt-nix + systems bundled)
2. `outputs` with `inputs@{ self, ... }`
3. `perSystem` with destructured `{ config, pkgs, lib, system, ... }`
4. `let` block: `goPkg`, `version`, `ldflags`, `vendorHash`, `buildGoModule`
5. `packages` — `default` + named package
6. `apps` — `default`, `test`, `lint`
7. `devShells` — `default` (with compiler), `ci` (mkShellNoCC)
8. `checks` — single attrset with `format`, `build`, `test`
9. `treefmt` — `programs.X.enable`
10. `flake.overlays.default` — at module level (outside perSystem)

---

## Unfree Packages Pattern

For projects needing unfree packages (e.g., AutoCart):

```nix
outputs = inputs@{ self, ... }:
flake-parts.lib.mkFlake { inherit inputs; } {
  systems = import inputs.systems;
  imports = [ inputs.treefmt-nix.flakeModule ];

  # Shadow pkgs with unfree-allowing version
  _module.args.pkgs = import inputs.nixpkgs {
    localSystem.system = "x86_64-linux";
    config.allowUnfree = true;
  };

  perSystem = { config, pkgs, lib, ... }: {
    # ... rest of config
  };
};
```

**Critical:** Must use `_module.args.pkgs` to shadow the default. Using a separate variable name (like `unfreePkgs`) causes infinite recursion.

---

## Private Go Dependencies

Use `go-nix-helpers` `mkPreparedSource` for injecting private Go modules into the Nix sandbox:

```nix
mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
  inherit pkgs lib;
  inherit goPkg;
};

preparedSrc = mkPreparedSource {
  name = "my-project";
  inherit version;
  src = lib.cleanSource ./.;
  deps = {
    "github.com/larsartmann/go-finding" = go-finding;
  };
};
```

Reference implementations: `go-structure-linter`, `mr-sync`.

---

## Checks Placement Rules

1. **Always use a single `checks = { ... }` attrset**
2. **Never use dot-notation** (`checks.X = ...`) outside the attrset
3. **Never place inside treefmt or other blocks**
4. **Always include both `format` and `build`**
5. **`config` and `self` must be in perSystem's destructured args**

---

## treefmt Configuration Rules

1. **All formatters go inside `programs`:** `treefmt.programs.gofumpt.enable = true`
2. **Standard formatters for Go projects:** gofumpt, goimports, nixfmt
3. **For templ projects, add:** `programs.templ.enable = true`
4. **Never use bare names:** `treefmt.nixfmt.enable` is WRONG

---

## extraBuildAttrs Merge Rules

Six attributes in `extraBuildAttrs` are **concatenated** with the module's
values (not overridden). All other attributes override via `//`.

| Attribute             | Direction  | Module provides                                     |
| --------------------- | ---------- | --------------------------------------------------- |
| `nativeBuildInputs`   | Appended   | `templ`, `installShellFiles` (when enabled)         |
| `buildInputs`         | Appended   | (none by default)                                   |
| `checkInputs`         | Appended   | (none by default)                                   |
| `configureFlags`      | Appended   | (none by default)                                   |
| `preBuild`            | Appended   | Auto dep-sync logic when `deps` are set (runs first) |
| `postInstall`         | Appended   | Shell completion installation when `enableCompletions` (runs first) |

**Correct — your values are added to the module's:**

```nix
go-standard = {
  extraBuildAttrs = {
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.sqlite ];
    # These APPEND to the module's lists, not replace them.
  };
};
```

**All other attrs override (standard `//` merge):**

```nix
go-standard = {
  extraBuildAttrs = {
    doCheck = false;       # Overrides module default (true)
    installPhase = "...";   # Overrides buildGoModule default
  };
};
```

### Per-package extraBuildAttrs (G2)

Each entry in the `packages` submodule can carry its own `extraBuildAttrs`.
Per-package values are **appended** to top-level values for the six concat
keys, and **override** for all others.

```nix
go-standard = {
  extraBuildAttrs.nativeBuildInputs = [ pkgs.git ];  # applies to ALL packages

  packages = {
    worker = {
      subPackages = [ "cmd/worker" ];
      # nativeBuildInputs = [ pkgs.git, pkgs.makeWrapper ]  (top-level + per-package)
      # ldflags overrides top-level entirely (non-concat key)
      extraBuildAttrs.ldflags = [ "-X main.mode=worker" ];
    };
  };
};
```

---

## CI-friendly options

### `lintAsCheck` — hermetic lint check

```nix
go-standard.lintAsCheck = true;
# Produces checks.lint (gated on enableGolangciLint = true)
# Use when CI requires a derivation, not just an app
```

### `enableTestCheck` — hermetic test check

```nix
go-standard = {
  enableCheck = false;    # skip tests during normal builds (faster)
  enableTestCheck = true; # but still run tests in CI via nix flake check
};
```

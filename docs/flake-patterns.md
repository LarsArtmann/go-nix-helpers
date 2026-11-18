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
9. [OCI Container Pattern](#oci-container-pattern)
10. [Nix 2.34 tryEval Assertion Pattern](#nix-234-tryeval-assertion-pattern)

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
let goPkg = pkgs.go_1_27; in
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

See `templates/go-standard/flake.nix` for the gold standard. Key sections in order:

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

| Attribute           | Direction | Module provides                                                     |
| ------------------- | --------- | ------------------------------------------------------------------- |
| `nativeBuildInputs` | Appended  | `templ`, `installShellFiles` (when enabled)                         |
| `buildInputs`       | Appended  | (none by default)                                                   |
| `checkInputs`       | Appended  | (none by default)                                                   |
| `configureFlags`    | Appended  | (none by default)                                                   |
| `preBuild`          | Appended  | Auto dep-sync logic when `deps` are set (runs first)                |
| `postInstall`       | Appended  | Shell completion installation when `enableCompletions` (runs first) |

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

---

## OCI Container Pattern

Ship images through the `container` option — never a hand-rolled `dockerTools`
block, never a Dockerfile alongside the flake.

**Right:**

```nix
go-standard = {
  container = {
    enable = true;
    cmd = [ "run" "--addr" "0.0.0.0:8097" ];
    exposedPorts = [ "8097/tcp" ];
    volumes = [ "/data" ];
    env.LOG_LEVEL = "info";
  };
};
```

This emits `packages.<pname>-image`, `apps.<pname>-image-load` / `.#<pname>-image-push`
(skopeo, daemon-less), and `checks.container-structure` (a jq gate over the image
asserting non-root user, entrypoint, labels, arch, and layers). Defaults you inherit
without writing anything: user `65532:65532`, cacert + `SSL_CERT_FILE`,
`org.opencontainers.image.*` labels, `/bin/<mainProgram>` entrypoint,
volume dirs pre-created with the right ownership, `maxLayers = 20` for cross-image
layer sharing.

**Wrong — hand-rolled `pkgs.dockerTools` in the consumer flake:**

drifts from the module defaults (no structure check, no layer-sharing profile,
per-repo copy-paste), and duplicates the Go build. The option exists precisely so
this block never appears in a consumer:

```nix
# DON'T: per-repo dockerTools assembly
packages.image = pkgs.dockerTools.buildImage { /* ...50 lines... */ };
```

**Wrong — a Dockerfile next to the flake:** two build systems for one artifact;
the Docker build cannot see `_local_deps/` (private deps) and silently rebuilds
outside the sandbox. Keep a Dockerfile only for tooling that cannot consume OCI
artifacts at all, and treat it as a portability shim, not the source of truth.

### Registry

`container.registry` defaults to `ghcr.io/larsartmann`, assuming GitHub is the
main remote. Forgejo-remote projects must override — point `registry` at the
Forgejo host, or set a registry-less `imageName`. Nix eval cannot see the git
remote, so the choice is always explicit.

### Tag strategy

`container.tag = null` (default) uses nix2container's content-hash tag: the tag
IS the image output hash, so identical closures produce identical tags and
re-deploys are no-ops. Pin a `self.rev`-derived tag (e.g.
`tag = "${self.shortRev or "dirty"}"`) only when an external system needs to
correlate image tags with git revisions — you trade reproducible no-op pushes
for git-readable tags. `created` follows the same logic: zero-epoch default is
byte-reproducible; a real timestamp breaks bit-for-bit rebuilds.

### Multi-arch images (recipe, not an app)

The module emits per-system images (`packages.<system>.<pname>-image`); a
multi-arch manifest LIST is an assembly step over several of them, and
nix2container at the pinned rev (42d1df94) has no manifest-list primitive.
The honest recipe is CI-side, per GitHub's native arm64 runners:

```yaml
# .github/workflows: one job per arch, then a merge job
strategy:
  matrix:
    runner: [ubuntu-latest, ubuntu-24.04-arm]
steps:
  - uses: actions/checkout@v4
  - uses: cachix/install-nix-action@v31
  - run: nix build .#<pname>-image
  - run: nix run .#<pname>-image-load   # needs docker on the runner
  - run: docker tag <image> ghcr.io/<owner>/<name>:${{ github.sha }}-${{ matrix.arch }}
  - run: docker push ...
# merge job:
#   docker manifest create ghcr.io/<owner>/<name>:<tag> \
#     ghcr.io/<owner>/<name>:<sha>-amd64 ghcr.io/<owner>/<name>:<sha>-arm64
#   docker manifest push
```

Building the OTHER arch's image locally (`nix build .#checks.aarch64-linux...`)
needs binfmt/QEMU emulation and a full emulated Go build — a footgun the module
deliberately does not wire into an app. Revisit when nix2container ships a
manifest-list builder.

---

## Nix 2.34 tryEval Assertion Pattern

On Nix 2.34, `tryEval` cannot recover a thrown error's message: `toString` of
the captured value is `""`. Any test that asserts on thrown message content
through `tryEval` is vacuously false or silently green — it has never tested
anything.

**Wrong:**

```nix
assert (builtins.tryEval (bad "input")).value == null
  || builtins.hasInfix "expected message" (toString (builtins.tryEval (bad "input")).value);
# toString of the captured error is "" — the hasInfix can NEVER match
```

**Right — pick one of three anchors:**

```nix
# 1. Assert against the pure message-builder function, not the throw
assert builtins.hasInfix "expected message" (goModFloorMessage "1.30" "1.26");

# 2. Assert on flattened derivation attrs (mkDerivation flattens `env`)
assert drv.CGO_ENABLED == "0";  # NOT `drv ? env` — that key does not survive

# 3. Assert on the throw-site source text itself
assert builtins.hasInfix "is not a generated package" (builtins.readFile ./modules/go-standard.nix);
```

Also mind `or` precedence in the same tests: `x.attr or default == y` parses as
`x.attr or (default == y)` — parenthesize every defaulted comparison:
`(x.program or "MISSING") == value`.

## Tag-pinned Inputs Need Paired Relocks

An input URL carrying a tag (`github:owner/repo/vX.Y.Z`) is FROZEN —
`nix flake update <input>` can never move it. Bump by editing the URL tag
itself. And a tag bump frequently drags siblings: the terraform-diagrams-
aggregator incident (2026-11-18) bumped `samber-do-auditlog` v0.10.0 →
v0.12.3 and the new cmdguard v5 API surface immediately demanded a fresh
vendorHash. The recipe that avoids two failed builds:

```nix
# 1. edit the tag in the input URL
samber-do-auditlog.url = "github:LarsArtmann/samber-do-auditlog/v0.12.3";
```

```bash
# 2. relock, then run the vendorHash dance (or nix run .#update-vendor-hash)
nix flake update samber-do-auditlog
nix run .#update-vendor-hash                        # module app: got: -> flake.nix -> verify
```

The `update-vendor-hash` app (go-standard, `enableUpdateVendorHashApp`)
automates the dummy-hash → build → parse `got:` → substitute → re-verify
sequence and targets the substitution by the OLD hash value, so sibling FOD
lines are never corrupted.

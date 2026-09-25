# go-standard.nix — Standard flake-parts module for LarsArtmann Go projects
#
# Bundles: treefmt-nix (via composite module in flake.nix)
#
# Provides: packages.default, apps.default/test/lint, devShells.default/ci,
#           checks.format/build, checks.templ-committed (eval-time throw when
#           any .templ lacks its committed *_templ.go sibling), treefmt,
#           flake.overlays.default
#
# Usage (consumer's flake.nix — only 3 inputs needed!):
#
#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#     flake-parts = {
#       url = "github:hercules-ci/flake-parts";
#       inputs.nixpkgs-lib.follows = "nixpkgs";
#     };
#     go-nix-helpers = {
#       url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
#       inputs.nixpkgs.follows = "nixpkgs";
#     };
#   };
#
#   outputs = inputs@{ self, ... }:
#     flake-parts.lib.mkFlake { inherit inputs; } {
#       imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];
#       go-standard = {
#         pname = "my-project";
#         vendorHash = "sha256-AAA...";
#         description = "What this project does";
#       };
#     };
{
  config,
  lib,
  inputs,
  self,
  ...
}:
let
  cfg = config.go-standard;

  # Default systems matching github:nix-systems/default, minus x86_64-darwin:
  # Nixpkgs 26.11 (current nixos-unstable) dropped x86_64-darwin support, so
  # evaluating that system fails outright. Consumers no longer need a
  # `systems` flake input (several already overrode systems for exactly
  # this reason — see go-health, go-taskqueue).
  defaultSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
in
{
  options.go-standard = {
    pname = lib.mkOption {
      type = lib.types.str;
      description = "Package name (also used as overlay attr and mainProgram)";
    };

    vendorHash = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Vendor hash for buildGoModule (null = committed vendor/)";
    };

    src = lib.mkOption {
      type = lib.types.path;
      default = self.outPath;
      defaultText = "self.outPath";
      description = "Source path for the Go module (use lib.fileset for filtering)";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "A LarsArtmann Go project";
      description = "Short description for package meta";
    };

    subPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "." ];
      description = "Subpackages to build";
    };

    goPkgAttr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "go_1_27";
      description = ''
        Go package attribute in nixpkgs (e.g. "go_1_27"). null (default)
        auto-selects the newest packaged go_1_XX branch from your nixpkgs,
        so a go.mod floor newer than the pinned default never breaks the
        build. Set goTarballVersion when even the newest branch is too old.
      '';
    };

    goPkgOverride = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      default = pkg: pkg;
      example = lib.literalExpression ''
        pkg: pkg.overrideAttrs (finalAttrs: _prev: {
          version = "1.26.4";
          src = pkgs.fetchurl {
            url = "https://go.dev/dl/go''${finalAttrs.version}.src.tar.gz";
            hash = "sha256-...";
          };
        });
      '';
      description = ''
        Function applied to the Go package selected by `goPkgAttr`.
        Use to build a custom Go toolchain (e.g. a newer patch version
        than nixpkgs ships) without changing the attribute name.
        Example: `goPkgOverride = pkg: pkg.overrideAttrs ...`.
      '';
    };

    # Build Go from the go.dev SOURCE tarball instead of nixpkgs — set when
    # the repo's go.mod floor is newer than every nixpkgs branch. Unlike
    # goPkgOverride this needs no `pkgs` in scope, so consumers can set it at
    # flake level. Takes precedence over goPkgOverride. Drop the setting once
    # the newest nixpkgs go_1_XX branch satisfies the go.mod floor again.
    goTarballVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "1.26.6";
      description = ''
        Exact Go version to build from https://go.dev/dl/go<version>.src.tar.gz
        (e.g. "1.26.6"). Use when the go.mod floor is newer than the newest
        nixpkgs go_1_XX branch and buildGoModule's GOTOOLCHAIN=local forbids
        toolchain auto-downloads. Requires goTarballHash.
      '';
    };

    goTarballHash = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "sha256-oHIcVMaIkBRI13rZs+x+p8R0cwdV/4kTgukuy5P/LLE=";
      description = "SRI hash of the go.dev source tarball pinned by goTarballVersion.";
    };

    lintAsCheck = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Also expose golangci-lint as a `checks.lint` derivation, in addition
        to the `apps.lint` app. Useful for CI pipelines that run
        `nix flake check` and expect a hermetic lint derivation. The lint
        check runs golangci-lint against the package source (with FOD
        vendor/ when deps are set), inheriting the module's source tree.
        Only takes effect when `enableGolangciLint` is true.
      '';
    };

    enableTempl = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include templ in devShells and treefmt";
    };

    enableGovulncheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include govulncheck in the default devShell";
    };

    enableGopls = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include gopls in the default devShell";
    };

    systems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultSystems;
      defaultText = lib.literalExpression ''
        [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ]
      '';
      description = ''
        Systems to build for. Defaults to the standard set from
        github:nix-systems/default minus x86_64-darwin (nixpkgs 26.11+
        dropped x86_64-darwin support). Override to restrict or extend.
        Alternatively, use a `systems` flake input and set
        `go-standard.systems = import inputs.systems;`.
      '';
    };

    enableCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run `go test` during the Nix build (doCheck)";
    };

    enableTestCheck = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Generate `checks.test` — a hermetic derivation that forces `go test`
        regardless of `enableCheck`. Use when you want to skip tests during
        normal builds (`enableCheck = false`) but still run them via
        `nix flake check` in CI.
      '';
    };

    enableOverlay = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to generate flake.overlays.default";
    };

    buildFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra build flags passed to `go build` (e.g. build tags)";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = self.rev or self.dirtyRev or "dev";
      defaultText = lib.literalExpression "self.rev or self.dirtyRev or \"dev\"";
      description = ''
        Version string for the package. Defaults to the git revision.
        Override for custom versioning.
      '';
    };

    enableGolangciLint = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include golangci-lint in devShells and the lint app";
    };

    enableGofumpt = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable gofumpt in treefmt programs";
    };

    enableGoimports = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable goimports in treefmt programs";
    };

    enableNixfmt = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable nixfmt in treefmt programs";
    };

    enableShfmt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable shfmt (shell script formatter) in treefmt programs";
    };

    enableCompletions = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install shell completions (bash, zsh, fish) for the default binary.
        Requires the binary to support `--completion <shell>` subcommand
        (e.g. cobra, urfave/cli). Emits a build-time warning if the binary
        doesn't support completions instead of silently doing nothing.
        See `completionStyle` for cobra-style `completion <shell>` commands.
      '';
    };

    completionStyle = lib.mkOption {
      type = lib.types.enum [
        "flag"
        "subcommand"
      ];
      default = "flag";
      description = ''
        How the binary exposes shell completions (only used when
        enableCompletions is true): "flag" invokes
        `<binary> --completion <shell>` (urfave/cli style, the default);
        "subcommand" invokes `<binary> completion <shell>` (cobra style).
      '';
    };

    goExperiment = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        GOEXPERIMENT setting for the package build AND devShells
        (e.g. "jsonv2"). null leaves the variable unset so the Go
        toolchain's default experiment set applies.
      '';
    };

    cgoEnabled = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        CGO_ENABLED setting for the package build AND devShells.
        null leaves the platform/toolchain default in place.
      '';
    };

    packages = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            subPackages = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "." ];
              description = "Go subPackages to build for this binary";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "A LarsArtmann Go project";
              description = "Short description for this package's meta";
            };
            extraBuildAttrs = lib.mkOption {
              type = lib.types.attrs;
              default = { };
              description = ''
                Per-package extra attributes merged into this entry's buildGoModule.
                Same concatenation semantics as the top-level `extraBuildAttrs`:
                `nativeBuildInputs`, `buildInputs`, `checkInputs`,
                `configureFlags`, `preBuild`, `postInstall` are appended to
                top-level values; all other attrs override.
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        Additional packages for monorepo support.
        When set, generates a separate buildGoModule for each entry,
        all sharing the same source and vendor hash.
        Each entry can carry its own `extraBuildAttrs` for per-binary
        customization (build flags, inputs, phases).

        Example:
        ```
        go-standard.packages = {
          server.subPackages = [ "cmd/server" ];
          worker.subPackages = [ "cmd/worker" ];
          worker.extraBuildAttrs.ldflags = [ "-X main.workerMode=true" ];
        };
        ```
      '';
    };

    deps = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = ''
        Private Go deps for mkPreparedSource.
        When non-empty, the module auto-wires mkPreparedSource and
        auto-injects GOPRIVATE into devShells.
      '';
    };

    subModules = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = ''
        Explicit sub-modules for mkPreparedSource (merged with auto-discovered).
        Rarely needed — auto-discovery handles everything by default.
      '';
    };

    requireDeps = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Manually injected require lines for mkPreparedSource.
        Keys are module paths, values are version strings.
        Used when sub-modules need explicit require entries not in go.mod.
      '';
    };

    postPatchExtra = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Extra postPatch commands for mkPreparedSource (rarely needed)";
    };

    autoGoPrivate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When deps are set, auto-inject GOPRIVATE into devShells to prevent
        Go from trying to reach the public proxy for private repos.
        Uses `privateGlobPattern` (default: LarsArtmann globs) so all repos
        matching the pattern are covered, including those not explicitly
        listed in deps but resolvable via SSH in the devShell.
        Can be overridden via shellExtraEnv.GOPRIVATE if needed.
      '';
    };

    privateGlobPattern = lib.mkOption {
      type = lib.types.str;
      default = "github.com/larsartmann/*,github.com/LarsArtmann/*";
      description = ''
        GOPRIVATE glob pattern used by `autoGoPrivate`.
        Defaults to LarsArtmann repos. Override for other organizations,
        e.g. `"github.com/myorg/*"` or `"github.com/myorg/*,github.com/MyOrg/*"`.
        Only effective when `autoGoPrivate = true` and `deps` is non-empty.
      '';
    };

    validatePrivateDeps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Pass through to mkPreparedSource. When true, build fails with a clear
        error if any private require in go.mod lacks a replace directive.
        Set to false if some LarsArtmann deps are public.
      '';
    };

    privateDepPattern = lib.mkOption {
      type = lib.types.str;
      default = "github\\.com/[Ll]ars[Aa]rtmann/";
      description = ''
        ERE regex matching module paths in go.mod that must have a replace
        directive. Override for other organizations. Default matches all
        LarsArtmann repos.
      '';
    };

    publicDeps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Module paths to exclude from private dependency validation only.
        Use for repos that match privateDepPattern but are actually public
        (served by proxy.golang.org). Versioned-path aware: listing
        "github.com/foo/bar" also excludes "github.com/foo/bar/v2", "/v3", etc.
        Example: [ "github.com/larsartmann/go-atomic-write" ]

        NOTE: This does NOT affect GOPRIVATE. All modules matching
        `privateGlobPattern` are always marked private in devShells.
        This option only suppresses false-positive "missing dep" errors
        during build-time validation.
      '';
    };

    proxyVendor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Pass proxyVendor to buildGoModule (true = vendor via Go proxy)";
    };

    ldflags = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = "Custom ldflags (null = default version-injection flags)";
    };

    extraMeta = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra attributes merged into package meta";
    };

    extraBuildAttrs = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Extra attributes merged into buildGoModule.
        Six attributes receive special concatenation handling:
        - `nativeBuildInputs` — appended to module's list (templ, installShellFiles)
        - `buildInputs` — appended to module's list
        - `checkInputs` — appended to module's list
        - `configureFlags` — appended to module's list
        - `preBuild` — appended after module-generated preBuild (dep-sync runs first)
        - `postInstall` — appended after module-generated postInstall (completion install runs first)
        All other attributes override module defaults via the `//` operator.
      '';
    };

    devShellExtraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      description = "Extra packages for the default devShell (function of pkgs)";
    };

    shellExtraEnv = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra env vars for devShells";
    };
  };

  config = {
    inherit (cfg) systems;

    perSystem =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        inherit (cfg) version;

        pure = import ../pure-functions.nix { inherit lib; };

        # Single declaration site for toolchain resolution — attr pin, auto
        # newest branch, go.dev source tarball, override hook — lives in
        # pure-functions.goBaseFrom (shared with mkGoFlake).
        goPkg = pure.goBaseFrom {
          inherit pkgs;
          inherit (cfg)
            goPkgAttr
            goPkgOverride
            goTarballVersion
            goTarballHash
            ;
        };

        usePreparedSource = cfg.deps != { };

        # Eval-time go.mod floor check: the `go` directive in the consumer's
        # ROOT go.mod must not exceed the resolved toolchain. GOTOOLCHAIN=local
        # (set in all devShells and enforced in the sandbox) forbids toolchain
        # downloads, so a floor above the toolchain is a guaranteed build
        # failure — surface it at eval with an actionable message instead of
        # a cryptic sandbox error at build time.
        goModFloorCheck =
          let
            goModPath = self.outPath + "/go.mod";
          in
          if !builtins.pathExists goModPath then
            null
          else
            let
              goLines = builtins.filter (l: builtins.match "go [0-9].*" l != null) (
                map lib.strings.trim (lib.splitString "\n" (builtins.readFile goModPath))
              );
              floorStr = if goLines == [ ] then null else lib.removePrefix "go " (builtins.head goLines);
              # Numeric components only: custom overrides can carry suffixes
              # ("1.26.4-custom") that would crash fromJSON.
              toNums = v: map builtins.fromJSON (builtins.filter (c: builtins.match "[0-9]+" c != null) (lib.splitVersion v));
              # -1 | 0 | 1, numeric per component; longer list wins on equal
              # prefix ("1.27" < "1.27.1"), matching Go's own comparison.
              cmp =
                a: b:
                if a == [ ] then
                  (if b == [ ] then 0 else -1)
                else if b == [ ] then
                  1
                else if builtins.head a < builtins.head b then
                  -1
                else if builtins.head a > builtins.head b then
                  1
                else
                  cmp (builtins.tail a) (builtins.tail b);
            in
            if floorStr == null then
              null
            else if cmp (toNums floorStr) (toNums goPkg.version) == 1 then
              throw ''
                go-standard: go.mod requires go ${floorStr} but the resolved toolchain is ${goPkg.version} (${if cfg.goPkgAttr != null then cfg.goPkgAttr else "auto"}).
                GOTOOLCHAIN=local forbids toolchain downloads, so every build and devShell `go` invocation would fail.
                Fix one of:
                  1. Pin the newest nixpkgs branch: goPkgAttr = "go_1_XX" (or leave null for auto)
                  2. Build the exact version from source: goTarballVersion = "${floorStr}" + goTarballHash
                  3. Update the nixpkgs input so a newer go_1_XX branch is packaged
              ''
            else
              null;

        preparedSrc =
          if usePreparedSource then
            (import "${inputs.go-nix-helpers}/mkPreparedSource.nix" {
              inherit pkgs lib goPkg;
            })
              {
                name = cfg.pname;
                inherit version;
                inherit (cfg) src;
                inherit (cfg)
                  deps
                  subModules
                  postPatchExtra
                  requireDeps
                  validatePrivateDeps
                  privateDepPattern
                  publicDeps
                  ;
              }
          else
            null;

        finalSrc = if usePreparedSource then preparedSrc else cfg.src;

        buildGoModule = pkgs.buildGoModule.override { go = goPkg; };

        # Warn if vendorHash looks like a placeholder that the consumer
        # forgot to replace with a real hash after initial setup.
        vendorHashWarning =
          if cfg.vendorHash != null && builtins.match "sha256-(AAA[A+/]*=*)" cfg.vendorHash != null then
            builtins.trace "warning: go-standard.vendorHash appears to be a placeholder (${cfg.vendorHash}). Set the real hash after the first build." null
          else
            null;

        # deps (mkPreparedSource) force proxyVendor = false: vendoring must
        # resolve through the injected _local_deps replaces, not the Go proxy.
        # Say so instead of silently flipping the consumer's explicit true.
        proxyVendorWarning =
          if usePreparedSource && cfg.proxyVendor then
            builtins.trace "warning: go-standard.proxyVendor = true is ignored when deps are set — prepared-source builds vendor via the injected _local_deps replaces, never the Go proxy." null
          else
            null;

        # A pinned goPkgAttr older than the newest packaged branch is
        # usually a stale pin — the auto default would resolve newer.
        # Informational only: deliberate old pins (reproducibility) may
        # ignore it.
        stalePinWarning =
          let
            newest = pure.staleGoAttrName { inherit pkgs; goPkgAttr = cfg.goPkgAttr; };
          in
          if newest != null then
            builtins.trace "warning: go-standard.goPkgAttr = \"${cfg.goPkgAttr}\" is not the newest Go in your nixpkgs (\"${newest}\") — bump the pin or drop it to use the auto default." null
          else
            null;

        finalLdflags =
          if cfg.ldflags != null then
            cfg.ldflags
          else
            [
              "-s"
              "-w"
              "-X main.version=${version}"
            ];

        # When using mkPreparedSource, the local copies may introduce
        # transitive deps not in go.mod. The FOD (go-modules derivation)
        # has network access, so we run `go mod tidy` there to resolve
        # them, then propagate the tidied go.mod/go.sum to the main build.
        autoDepFodAttrs = lib.optionalAttrs usePreparedSource {
          modBuildPhase = ''
            runHook preBuild
            export GOCACHE=$TMPDIR/go-cache
            export GOPATH="$TMPDIR/go"
            cd "$modRoot"
            go mod tidy
            go mod vendor
            mkdir -p vendor
            runHook postBuild
          '';
          modInstallPhase = ''
            cp -r --reflink=auto vendor $out
            cp go.mod $out/go.mod
            cp go.sum $out/go.sum
          '';
        };

        # Sync tidied go.mod/go.sum from FOD output to main build directory.
        autoDepSyncPreBuild = lib.optionalString usePreparedSource ''
          if [ -n "''${goModules:-}" ] && [ -f "$goModules/go.mod" ]; then
            cp "$goModules/go.mod" go.mod
            cp "$goModules/go.sum" go.sum
          fi
        '';

        # Merge user's extraBuildAttrs, with special handling for attrs
        # that should be concatenated rather than overridden:
        # - preBuild/postInstall: concatenated with module-generated values
        # - nativeBuildInputs: concatenated (module adds templ, installShellFiles)
        # - buildInputs/checkInputs/configureFlags: concatenated for future-proofing
        # Keys that receive concatenation (not override) in extraBuildAttrs.
        concatKeys = [
          "preBuild"
          "postInstall"
          "nativeBuildInputs"
          "buildInputs"
          "checkInputs"
          "configureFlags"
        ];

        # Reusable package builder for monorepo support.
        # Builds one Go binary with the given name, subPackages, description,
        # and optional per-package extraBuildAttrs (G2).
        # Per-package attrs merge with top-level cfg.extraBuildAttrs:
        # the six concatKeys append per-package values after top-level values;
        # all other keys use per-package override of top-level.
        # joinSnippet merges two shell snippets with a newline separator so a
        # top-level snippet not ending in \n cannot merge with the first line
        # of the per-package snippet into one broken command.
        joinSnippet =
          a: b:
          if a == "" then
            b
          else if b == "" then
            a
          else
            a + "\n" + b;

        # The completion command word: urfave/cli style `--completion <shell>`
        # (flag, default) or cobra style `completion <shell>` (subcommand).
        completionWord = if cfg.completionStyle == "subcommand" then "completion" else "--completion";

        # Go env vars from typed options; empty when both are unset (null).
        # CGO_ENABLED uses Go's canonical 0/1 — NOT toString (Nix's
        # toString false is "", which Go treats as unset, silently
        # re-enabling cgo).
        optionEnv =
          (lib.optionalAttrs (cfg.goExperiment != null) { GOEXPERIMENT = cfg.goExperiment; })
          // (lib.optionalAttrs (cfg.cgoEnabled != null) {
            CGO_ENABLED = if cfg.cgoEnabled then "1" else "0";
          });

        mkGoPackage =
          pkgName: subPkgs: pkgDesc: pkgExtraBuildAttrs:
          let
            topLevel = cfg.extraBuildAttrs;
            perPkg = pkgExtraBuildAttrs;
            combinedConcat = {
              nativeBuildInputs = (topLevel.nativeBuildInputs or [ ]) ++ (perPkg.nativeBuildInputs or [ ]);
              buildInputs = (topLevel.buildInputs or [ ]) ++ (perPkg.buildInputs or [ ]);
              checkInputs = (topLevel.checkInputs or [ ]) ++ (perPkg.checkInputs or [ ]);
              configureFlags = (topLevel.configureFlags or [ ]) ++ (perPkg.configureFlags or [ ]);
              preBuild = joinSnippet (topLevel.preBuild or "") (perPkg.preBuild or "");
              postInstall = joinSnippet (topLevel.postInstall or "") (perPkg.postInstall or "");
            };
            combinedOther =
              (builtins.removeAttrs topLevel concatKeys) // (builtins.removeAttrs perPkg concatKeys);
            completionPostInstall = lib.optionalString cfg.enableCompletions ''
              # Check if the binary supports ${completionWord} before installing.
              # Falls back to a clear warning instead of silently installing
              # empty completion files.
              # timeout prevents a hanging binary from blocking the build.
              if ! timeout 10 $out/bin/${pkgName} ${completionWord} bash >/dev/null 2>&1; then
                echo "" >&2
                echo "=======================================================" >&2
                echo "go-standard: enableCompletions is enabled but ${pkgName}" >&2
                echo "does not support ${cfg.completionStyle}-style completions." >&2
                echo "Shell completions were NOT installed." >&2
                echo "Either set enableCompletions = false, pick the right" >&2
                echo "completionStyle, or ensure the binary uses a framework" >&2
                echo "that supports them (cobra, urfave/cli)." >&2
                echo "=======================================================" >&2
              else
                installShellCompletion --cmd ${pkgName} \
                  --bash <(timeout 10 $out/bin/${pkgName} ${completionWord} bash 2>/dev/null || true) \
                  --zsh <(timeout 10 $out/bin/${pkgName} ${completionWord} zsh 2>/dev/null || true) \
                  --fish <(timeout 10 $out/bin/${pkgName} ${completionWord} fish 2>/dev/null || true)
              fi
            '';
            mergedPostInstall = completionPostInstall + combinedConcat.postInstall;
          in
          buildGoModule (
            {
              pname = pkgName;
              inherit version;
              src = finalSrc;
              inherit (cfg) vendorHash;
              proxyVendor = if usePreparedSource then false else cfg.proxyVendor;
              subPackages = subPkgs;
              doCheck = cfg.enableCheck;
              inherit (cfg) buildFlags;
              ldflags = finalLdflags;
              preBuild = autoDepSyncPreBuild + combinedConcat.preBuild;
              postInstall = mergedPostInstall;
              nativeBuildInputs =
                lib.optionals cfg.enableTempl [ pkgs.templ ]
                ++ lib.optionals cfg.enableCompletions [ pkgs.installShellFiles ]
                ++ combinedConcat.nativeBuildInputs;
              inherit (combinedConcat) buildInputs;
              inherit (combinedConcat) checkInputs;
              inherit (combinedConcat) configureFlags;
              meta = {
                description = pkgDesc;
                license = lib.licenses.mit;
                mainProgram = pkgName;
                maintainers = [
                  {
                    name = "Lars Artmann";
                    github = "LarsArtmann";
                  }
                ];
              }
              // cfg.extraMeta;
            }
            // autoDepFodAttrs
            // combinedOther
            // (lib.optionalAttrs (optionEnv != { }) {
              # Typed options win inside env, but a consumer's own
              # extraBuildAttrs.env keys are preserved.
              env = (combinedOther.env or { }) // optionEnv;
            })
          );

        # Build the default package (always present)
        # vendorHashWarning/proxyVendorWarning/goModFloorCheck/stalePinWarning
        # are referenced here to force evaluation of their checks when
        # packages are evaluated.
        package = builtins.seq goModFloorCheck (
          builtins.seq proxyVendorWarning (
            builtins.seq vendorHashWarning (
              builtins.seq stalePinWarning (mkGoPackage cfg.pname cfg.subPackages cfg.description { })
            )
          )
        );

        # Build extra packages when monorepo config is set
        extraPackages = lib.mapAttrs (
          name: pcfg: mkGoPackage name pcfg.subPackages pcfg.description (pcfg.extraBuildAttrs or { })
        ) cfg.packages;

        templPkg = lib.optionals cfg.enableTempl [ pkgs.templ ];
        goplsPkg = lib.optionals cfg.enableGopls [ pkgs.gopls ];
        vulncheckPkg = lib.optionals cfg.enableGovulncheck [ pkgs.govulncheck ];
        golangciLintPkg = lib.optionals cfg.enableGolangciLint [ pkgs.golangci-lint ];

        mkApp = name: runtimeInputs: text: {
          type = "app";
          program = lib.getExe (pkgs.writeShellApplication { inherit name runtimeInputs text; });
        };

        autoGoPrivateEnv =
          if cfg.deps != { } && cfg.autoGoPrivate then { GOPRIVATE = cfg.privateGlobPattern; } else { };

        finalShellExtraEnv = autoGoPrivateEnv // optionEnv // cfg.shellExtraEnv;
      in
      {
        packages = {
          default = package;
          ${cfg.pname} = package;
        }
        // extraPackages;

        apps = {
          default = {
            type = "app";
            program = lib.getExe config.packages.default;
          };
          test = mkApp "run-test" [ goPkg ] "go test -race -v -coverprofile=coverage.out ./...";
        }
        // lib.optionalAttrs cfg.enableGolangciLint {
          lint = mkApp "run-lint" [
            goPkg
            pkgs.golangci-lint
          ] "golangci-lint run ./...";
        }
        //
          lib.optionalAttrs (cfg.enableGofumpt || cfg.enableGoimports || cfg.enableNixfmt || cfg.enableTempl)
            {
              fmt = {
                type = "app";
                program = lib.getExe (
                  pkgs.writeShellApplication {
                    name = "run-fmt";
                    runtimeInputs = [ config.treefmt.build.wrapper ];
                    text = "treefmt";
                  }
                );
              };
            }
        // lib.mapAttrs' (
          name: pkg:
          lib.nameValuePair name {
            type = "app";
            program = lib.getExe pkg;
          }
        ) extraPackages;

        devShells = {
          default = pkgs.mkShell (
            {
              packages = [
                goPkg
              ]
              ++ golangciLintPkg
              ++ templPkg
              ++ goplsPkg
              ++ vulncheckPkg
              ++ (cfg.devShellExtraPackages pkgs);
              GOWORK = "off";
              GOTOOLCHAIN = "local";
            }
            // finalShellExtraEnv
          );

          ci = pkgs.mkShellNoCC (
            {
              packages = [ goPkg ] ++ golangciLintPkg ++ templPkg;
              GOWORK = "off";
              GOTOOLCHAIN = "local";
            }
            // finalShellExtraEnv
          );
        };

        checks =
          let
            # goimports shells out to `go` for module metadata when it formats
            # files inside a module. The check sandbox has no network, so the
            # `go` on PATH must match the repo's floor exactly (goPkg) and must
            # never try a toolchain auto-download (GOTOOLCHAIN=local) — a floor
            # above the ambient toolchain otherwise fails the check with
            # "go: downloading goX.Y.Z" DNS errors. Applies to BOTH
            # go-standard's checks.format and treefmt-nix's own checks.treefmt
            # (one underlying check, registered twice).
            hermeticTreefmtCheck = (config.treefmt.build.check self).overrideAttrs (old: {
              nativeBuildInputs = [ goPkg ] ++ (old.nativeBuildInputs or [ ]);
              GOTOOLCHAIN = "local";
            });
          in
          {
            format = hermeticTreefmtCheck;
            treefmt = lib.mkForce hermeticTreefmtCheck;
            build = config.packages.default;
          }
          // lib.optionalAttrs (cfg.lintAsCheck && cfg.enableGolangciLint) {
            lint =
              let
                pkg = config.packages.default.overrideAttrs (_old: {
                  pname = "${cfg.pname}-lint";
                  nativeBuildInputs = [
                    goPkg
                    pkgs.golangci-lint
                  ];
                  buildPhase = ''
                    runHook preBuild
                    export HOME=$TMPDIR
                    golangci-lint run ./...
                    runHook postBuild
                  '';
                  doCheck = false;
                  installPhase = "touch $out";
                });
              in
              pkg;
          }
          // lib.optionalAttrs cfg.enableTestCheck {
            test = config.packages.default.overrideAttrs (_old: {
              doCheck = true;
            });
          }
          // (
            let
              # Every .templ file in the flake source must ship its generated
              # *_templ.go sibling. Nix builds vendor the source WITHOUT running
              # `templ generate`, so an untracked generated file breaks the build
              # with `undefined: someFragment`. The flake source contains only
              # TRACKED files, so a missing sibling here means it is not
              # committed to git.
              walkTempl =
                dir:
                lib.concatLists (
                  lib.mapAttrsToList (
                    name: type:
                    let
                      path = dir + "/${name}";
                    in
                    if type == "directory" then
                      # `test-assets` hosts this library's OWN templ-check fixtures
                      # (modules/../test-module.nix walks them via a mock self);
                      # the missing-generated fixture deliberately lacks a
                      # sibling, which must not fail the host repo's own check.
                      (if name == ".git" || name == "test-assets" then [ ] else walkTempl path)
                    else if lib.hasSuffix ".templ" name then
                      [
                        {
                          templ = path;
                          # Path arithmetic ONLY: `dir + "/${...}"` keeps the value
                          # a Nix PATH. Coercing the path to a string first
                          # (`removeSuffix path + "_templ.go"`) builds a
                          # context-carrying STRING, and `builtins.pathExists` on
                          # that realises the context — fatal under
                          # `nix flake check --no-build` on current Nix.
                          generated = dir + "/${lib.removeSuffix ".templ" name}_templ.go";
                        }
                      ]
                    else
                      [ ]
                  ) (builtins.readDir dir)
                );
              templFiles = walkTempl self.outPath;
              missing = builtins.filter (f: !builtins.pathExists f.generated) templFiles;
            in
            lib.optionalAttrs (missing != [ ]) {
              templ-committed = builtins.throw ''
                go-standard: ${toString (builtins.length missing)} .templ file(s) without a committed *_templ.go sibling:
                ${lib.concatStringsSep "\n" (map (f: "  ${toString f.templ}") missing)}

                Nix builds vendor the source without running `templ generate` —
                the build fails with `undefined: someFragment`. Run `templ generate`
                and commit the generated *_templ.go files:
                  git add -- '*_templ.go'
              '';
            }
          );

        treefmt = {
          projectRootFile = "go.mod";
          programs = {
            gofumpt.enable = cfg.enableGofumpt;
            goimports.enable = cfg.enableGoimports;
            nixfmt.enable = cfg.enableNixfmt;
            templ.enable = cfg.enableTempl;
            shfmt.enable = cfg.enableShfmt;
          };
        };
      };

    flake.overlays.default = lib.mkIf cfg.enableOverlay (
      final: _prev:
      {
        ${cfg.pname} = self.packages.${final.stdenv.system}.default;
      }
      // (builtins.mapAttrs (name: _pkg: self.packages.${final.stdenv.system}.${name}) cfg.packages)
    );
  };
}

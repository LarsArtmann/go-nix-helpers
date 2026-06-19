# mkPreparedSource.nix
#
# Prepares Go source with local dependency replacement for Nix sandbox builds.
#
# Problem: Go repos with private dependencies can't fetch them inside the Nix
# sandbox (no SSH, no network for `go mod download`). This helper copies
# flake-input deps into `_local_deps/` and injects `replace` directives into
# go.mod so the Go toolchain resolves them locally.
#
# Key features:
#   - Auto-discovers sub-modules: scans each dep source for subdirectories
#     containing `go.mod` and generates replace directives automatically.
#     No manual `subModules` list needed (though explicit entries are merged).
#   - Build-time validation: verifies every private module require in go.mod
#     has a corresponding replace directive, failing with a clear message
#     instead of a cryptic "could not read Username" SSH error.
#   - /vN major version suffix handling: the /vN suffix is kept in the module
#     path but stripped from the local directory path.
#
# Usage:
#   mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
#     inherit pkgs lib;
#     goPkg = pkgs.go_1_26;
#   };
#   preparedSrc = mkPreparedSource {
#     name = "my-app";
#     version = "1.0.0";
#     src = ./.;
#     deps = {
#       "github.com/larsartmann/go-cqrs-lite" = go-cqrs-lite;
#       "github.com/larsartmann/go-branded-id" = go-branded-id;
#     };
#     # subModules is optional — auto-discovered by default.
#     # postPatchExtra = ''# additional shell commands'';
#   };
#   buildGoModule { src = preparedSrc; vendorHash = "..."; }
#
# Parameters:
#   name                 Derivation name prefix.
#   src                  Source derivation or path (the project root).
#   deps                 Attrset of { "import/path" = flake-input; }.
#
#   version              Version string (default: "dev").
#
#   subModules           Attrset of { "import/path" = [ "sub1" "sub2/v2" ]; }.
#                         Explicit sub-module entries, MERGED with auto-discovered.
#                         Versioned sub-paths (ending in /vN) are handled
#                         automatically — the /vN suffix is kept in the module
#                         path but stripped from the local directory path.
#                         (default: {} — auto-discovery handles everything)
#
#   autoSubModules       When true, scan each dep source for subdirectories
#                         containing go.mod and auto-generate replace directives.
#                         Extra replaces are harmless no-ops for unused modules.
#                         (default: true)
#
#   requireDeps          Attrset of { "import/path" = "version"; } (rarely needed).
#                         Manually inject require lines for sub-modules not yet
#                         in go.mod.
#
#   subModuleVersion     Version for pseudo-version normalization (default: "v0.0.0").
#   stripLocalReplaces   Strip stale `replace X => /home/...` directives (default: true).
#   validatePrivateDeps  Verify every private require has a replace (default: true).
#   postPatchExtra       Additional shell commands appended to postPatch.
{
  pkgs,
  lib,
  goPkg,
}: {
  name,
  src,
  deps,
  version ? "dev",
  subModules ? {},
  autoSubModules ? true,
  requireDeps ? {},
  subModuleVersion ? "v0.0.0",
  stripLocalReplaces ? true,
  validatePrivateDeps ? true,
  postPatchExtra ? "",
}: let
  # ---------------------------------------------------------------------------
  # Path helpers
  # ---------------------------------------------------------------------------

  # Strip trailing /vN major version suffix from a path.
  # "codec/v2" → "codec", "core" → "core"
  stripVersionSuffix = path: let
    parts = lib.splitString "/" path;
    last = lib.last parts;
  in
    if builtins.match "v[0-9]+" last != null
    then lib.concatStringsSep "/" (lib.init parts)
    else path;

  # Extract repo name from Go import path, stripping any /vN major version suffix.
  # "github.com/larsartmann/go-cqrs-lite" → "go-cqrs-lite"
  # "github.com/larsartmann/go-filewatcher/v2" → "go-filewatcher"
  repoName = path: let
    stripped = stripVersionSuffix path;
  in lib.last (lib.splitString "/" stripped);

  # Read the module path from the first non-empty line of a go.mod file.
  # go.mod line 1 is always: "module <import-path>"
  # Returns "" for empty/malformed files.
  readModulePath = goModFile: let
    content = builtins.readFile goModFile;
    lines = lib.splitString "\n" content;
    nonEmpty = lib.filter (l: l != "") lines;
    firstLine =
      if lib.length nonEmpty > 0
      then lib.head nonEmpty
      else "";
    parts = lib.splitString " " firstLine;
  in
    if lib.length parts >= 2
    then lib.elemAt parts 1
    else "";

  # ---------------------------------------------------------------------------
  # Auto-discovery: scan dep source for sub-modules
  # ---------------------------------------------------------------------------

  # Discover sub-modules by scanning a dep source for subdirectories with go.mod.
  # Returns: [ { modulePath, localDir; } ]
  # Example for go-cqrs-lite:
  #   [ { modulePath = ".../catalog/v2"; localDir = "./_local_deps/go-cqrs-lite/catalog"; }
  #     { modulePath = ".../codec/v2";   localDir = "./_local_deps/go-cqrs-lite/codec"; }
  #     ... ]
  discoverSubModules = depPath: depSrc:
    if !autoSubModules
    then []
    else let
      entries = builtins.readDir depSrc;
      dirs = lib.attrNames (lib.filterAttrs (_: type: type == "directory") entries);
      dirsGoMod = lib.filter (dir:
        builtins.pathExists "${depSrc}/${dir}/go.mod"
      ) dirs;
      basename = repoName depPath;
      discover = dir: let
        modulePath = readModulePath "${depSrc}/${dir}/go.mod";
      in {
        inherit modulePath;
        localDir = "./_local_deps/${basename}/${dir}";
      };
    in map discover dirsGoMod;

  # Collect all auto-discovered sub-modules across all deps.
  allDiscovered = lib.flatten (
    lib.mapAttrsToList (depPath: depSrc:
      discoverSubModules depPath depSrc
    ) deps
  );

  # ---------------------------------------------------------------------------
  # Shell script generation
  # ---------------------------------------------------------------------------

  # Copy each dep into _local_deps/<basename>
  copyDeps =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: _: let
          basename = repoName path;
        in ''cp -r ${deps.${path}} _local_deps/${basename}''
      )
      deps);

  # Replace directives for main deps:
  # "github.com/.../go-cqrs-lite" => ./_local_deps/go-cqrs-lite
  replaceLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: _: let
          basename = repoName path;
        in ''echo "  ${path} => ./_local_deps/${basename}" >> go.mod''
      )
      deps);

  # Replace directives for explicit subModules:
  # "github.com/.../go-cqrs-lite/codec/v2" => ./_local_deps/go-cqrs-lite/codec
  subModuleReplaceExplicit =
    lib.concatStringsSep "\n"
    (lib.concatLists (
      lib.mapAttrsToList (
        depPath: subs:
          map (sub: let
            basename = repoName depPath;
            localSub = stripVersionSuffix sub;
          in ''echo "  ${depPath}/${sub} => ./_local_deps/${basename}/${localSub}" >> go.mod'')
          subs
      )
      subModules
    ));

  # Replace directives for auto-discovered sub-modules:
  # "github.com/.../codec/v2" => ./_local_deps/go-cqrs-lite/codec
  subModuleReplaceAuto =
    lib.concatStringsSep "\n"
    (map (
        sm: ''echo "  ${sm.modulePath} => ${sm.localDir}" >> go.mod''
      )
      allDiscovered);

  # Deduplicate: merge explicit + auto, remove exact-duplicate echo lines.
  # Go ignores duplicate replace directives, but keeping them clean is nicer.
  allSubModuleReplace =
    lib.concatStringsSep "\n"
    (lib.unique (
      lib.splitString "\n" subModuleReplaceExplicit
      ++ lib.splitString "\n" subModuleReplaceAuto
    ));

  # Require lines for manually injected deps (rarely needed).
  extraRequireLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: ver: ''echo "	${path} ${ver}" >> go.mod''
      )
      requireDeps);

  hasRequires = requireDeps != {};

  # Normalize pseudo-versions for explicit sub-modules.
  # Replaces "v0.0.0-20260101000000-abc123" with "v0.0.0" so replace directives match.
  subModuleVersionNormalize =
    lib.concatStringsSep "\n"
    (lib.concatLists (
      lib.mapAttrsToList (
        depPath: subs:
          map (sub: ''
            sed -i 's|${depPath}/${sub} v0\.0\.0-[^ ]*|${depPath}/${sub} ${subModuleVersion}|g' go.mod
          '')
          subs
      )
      subModules
    ));

  # Normalize pseudo-versions for auto-discovered sub-modules.
  autoVersionNormalize =
    lib.concatStringsSep "\n"
    (map (
        sm: ''
          sed -i 's|${sm.modulePath} v0\.0\.0-[^ ]*|${sm.modulePath} ${subModuleVersion}|g' go.mod
        ''
      )
      allDiscovered);

  # Strip stale `replace X => /home/...` directives (leftover dev artifacts).
  stripLocalReplacesScript = ''
    sed -i '/=> \/home\//d' go.mod
    sed -i '/^replace ($/{N;/\n)$/d}' go.mod
  '';

  # Build-time validation: verify every private module require has a replace.
  # Produces a clear error listing missing deps instead of the cryptic
  # "could not read Username for 'https://github.com'" SSH error.
  validateScript = ''
    if [ -f go.mod ]; then
      MISSING=""
      # Extract private module paths from require blocks only.
      # Skip the "module" declaration line and replace/exclude blocks.
      REQUIRED=$(
        awk '
          /^require[[:space:]]*\(/{inreq=1; next}
          /^\)/{inreq=0; next}
          /^require[[:space:]]+[^(]/{if(!inreq){print $2; next}}
          inreq{print $1}
        ' go.mod | grep -E 'github\.com/[Ll]ars[Aa]rtmann/' | sort -u
      )
      for mod in $REQUIRED; do
        if ! grep -qF "  $mod => " go.mod; then
          MISSING="''${MISSING}
      $mod"
        fi
      done
      if [ -n "''${MISSING# }" ]; then
        echo ""
        echo "=======================================================" >&2
        echo "mkPreparedSource: private modules without local replace:" >&2
        echo "$MISSING" >&2
        echo "" >&2
        echo "These modules are required in go.mod but have no replace" >&2
        echo "directive. Add the missing repos to your flake.nix inputs" >&2
        echo "and deps map." >&2
        echo "=======================================================" >&2
        exit 1
      fi
    fi
  '';
in
  pkgs.stdenv.mkDerivation {
    pname = "${name}-prepared-source";
    inherit version src;

    dontBuild = true;
    nativeBuildInputs = [goPkg];

    postPatch = ''
      mkdir -p _local_deps
      ${copyDeps}
      chmod -R u+w _local_deps

      ${lib.optionalString stripLocalReplaces stripLocalReplacesScript}

      ${postPatchExtra}

      ${subModuleVersionNormalize}
      ${autoVersionNormalize}

      ${lib.optionalString hasRequires ''
        echo "" >> go.mod
        echo 'require (' >> go.mod
        ${extraRequireLines}
        echo ')' >> go.mod
      ''}

      if [ -n "$(cat go.mod | tr -d '\n')" ]; then
        echo "" >> go.mod
      fi
      echo 'replace (' >> go.mod
      ${replaceLines}
      ${allSubModuleReplace}
      echo ')' >> go.mod

      ${lib.optionalString validatePrivateDeps validateScript}
    '';

    installPhase = ''
      mkdir $out
      cp -r . $out/
    '';
  }

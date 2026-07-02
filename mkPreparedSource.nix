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
#   - Recursive auto-discovery: walks each dep source recursively to find
#     ALL go.mod files at any depth (not just top-level) and generates replace
#     directives automatically. Excludes example/testdata/vendor directories.
#     No manual `subModules` list needed (though explicit entries are merged).
#   - Build-time validation: verifies every private module require in go.mod
#     has a corresponding replace directive, failing with a clear message
#     instead of a cryptic "could not read Username" SSH error.
#   - /vN major version suffix handling: ALL /vN segments are stripped from
#     local directory paths (e.g. "event/v3/eventtest" → "event/eventtest"),
#     while the full versioned path is kept in replace directives.
#   - Strips stale local-path replaces: all absolute (/home/...) and relative
#     (./..., ../...) replace directives are removed before mkPreparedSource
#     appends its own ./_local_deps/ replaces.
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
#   autoSubModules       When true, recursively scan each dep source for ALL
#                         go.mod files (at any depth) and auto-generate replace
#                         directives. Only submodules referenced in go.mod or
#                         go.sum are kept — unused replaces break Go's vendor
#                         consistency check. (default: true)
#
#   excludeSubModuleDirs Directory names to skip during recursive auto-discovery
#                         (default: ["example" "examples" "testdata" ".git"
#                          "vendor" "node_modules"]).
#
#   requireDeps          Attrset of { "import/path" = "version"; } (rarely needed).
#                         Manually inject require lines for sub-modules not yet
#                         in go.mod.
#
#   subModuleVersion     Version for pseudo-version normalization (default: "v0.0.0").
#   stripLocalReplaces   Strip stale local-path replace directives (default: true).
#   validatePrivateDeps  Verify every private require has a replace (default: true).
#   privateDepPattern    ERE regex matching private module paths in go.mod that must
#                        have a replace directive (default: "github\\.com/[Ll]ars[Aa]rtmann/").
#                        Override to support deps outside the LarsArtmann org.
#   postPatchExtra       Additional shell commands appended to postPatch.
{
  pkgs,
  lib,
  goPkg,
}:
{
  name,
  src,
  deps,
  version ? "dev",
  subModules ? { },
  autoSubModules ? true,
  excludeSubModuleDirs ? [
    "example"
    "examples"
    "testdata"
    ".git"
    "vendor"
    "node_modules"
  ],
  requireDeps ? { },
  subModuleVersion ? "v0.0.0",
  stripLocalReplaces ? true,
  validatePrivateDeps ? true,
  privateDepPattern ? "github\\.com/[Ll]ars[Aa]rtmann/",
  postPatchExtra ? "",
}:
let
  # ---------------------------------------------------------------------------
  # Path helpers
  # ---------------------------------------------------------------------------

  # Strip ALL /vN major version suffixes from a path — not just trailing.
  # "codec/v2" → "codec", "event/v3/eventtest" → "event/eventtest", "core" → "core"
  stripVersionSuffix =
    path:
    let
      parts = lib.splitString "/" path;
    in
    lib.concatStringsSep "/" (lib.filter (p: builtins.match "v[0-9]+" p == null) parts);

  # Extract repo name from Go import path, stripping any /vN major version suffix.
  # "github.com/larsartmann/go-cqrs-lite" → "go-cqrs-lite"
  # "github.com/larsartmann/go-filewatcher/v2" → "go-filewatcher"
  repoName =
    path:
    let
      stripped = stripVersionSuffix path;
    in
    lib.last (lib.splitString "/" stripped);

  # Read the module path from the first non-empty line of a go.mod file.
  # go.mod line 1 is always: "module <import-path>"
  # Returns "" for empty/malformed files.
  readModulePath =
    goModFile:
    let
      content = builtins.readFile goModFile;
      lines = lib.splitString "\n" content;
      nonEmpty = lib.filter (l: l != "") lines;
      firstLine = if lib.length nonEmpty > 0 then lib.head nonEmpty else "";
      parts = lib.splitString " " firstLine;
    in
    if lib.length parts >= 2 then lib.elemAt parts 1 else "";

  # ---------------------------------------------------------------------------
  # Auto-discovery: scan dep source for sub-modules
  # ---------------------------------------------------------------------------

  # Discover sub-modules by recursively scanning a dep source for go.mod files
  # at ANY depth (not just top-level). Returns: [ { modulePath, localDir; } ]
  # Example for go-cqrs-lite:
  #   [ { modulePath = ".../catalog/v2";           localDir = "./_local_deps/go-cqrs-lite/catalog"; }
  #     { modulePath = ".../event/v3/eventtest";   localDir = "./_local_deps/go-cqrs-lite/event/eventtest"; }
  #     { modulePath = ".../storage/memory/v3";    localDir = "./_local_deps/go-cqrs-lite/storage/memory"; }
  #     ... ]
  discoverSubModules =
    depPath: depSrc:
    if !autoSubModules then
      [ ]
    else
      let
        # Recursively walk the dep tree, collecting relative paths to every
        # directory that contains a go.mod (excluding the dep root itself
        # and excluded directories like example/testdata/vendor).
        walk =
          dir:
          let
            entries = builtins.readDir dir;
            allDirs = lib.attrNames (lib.filterAttrs (_: type: type == "directory") entries);
            dirs = lib.filter (d: !(lib.elem d excludeSubModuleDirs)) allDirs;
            subs = lib.flatten (map (d: walk "${dir}/${d}") dirs);
          in
          if builtins.pathExists "${dir}/go.mod" && dir != rootDir then
            [ (lib.removePrefix (rootDir + "/") dir) ] ++ subs
          else
            subs;
        rootDir = toString depSrc;
        found = walk rootDir;
        basename = repoName depPath;
      in
      map (rel: {
        modulePath = readModulePath "${depSrc}/${rel}/go.mod";
        localDir = "./_local_deps/${basename}/${rel}";
      }) found;

  # Collect all auto-discovered sub-modules across all deps, filtered to only
  # those whose modulePath appears in go.mod or go.sum. Extra replaces for
  # unused modules break Go's vendor consistency check when proxyVendor=false
  # ("X is replaced in go.mod, but not marked as replaced in vendor/modules.txt").
  allDiscoveredRaw = lib.flatten (
    lib.mapAttrsToList (depPath: depSrc: discoverSubModules depPath depSrc) deps
  );

  # Read go.mod and go.sum to determine which modules are actually imported.
  goModContent =
    if builtins.pathExists "${src}/go.mod"
    then builtins.readFile "${src}/go.mod"
    else "";
  goSumContent =
    if builtins.pathExists "${src}/go.sum"
    then builtins.readFile "${src}/go.sum"
    else "";
  depReferenceText = goModContent + "\n" + goSumContent;

  allDiscovered = lib.filter (sm: sm.modulePath != "" && lib.hasInfix sm.modulePath depReferenceText) allDiscoveredRaw;

  # ---------------------------------------------------------------------------
  # Shell script generation
  # ---------------------------------------------------------------------------

  # Copy each dep into _local_deps/<basename>
  copyDeps = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      path: _:
      let
        basename = repoName path;
      in
      "cp -r ${deps.${path}} _local_deps/${basename}"
    ) deps
  );

  # Replace directives for main deps:
  # "github.com/.../go-cqrs-lite" => ./_local_deps/go-cqrs-lite
  replaceLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      path: _:
      let
        basename = repoName path;
      in
      ''echo "  ${path} => ./_local_deps/${basename}" >> go.mod''
    ) deps
  );

  # Unify explicit subModules into the same {modulePath, localDir} shape as
  # auto-discovered entries. Both sources then share ONE replace generator and
  # ONE version normalizer — eliminating the split brain where /vN handling
  # and dedup logic had to be maintained in two parallel code paths.
  explicitSubModules = lib.flatten (
    lib.mapAttrsToList (
      depPath: subs:
      map (sub: {
        modulePath = "${depPath}/${sub}";
        localDir = "./_local_deps/${repoName depPath}/${stripVersionSuffix sub}";
      }) subs
    ) subModules
  );

  # Merged + deduplicated sub-module list (explicit entries first).
  allSubModules = lib.unique (explicitSubModules ++ allDiscovered);

  # Single replace-directive generator for ALL sub-modules (explicit + auto).
  # "github.com/.../codec/v2" => ./_local_deps/go-cqrs-lite/codec
  allSubModuleReplace = lib.concatStringsSep "\n" (
    map (sm: ''echo "  ${sm.modulePath} => ${sm.localDir}" >> go.mod'') allSubModules
  );

  # Require lines for manually injected deps (rarely needed).
  extraRequireLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (path: ver: ''echo "	${path} ${ver}" >> go.mod'') requireDeps
  );

  hasRequires = requireDeps != { };

  # Normalize pseudo-versions for ALL sub-modules so replace directives match.
  # Replaces "v0.0.0-20260101000000-abc123" with "v0.0.0".
  subModuleVersionNormalize = lib.concatStringsSep "\n" (
    map (sm: ''
      sed -i 's|${sm.modulePath} v0\.0\.0-[^ ]*|${sm.modulePath} ${subModuleVersion}|g' go.mod
    '') allSubModules
  );

  # Strip replace directives that point OUTSIDE the prepared source tree,
  # where the path cannot exist inside the Nix sandbox:
  #   - absolute paths (=> /home/..., => /tmp/...)  — dev-machine leftovers
  #   - sibling/parent dirs (=> ../sibling)          — resolved via _local_deps
  # In-tree replaces (=> ./submodule) are PRESERVED: the source tree is copied
  # wholesale into the prepared source, so those paths resolve correctly.
  # mkPreparedSource appends fresh ./_local_deps/ replaces after this runs.
  stripLocalReplacesScript = ''
    sed -i '/=> \//d' go.mod
    sed -i '/=> \.\.\//d' go.mod
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
        ' go.mod | grep -E '${privateDepPattern}' | sort -u
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
  nativeBuildInputs = [ goPkg ];

  postPatch = ''
    mkdir -p _local_deps
    ${copyDeps}
    chmod -R u+w _local_deps

    ${lib.optionalString stripLocalReplaces stripLocalReplacesScript}

    ${postPatchExtra}

    ${subModuleVersionNormalize}

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

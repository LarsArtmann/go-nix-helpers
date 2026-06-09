# Reusable `mkPreparedSource` helper for private Go repo overlays
#
# Problem: Go repos with private dependencies can't fetch them inside the Nix
# sandbox (no SSH, no network for go mod download). Solution: fetch deps as
# flake inputs, copy them into _local_deps/, add `replace` directives to go.mod.
#
# Usage (add as `flake = false` input, then import):
#   mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
#     inherit pkgs lib;
#     goPkg = pkgs.go_1_26;
#   };
#   preparedSrc = mkPreparedSource {
#     name = "my-app";
#     version = "dev";
#     src = srcFiltered;
#     deps = {
#       "github.com/larsartmann/go-output" = go-output;
#       "github.com/larsartmann/go-branded-id" = go-branded-id;
#       "github.com/larsartmann/go-filewatcher/v2" = go-filewatcher;
#     };
#     subModules = {
#       "github.com/larsartmann/go-output" = [ "enum" "escape" "sort" "table" ];
#       "github.com/larsartmann/go-cqrs-lite" = [ "codec/v2" "command/v2" "core" ];
#     };
#     postPatchExtra = ''
#       # Additional custom commands
#     '';
#   };
#   buildGoModule { src = preparedSrc; vendorHash = "..."; }
#
# Parameters:
#   - name: derivation name prefix
#   - version: version string (default: "dev")
#   - src: source derivation/path
#   - deps: attrset of { "import/path" = flake-input; }
#   - subModules: attrset of { "import/path" = [ "sub1" "sub2/v2" ]; } (optional)
#     Auto-generates `replace` directives and normalizes pseudo-versions for each sub-module.
#     Versioned sub-paths (ending in /vN) are handled automatically: the /vN suffix
#     is kept in the module path but stripped from the local directory path.
#     e.g. "codec/v2" → replace directive: `.../codec/v2 => ./_local_deps/<repo>/codec`
#   - requireDeps: attrset of { "import/path" = "version"; } (optional, rarely needed)
#     Manually inject require lines. Use for sub-modules not yet in go.mod.
#   - subModuleVersion: version for pseudo-version normalization (default: "v0.0.0")
#   - stripLocalReplaces: strip stale `replace X => /home/...` directives from go.mod (default: true)
#   - postPatchExtra: additional shell commands (optional)
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
  requireDeps ? {},
  subModuleVersion ? "v0.0.0",
  stripLocalReplaces ? true,
  postPatchExtra ? "",
}: let
  # Strip trailing /vN major version suffix from a path
  stripVersionSuffix = path: let
    parts = lib.splitString "/" path;
    last = lib.last parts;
  in
    if builtins.match "v[0-9]+" last != null
    then lib.concatStringsSep "/" (lib.init parts)
    else path;

  # Extract repo name from Go import path, stripping any /vN major version suffix
  repoName = path: let
    stripped = stripVersionSuffix path;
  in lib.last (lib.splitString "/" stripped);

  copyDeps =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: _: let
          basename = repoName path;
        in ''cp -r ${deps.${path}} _local_deps/${basename}''
      )
      deps);

  replaceLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: _: let
          basename = repoName path;
        in ''echo "  ${path} => ./_local_deps/${basename}" >> go.mod''
      )
      deps);

  subModuleReplace =
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

  extraRequireLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: ver: ''echo "	${path} ${ver}" >> go.mod''
      )
      requireDeps);

  hasRequires = requireDeps != {};

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

  stripLocalReplacesScript = ''
    # Strip replace directives pointing to local home directories (stale dev artifacts)
    sed -i '/=> \/home\//d' go.mod
    # Remove replace blocks that became empty after stripping
    sed -i '/^replace ($/{N;/\n)$/d}' go.mod
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
      ${subModuleReplace}
      echo ')' >> go.mod
    '';

    installPhase = ''
      mkdir $out
      cp -r . $out/
    '';
  }

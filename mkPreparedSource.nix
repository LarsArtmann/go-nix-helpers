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
#     };
#     subModules = {
#       "github.com/larsartmann/go-output" = [ "enum" "escape" "sort" "table" ];
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
#   - subModules: attrset of { "import/path" = [ "sub1" "sub2" ]; } (optional)
#     Auto-generates both `require` and `replace` directives for each sub-module.
#   - requireDeps: attrset of { "import/path" = "version"; } (optional, rarely needed)
#     Manually inject require lines — prefer subModules which auto-generates them.
#   - subModuleVersion: version for auto-generated sub-module require lines (default: "v0.0.0")
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
  copyDeps =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: _: let
          basename = lib.last (lib.splitString "/" path);
        in ''cp -r ${deps.${path}} _local_deps/${basename}''
      )
      deps);

  replaceLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (
        path: _: let
          basename = lib.last (lib.splitString "/" path);
        in ''echo "  ${path} => ./_local_deps/${basename}" >> go.mod''
      )
      deps);

  subModuleReplace =
    lib.concatStringsSep "\n"
    (lib.concatLists (
      lib.mapAttrsToList (
        depPath: subs:
          map (sub: let
            basename = lib.last (lib.splitString "/" depPath);
          in ''echo "  ${depPath}/${sub} => ./_local_deps/${basename}/${sub}" >> go.mod'')
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

  subModuleRequire =
    lib.concatStringsSep "\n"
    (lib.concatLists (
      lib.mapAttrsToList (
        depPath: subs:
          map (sub: let
            fullPath = "${depPath}/${sub}";
          in ''
            if ! grep -q '${fullPath} ' go.mod; then
              echo '	${fullPath} ${subModuleVersion} // indirect' >> go.mod
            fi
          '')
          subs
      )
      subModules
    ));

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

      ${subModuleRequire}

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

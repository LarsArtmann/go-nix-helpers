# pure-functions.nix
#
# Pure utility functions extracted from mkPreparedSource for testability.
# These functions have no side effects and can be unit-tested directly.
{ lib, ... }:
let
  # Strip ALL /vN major version suffixes from a path — not just trailing.
  # "codec/v2" → "codec", "event/v3/eventtest" → "event/eventtest", "core" → "core"
  stripVersionSuffix =
    path:
    let
      parts = lib.splitString "/" path;
    in
    lib.concatStringsSep "/" (lib.filter (p: builtins.match "v[0-9]+" p == null) parts);

  # Extract a unique directory name from a Go import path, stripping any
  # /vN major version suffix.
  # "github.com/larsartmann/go-cqrs-lite" → "go-cqrs-lite"
  # "github.com/larsartmann/go-filewatcher/v2" → "go-filewatcher"
  repoName =
    path:
    let
      stripped = stripVersionSuffix path;
      parts = lib.splitString "/" stripped;
    in
    if lib.length parts >= 3 then lib.elemAt parts 2 else lib.last parts;

  # Pick the newest "go_1_XX" attribute name from a list of attr names.
  # "go_1_27" beats "go_1_26"; non-branch attrs ("go", "gopls", "go_1_27-foo")
  # are ignored. Comparison is numeric, not lexicographic (go_1_10 > go_1_9).
  # Returns null when the list contains no branch attr at all.
  newestGoAttrName =
    names:
    let
      branchAttrs = builtins.filter (name: builtins.match "go_1_[0-9]+" name != null) names;
      minor = name: builtins.fromJSON (lib.last (lib.splitString "_" name));
    in
    if branchAttrs == [ ] then null else lib.last (lib.sort (a: b: minor a < minor b) branchAttrs);

  # Stale-pin decision for the go-standard warning: when goPkgAttr pins a
  # REAL but non-newest go_1_XX branch, return the newest branch name (the
  # warning payload). null when the pin is null, already newest, absent
  # from pkgs (a different error), or no branch attrs exist at all. Kept
  # pure so tests assert the decision without capturing stderr.
  staleGoAttrName =
    {
      pkgs,
      goPkgAttr,
    }:
    let
      newest = newestGoAttrName (builtins.attrNames pkgs);
    in
    if goPkgAttr == null || newest == null || goPkgAttr == newest then null
    else if pkgs ? ${goPkgAttr} then newest
    else null;

  # Actionable error message for the eval-time go.mod floor check. Kept
  # pure so tests can assert the actual message content (tryEval cannot
  # recover thrown messages — toString of a captured error is "").
  goModFloorMessage =
    {
      floorStr,
      toolchainVersion,
      goPkgAttr ? null,
    }:
    ''
      go-standard: go.mod requires go ${floorStr} but the resolved toolchain is ${toolchainVersion} (${if goPkgAttr != null then goPkgAttr else "auto"}).
      GOTOOLCHAIN=local forbids toolchain downloads, so every build and devShell `go` invocation would fail.
      Fix one of:
        1. Pin the newest nixpkgs branch: goPkgAttr = "go_1_XX" (or leave null for auto)
        2. Build the exact version from source: goTarballVersion = "${floorStr}" + goTarballHash
        3. Update the nixpkgs input so a newer go_1_XX branch is packaged
    '';

  # Resolve the Go toolchain package from consumer options — the single
  # declaration site shared by the go-standard module and mkGoFlake.
  #   goPkgAttr:          explicit nixpkgs attr ("go_1_27") wins; null picks
  #                       the newest packaged go_1_XX branch (newestGoAttrName)
  #                       and falls back to pkgs.go when no branch attr exists.
  #   goTarballVersion/Hash: build go from the go.dev source tarball on top of
  #                       the resolved base — the declarative, pkgs-scope-free
  #                       way to outrun a lagging nixpkgs go.
  #   goPkgOverride:      last-chance override hook, applied only when no
  #                       tarball is set (the tarball wins over it).
  goBaseFrom =
    {
      pkgs,
      goPkgAttr ? null,
      goPkgOverride ? (pkg: pkg),
      goTarballVersion ? null,
      goTarballHash ? null,
    }:
    let
      goBase =
        if goPkgAttr != null then
          pkgs.${goPkgAttr}
        else
          let
            newest = newestGoAttrName (builtins.attrNames pkgs);
          in
          if newest == null then pkgs.go else pkgs.${newest};
    in
    if goTarballVersion != null then
      if goTarballHash == null then
        throw "goTarballHash is required when goTarballVersion is set"
      else
        goBase.overrideAttrs (
          finalAttrs: prevAttrs: {
            version = goTarballVersion;
            src = pkgs.fetchurl {
              url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
              hash = goTarballHash;
            };
            # The tarball's source tree is goTarballVersion's, but goBase is
            # the nixpkgs default (e.g. 1.27) — its version-suffixed patches
            # (go_no_vendor_checks-1.26) do not apply to a newer tree. Swap
            # for the matching nixpkgs patch when one exists.
            patches =
              let
                vendorChecks = p: builtins.match "go_no_vendor_checks-.*[.]patch" (baseNameOf p) != null;
                majorMinor = lib.concatStringsSep "." (lib.lists.sublist 0 2 (lib.splitVersion goTarballVersion));
                matching = pkgs.path + "/pkgs/development/compilers/go/go_no_vendor_checks-${majorMinor}.patch";
              in
              builtins.filter (p: !vendorChecks p) prevAttrs.patches
              ++ lib.optionals (builtins.pathExists matching) [ matching ];
          }
        )
    else
      goPkgOverride goBase;
in
{
  inherit
    stripVersionSuffix
    repoName
    newestGoAttrName
    staleGoAttrName
    goModFloorMessage
    goBaseFrom
    ;
}

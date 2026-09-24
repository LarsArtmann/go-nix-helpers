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
    if branchAttrs == [ ] then
      null
    else
      lib.last (lib.sort (a: b: minor a < minor b) branchAttrs);
in
{
  inherit stripVersionSuffix repoName newestGoAttrName;
}

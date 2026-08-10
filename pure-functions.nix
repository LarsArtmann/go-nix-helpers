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
in
{
  inherit stripVersionSuffix repoName;
}

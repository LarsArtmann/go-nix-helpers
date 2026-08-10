# test-pure-functions.nix — Property and edge case tests for pure functions
#
# Tests stripVersionSuffix and repoName extracted from mkPreparedSource.
# These are pure functions with no side effects, enabling thorough testing.
{
  pkgs,
  lib,
}:
let
  pure = import ./pure-functions.nix { inherit lib; };
  inherit (pure) stripVersionSuffix repoName;

  assertEq =
    name: actual: expected:
    if actual == expected then
      "echo 'PASS: ${name}'"
    else
      ''
        echo 'FAIL: ${name}'
        echo "  expected: ${builtins.toJSON expected}"
        echo "  actual:   ${builtins.toJSON actual}"
        exit 1
      '';

  # --- stripVersionSuffix tests ---
  stripBasic = [
    (assertEq "strip: simple path" (stripVersionSuffix "codec") "codec")
    (assertEq "strip: single v2" (stripVersionSuffix "codec/v2") "codec")
    (assertEq "strip: mid-path v3" (stripVersionSuffix "event/v3/eventtest") "event/eventtest")
    (assertEq "strip: deep nested v2/v3" (stripVersionSuffix "a/v2/b/v3/c") "a/b/c")
    (assertEq "strip: no version" (stripVersionSuffix "foo/bar/baz") "foo/bar/baz")
    (assertEq "strip: v1 suffix" (stripVersionSuffix "pkg/v1") "pkg")
    (assertEq "strip: v100 suffix" (stripVersionSuffix "pkg/v100") "pkg")
    (assertEq "strip: empty string" (stripVersionSuffix "") "")
    (assertEq "strip: single segment" (stripVersionSuffix "v2") "")
    (assertEq "strip: only version segments" (stripVersionSuffix "v2/v3") "")
    (assertEq "strip: non-version v-prefix" (stripVersionSuffix "vendor") "vendor")
    (assertEq "strip: version-like non-match" (stripVersionSuffix "vx") "vx")
  ];

  # --- stripVersionSuffix idempotence ---
  stripIdempotence = [
    (assertEq "idempotence: strip twice = strip once"
      (stripVersionSuffix (stripVersionSuffix "event/v3/eventtest"))
      (stripVersionSuffix "event/v3/eventtest"))
    (assertEq "idempotence: already stripped"
      (stripVersionSuffix (stripVersionSuffix "codec"))
      "codec")
  ];

  # --- stripVersionSuffix invariant: no /vN in output ---
  stripNoVersionInOutput = lib.map (
    input:
    let
      output = stripVersionSuffix input;
      parts = lib.splitString "/" output;
      hasVersion = lib.any (p: builtins.match "v[0-9]+" p != null) parts;
    in
    if !hasVersion then
      "echo 'PASS: no /vN in output for input: ${input}'"
    else
      ''
        echo 'FAIL: /vN found in output for input: ${input}'
        echo "  output: ${output}"
        exit 1
      ''
  ) [
    "codec/v2"
    "event/v3/eventtest"
    "a/v2/b/v3/c"
    "v2"
    ""
    "pkg"
    "v100/v200"
  ];

  # --- repoName tests ---
  repoBasic = [
    (assertEq "repoName: standard 3-segment"
      (repoName "github.com/larsartmann/go-cqrs-lite") "go-cqrs-lite")
    (assertEq "repoName: with v2 suffix"
      (repoName "github.com/larsartmann/go-filewatcher/v2") "go-filewatcher")
    (assertEq "repoName: deep path with version"
      (repoName "github.com/larsartmann/go-cqrs-lite/codec/v2") "go-cqrs-lite")
    (assertEq "repoName: short path"
      (repoName "foo/bar") "bar")
    (assertEq "repoName: single segment"
      (repoName "mypkg") "mypkg")
  ];

  # --- repoName determinism ---
  repoDeterminism = [
    (assertEq "determinism: same input same output"
      (repoName "github.com/larsartmann/go-cqrs-lite")
      (repoName "github.com/larsartmann/go-cqrs-lite"))
    (assertEq "determinism: different calls match"
      (repoName "a/b/c") (repoName "a/b/c"))
  ];

  # --- repoName no-slash invariant ---
  repoNoSlash = lib.map (
    input:
    let
      output = repoName input;
      hasSlash = lib.hasInfix "/" output;
    in
    if !hasSlash then
      "echo 'PASS: no slash in repoName output for: ${input}'"
    else
      ''
        echo 'FAIL: slash found in repoName output for: ${input}'
        echo "  output: ${output}"
        exit 1
      ''
  ) [
    "github.com/larsartmann/go-cqrs-lite"
    "github.com/larsartmann/go-filewatcher/v2"
    "foo/bar"
    "mypkg"
  ];

  allChecks = stripBasic ++ stripIdempotence ++ stripNoVersionInOutput ++ repoBasic ++ repoDeterminism ++ repoNoSlash;
in
pkgs.runCommand "test-pure-functions" { } ''
  ${builtins.concatStringsSep "\n" allChecks}

  echo ""
  echo "==========================================="
  echo "PURE FUNCTION TESTS PASSED (${toString (builtins.length allChecks)} checks)"
  echo "==========================================="

  mkdir $out
  echo "all pure function tests passed" > $out/result.txt
''

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
  inherit (pure) stripVersionSuffix repoName newestGoAttrName;

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
    (assertEq "idempotence: strip twice = strip once" (stripVersionSuffix (
      stripVersionSuffix "event/v3/eventtest"
    )) (stripVersionSuffix "event/v3/eventtest"))
    (assertEq "idempotence: already stripped" (stripVersionSuffix (stripVersionSuffix "codec")) "codec")
  ];

  # --- stripVersionSuffix invariant: no /vN in output ---
  stripNoVersionInOutput =
    lib.map
      (
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
      )
      [
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
    (assertEq "repoName: standard 3-segment" (repoName "github.com/larsartmann/go-cqrs-lite")
      "go-cqrs-lite"
    )
    (assertEq "repoName: with v2 suffix" (repoName "github.com/larsartmann/go-filewatcher/v2")
      "go-filewatcher"
    )
    (assertEq "repoName: deep path with version"
      (repoName "github.com/larsartmann/go-cqrs-lite/codec/v2")
      "go-cqrs-lite"
    )
    (assertEq "repoName: short path" (repoName "foo/bar") "bar")
    (assertEq "repoName: single segment" (repoName "mypkg") "mypkg")
  ];

  # --- repoName determinism ---
  repoDeterminism = [
    (assertEq "determinism: same input same output" (repoName "github.com/larsartmann/go-cqrs-lite") (
      repoName "github.com/larsartmann/go-cqrs-lite"
    ))
    (assertEq "determinism: different calls match" (repoName "a/b/c") (repoName "a/b/c"))
  ];

  # --- repoName no-slash invariant ---
  repoNoSlash =
    lib.map
      (
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
      )
      [
        "github.com/larsartmann/go-cqrs-lite"
        "github.com/larsartmann/go-filewatcher/v2"
        "foo/bar"
        "mypkg"
      ];

  # --- newestGoAttrName tests ---
  newestGoBasic = [
    (assertEq "newestGo: picks newest branch from realistic attr names" (newestGoAttrName [
      "gcc"
      "go"
      "go_1_24"
      "go_1_25"
      "go_1_26"
      "go_1_27"
      "gopls"
      "gotools"
    ]) "go_1_27")
    (assertEq "newestGo: single branch" (newestGoAttrName [ "go_1_23" ]) "go_1_23")
    (assertEq "newestGo: numeric not lexicographic (go_1_10 > go_1_9)" (newestGoAttrName [
      "go_1_9"
      "go_1_10"
    ]) "go_1_10")
    (assertEq "newestGo: two-digit vs newer two-digit" (newestGoAttrName [
      "go_1_9"
      "go_1_27"
      "go_1_10"
    ]) "go_1_27")
    (assertEq "newestGo: ignores non-branch go attrs" (newestGoAttrName [
      "go"
      "gopls"
      "go-tools"
      "go_1_26"
    ]) "go_1_26")
    (assertEq "newestGo: ignores suffixed branch names" (newestGoAttrName [
      "go_1_26"
      "go_1_27-something"
    ]) "go_1_26")
    (assertEq "newestGo: no branch attrs returns null" (newestGoAttrName [
      "go"
      "gopls"
      "gcc"
    ]) null)
    (assertEq "newestGo: empty list returns null" (newestGoAttrName [ ]) null)
    (assertEq "newestGo: determinism"
      (newestGoAttrName [
        "go_1_26"
        "go_1_27"
      ])
      (newestGoAttrName [
        "go_1_27"
        "go_1_26"
      ])
    )
  ];

  # --- goBaseFrom tests (stub pkgs attrsets — no nixpkgs evaluation) ---
  # overrideAttrs is emulated: f is applied as (finalAttrs: prevAttrs:) with
  # self as both arguments, and the delta is merged back onto the stub.
  stubPkg =
    name:
    let
      self = {
        inherit name;
        version = "1.26.7";
        patches = [
          "go_no_vendor_checks-1.26.patch"
          "unrelated.patch"
        ];
        overrideAttrs =
          f:
          let
            delta = f self self;
          in
          self // delta // { _overridden = true; };
      };
    in
    self;

  stubPkgs = {
    go = stubPkg "go-fallback";
    go_1_24 = stubPkg "go_1_24";
    go_1_26 = stubPkg "go_1_26";
    go_1_27 = stubPkg "go_1_27";
    fetchurl = args: { fetchurl-args = args; };
    path = /stub-nixpkgs-without-matching-patch;
  };

  stubPkgsNoBranch = {
    go = stubPkg "go-fallback";
    gopls = stubPkg "gopls";
  };

  inherit (pure) goBaseFrom;

  goBaseBasic = [
    (assertEq "goBaseFrom: explicit pin wins over auto"
      (goBaseFrom {
        pkgs = stubPkgs;
        goPkgAttr = "go_1_26";
      }).name
      "go_1_26"
    )
    (assertEq "goBaseFrom: null attr picks newest branch" (goBaseFrom { pkgs = stubPkgs; }).name
      "go_1_27"
    )
    (assertEq "goBaseFrom: no branch attrs falls back to pkgs.go"
      (goBaseFrom {
        pkgs = stubPkgsNoBranch;
      }).name
      "go-fallback"
    )
    (assertEq "goBaseFrom: override hook applied over auto default"
      (goBaseFrom {
        pkgs = stubPkgs;
        goPkgOverride = p: { name = "overridden-${p.name}"; };
      }).name
      "overridden-go_1_27"
    )
    (assertEq "goBaseFrom: override hook applied over explicit pin"
      (goBaseFrom {
        pkgs = stubPkgs;
        goPkgAttr = "go_1_26";
        goPkgOverride = p: { name = "overridden-${p.name}"; };
      }).name
      "overridden-go_1_26"
    )
    (assertEq "goBaseFrom: tarball overrides the base"
      (goBaseFrom {
        pkgs = stubPkgs;
        goTarballVersion = "1.28.0";
        goTarballHash = "sha256-STUB";
      }).version
      "1.28.0"
    )
    (assertEq "goBaseFrom: tarball drops version-suffixed vendor-check patches"
      (goBaseFrom {
        pkgs = stubPkgs;
        goTarballVersion = "1.28.0";
        goTarballHash = "sha256-STUB";
      }).patches
      [ "unrelated.patch" ]
    )
    (assertEq "goBaseFrom: tarball wins over override hook"
      (goBaseFrom {
        pkgs = stubPkgs;
        goPkgOverride = p: { name = "overridden-${p.name}"; };
        goTarballVersion = "1.28.0";
        goTarballHash = "sha256-STUB";
      })._overridden
      true
    )
    (assertEq "goBaseFrom: tarball without hash throws"
      (builtins.tryEval
        (goBaseFrom {
          pkgs = stubPkgs;
          goTarballVersion = "1.28.0";
        }).name
      ).success
      false
    )
  ];

  # --- staleGoAttrName tests (warning decision for go-standard) ---
  staleGo = pure.staleGoAttrName;

  staleGoBasic = [
    (assertEq "staleGo: null pin (auto default) never warns" (staleGo {
      pkgs = stubPkgs;
      goPkgAttr = null;
    }) null)
    (assertEq "staleGo: pinning the newest branch does not warn" (staleGo {
      pkgs = stubPkgs;
      goPkgAttr = "go_1_27";
    }) null)
    (assertEq "staleGo: older existing pin returns the newest attr" (staleGo {
      pkgs = stubPkgs;
      goPkgAttr = "go_1_26";
    }) "go_1_27")
    (assertEq "staleGo: much older pin also returns the newest attr" (staleGo {
      pkgs = stubPkgs;
      goPkgAttr = "go_1_24";
    }) "go_1_27")
    (assertEq "staleGo: missing attr returns null (not our error)" (staleGo {
      pkgs = stubPkgs;
      goPkgAttr = "go_1_99";
    }) null)
    (assertEq "staleGo: no branch attrs in pkgs returns null" (staleGo {
      pkgs = stubPkgsNoBranch;
      goPkgAttr = "go_1_26";
    }) null)
  ];

  # --- goModFloorMessage tests (pure message builder for the floor check) ---
  floorMsg = pure.goModFloorMessage;

  floorMsgBasic = [
    (assertEq "floorMsg: names the requirement" (
      builtins.match ".*requires go 1\.28.*" (floorMsg {
        floorStr = "1.28";
        toolchainVersion = "1.26.4";
      }) != null
    ) true)
    (assertEq "floorMsg: names the resolved toolchain" (
      builtins.match ".*toolchain is 1\.26\.4.*" (floorMsg {
        floorStr = "1.28";
        toolchainVersion = "1.26.4";
      }) != null
    ) true)
    (assertEq "floorMsg: auto label when goPkgAttr is null" (
      builtins.match ".*\\(auto\\).*" (floorMsg {
        floorStr = "1.28";
        toolchainVersion = "1.26.4";
      }) != null
    ) true)
    (assertEq "floorMsg: pinned attr label when goPkgAttr is set" (
      builtins.match ".*\\(go_1_26\\).*" (floorMsg {
        floorStr = "1.28";
        toolchainVersion = "1.26.4";
        goPkgAttr = "go_1_26";
      }) != null
    ) true)
    (assertEq "floorMsg: offers the tarball fix with the floor version" (
      builtins.match ".*goTarballVersion = \"1\.28\".*" (floorMsg {
        floorStr = "1.28";
        toolchainVersion = "1.26.4";
      }) != null
    ) true)
  ];

  allChecks =
    stripBasic
    ++ stripIdempotence
    ++ stripNoVersionInOutput
    ++ repoBasic
    ++ repoDeterminism
    ++ repoNoSlash
    ++ newestGoBasic
    ++ staleGoBasic
    ++ floorMsgBasic
    ++ goBaseBasic;
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

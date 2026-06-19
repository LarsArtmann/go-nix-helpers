# test.nix — Integration test for mkPreparedSource auto-discovery
#
# Run:  nix-build test.nix -o test-result && cat test-result/go.mod
# Or:   nix-build test.nix -A autoDiscovery -o test-result && cat test-result/go.mod
{
  pkgs ? import <nixpkgs> {},
}: let
  lib = pkgs.lib;

  mkPreparedSource = import ./mkPreparedSource.nix {
    inherit pkgs lib;
    goPkg = pkgs.go_1_26;
  };

  # ---------------------------------------------------------------------------
  # Mock dep: a repo with sub-modules (like go-cqrs-lite)
  # ---------------------------------------------------------------------------
  mockDep = pkgs.stdenv.mkDerivation {
    name = "mock-dep";
    dontBuild = true;
    src = ./.;
    unpackPhase = ''
      mkdir -p $out
      cat > $out/go.mod <<'EOF'
      module github.com/larsartmann/mock-dep
      go 1.26
      EOF
      for sub in codec storage kv; do
        mkdir -p $out/$sub
        cat > $out/$sub/go.mod <<EOF
      module github.com/larsartmann/mock-dep/$sub/v2
      go 1.26
      EOF
      done
      # Add a non-module directory (no go.mod) to verify it's skipped
      mkdir -p $out/docs
      echo "documentation" > $out/docs/README.md
    '';
    installPhase = "cp -r . $out/";
  };

  # Mock consumer go.mod that requires two of the three sub-modules
  mockConsumerSrc = pkgs.writeTextDir "go.mod" ''
    module github.com/larsartmann/mock-consumer

    go 1.26

    require (
      github.com/larsartmann/mock-dep/codec/v2 v0.0.0
      github.com/larsartmann/mock-dep/storage/v2 v0.0.0
    )
  '';

  # Consumer that only requires codec (for explicit-only test)
  mockCodecOnlySrc = pkgs.writeTextDir "go.mod" ''
    module github.com/larsartmann/mock-consumer

    go 1.26

    require github.com/larsartmann/mock-dep/codec/v2 v0.0.0
  '';

  # ---------------------------------------------------------------------------
  # Test 1: Auto-discovery (no manual subModules)
  # ---------------------------------------------------------------------------
  autoDiscovery = mkPreparedSource {
    name = "test-auto";
    version = "test";
    src = mockConsumerSrc;
    deps = {
      "github.com/larsartmann/mock-dep" = mockDep;
    };
    # subModules omitted — auto-discovery should find codec, storage, AND kv
  };

  # ---------------------------------------------------------------------------
  # Test 2: Explicit subModules only (autoSubModules = false)
  # ---------------------------------------------------------------------------
  explicitOnly = mkPreparedSource {
    name = "test-explicit";
    version = "test";
    src = mockCodecOnlySrc;
    deps = {
      "github.com/larsartmann/mock-dep" = mockDep;
    };
    autoSubModules = false;
    subModules = {
      "github.com/larsartmann/mock-dep" = ["codec/v2"];
    };
  };

  # ---------------------------------------------------------------------------
  # Test 3: Validation catches a missing dep
  # ---------------------------------------------------------------------------
  # This consumer requires a private module NOT in deps.
  # The build should fail with a clear error message.
  mockMissingDepSrc = pkgs.writeTextDir "go.mod" ''
    module github.com/larsartmann/mock-missing

    go 1.26

    require (
      github.com/larsartmann/nonexistent-dep v1.0.0
    )
  '';

  validationTest = mkPreparedSource {
    name = "test-validation";
    version = "test";
    src = mockMissingDepSrc;
    deps = {};
    autoSubModules = false;
    validatePrivateDeps = true;
  };
in {
  # nix-build test.nix -A autoDiscovery -o result-auto
  inherit autoDiscovery explicitOnly validationTest;

  # Verification script: checks all test outputs
  # nix-build test.nix -A verify -o result-verify && ./result-verify
  verify = pkgs.runCommand "test-verify" {} ''
    set -e

    echo "=== Test 1: Auto-discovery ==="
    GOMOD=${autoDiscovery}/go.mod
    echo "--- go.mod content ---"
    cat "$GOMOD"
    echo ""

    # Check that all three sub-modules have replace directives
    for mod in codec storage kv; do
      path="github.com/larsartmann/mock-dep/$mod/v2"
      if grep -qF "$path => " "$GOMOD"; then
        echo "PASS: $path has replace"
      else
        echo "FAIL: $path missing replace"
        exit 1
      fi
    done

    # Check that the main dep has a replace
    if grep -qF "github.com/larsartmann/mock-dep => " "$GOMOD"; then
      echo "PASS: main dep has replace"
    else
      echo "FAIL: main dep missing replace"
      exit 1
    fi

    # Check that docs dir (no go.mod) was NOT added as a sub-module
    if grep -qF "mock-dep/docs" "$GOMOD"; then
      echo "FAIL: non-module directory 'docs' got a replace directive"
      exit 1
    else
      echo "PASS: non-module directories skipped"
    fi

    echo ""
    echo "=== Test 2: Explicit only (autoSubModules=false) ==="
    GOMOD2=${explicitOnly}/go.mod
    cat "$GOMOD2"
    echo ""

    if grep -qF "codec/v2 => " "$GOMOD2"; then
      echo "PASS: explicit codec replace present"
    else
      echo "FAIL: explicit codec replace missing"
      exit 1
    fi
    if ! grep -qF "storage/v2 => " "$GOMOD2"; then
      echo "PASS: storage NOT in replaces (autoSubModules=false)"
    else
      echo "FAIL: storage should not be auto-discovered"
      exit 1
    fi

    echo ""
    echo "=== Test 3: Validation (should FAIL the build) ==="
    if nix-store -r ${validationTest.drvPath} 2>&1 | grep -q "private modules without local replace"; then
      echo "PASS: validation caught missing dep with clear error"
    elif nix-store -r ${validationTest.drvPath} 2>&1 | grep -q "builder failed"; then
      echo "PASS: validation caught missing dep (build failed as expected)"
    else
      echo "FAIL: validation did not catch missing dep"
      exit 1
    fi

    echo ""
    echo "==========================================="
    echo "ALL TESTS PASSED"
    echo "==========================================="

    mkdir $out
    echo "all tests passed" > $out/result.txt
  '';
}

# test.nix — Integration test for mkPreparedSource auto-discovery
#
# Run:  nix-build test.nix -o test-result && cat test-result/go.mod
# Or:   nix-build test.nix -A autoDiscovery -o test-result && cat test-result/go.mod
{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;

  mkPreparedSource = import ./mkPreparedSource.nix {
    inherit pkgs lib;
    goPkg = pkgs.go_1_26;
  };

  # ---------------------------------------------------------------------------
  # Mock dep: a repo with sub-modules (like go-cqrs-lite)
  # ---------------------------------------------------------------------------
  mockDep = pkgs.runCommandLocal "mock-dep" { } ''
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
    # Depth-2 nested module with /vN in the MIDDLE of the module path
    # (simulates go-cqrs-lite's event/v3/eventtest)
    mkdir -p $out/event/eventtest
    cat > $out/event/eventtest/go.mod <<'EOF'
    module github.com/larsartmann/mock-dep/event/v3/eventtest
    go 1.26
    EOF
    # Depth-2 nested module under a sub-module (simulates storage/memory)
    mkdir -p $out/internal/mem
    cat > $out/internal/mem/go.mod <<'EOF'
    module github.com/larsartmann/mock-dep/internal/mem/v3
    go 1.26
    EOF
    # Excluded directories: example and testdata should NOT be discovered
    mkdir -p $out/example/demo
    cat > $out/example/demo/go.mod <<'EOF'
    module github.com/larsartmann/mock-dep/example/demo
    go 1.26
    EOF
    mkdir -p $out/testdata/fixtures
    cat > $out/testdata/fixtures/go.mod <<'EOF'
    module github.com/larsartmann/mock-dep/testdata/fixtures
    go 1.26
    EOF
    # Add a non-module directory (no go.mod) to verify it's skipped
    mkdir -p $out/docs
    echo "documentation" > $out/docs/README.md
  '';

  # Mock consumer go.mod that requires two of the three sub-modules
  mockConsumerSrc = pkgs.writeTextDir "go.mod" ''
    module github.com/larsartmann/mock-consumer

    go 1.26

    require (
      github.com/larsartmann/mock-dep/codec/v2 v0.0.0
      github.com/larsartmann/mock-dep/storage/v2 v0.0.0
      github.com/larsartmann/mock-dep/event/v3/eventtest v0.0.0
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
      "github.com/larsartmann/mock-dep" = [ "codec/v2" ];
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
    deps = { };
    autoSubModules = false;
    validatePrivateDeps = true;
  };
in
{
  # nix-build test.nix -A autoDiscovery -o result-auto
  inherit autoDiscovery explicitOnly validationTest;

  # Verification script: checks the success-path test outputs.
  # nix-build test.nix -A verify -o result-verify && ./result-verify
  #
  # NOTE: validationTest is deliberately a FAILING derivation (its build must be
  # rejected with the validation message). It CANNOT be a Nix dependency of this
  # verify derivation — a failing derivation can never be in the closure of a
  # passing one. So the negative case is verified separately below.
  verify = pkgs.runCommand "test-verify" { } ''
    set -e

    echo "=== Test 1: Auto-discovery ==="
    GOMOD=${autoDiscovery}/go.mod
    echo "--- go.mod content ---"
    cat "$GOMOD"
    echo ""

    # Check that all three top-level sub-modules have replace directives
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

    # Check depth-2 nested module with mid-path /vN: event/v3/eventtest
    if grep -qF "github.com/larsartmann/mock-dep/event/v3/eventtest => " "$GOMOD"; then
      echo "PASS: depth-2 nested eventtest has replace"
    else
      echo "FAIL: depth-2 nested eventtest missing replace"
      exit 1
    fi
    # Verify the local dir is event/eventtest (NOT event/v3/eventtest)
    if grep -qF "event/v3/eventtest => ./_local_deps/mock-dep/event/eventtest" "$GOMOD"; then
      echo "PASS: eventtest localDir correctly strips mid-path /v3"
    else
      echo "FAIL: eventtest localDir has wrong path (expected event/eventtest)"
      grep "eventtest" "$GOMOD"
      exit 1
    fi

    # Check depth-2 nested module under a regular sub-module: internal/mem/v3
    if grep -qF "github.com/larsartmann/mock-dep/internal/mem/v3 => " "$GOMOD"; then
      echo "PASS: depth-2 nested internal/mem has replace"
    else
      echo "FAIL: depth-2 nested internal/mem missing replace"
      exit 1
    fi

    # Check that excluded directories are NOT in replaces
    if grep -qF "mock-dep/example/demo" "$GOMOD"; then
      echo "FAIL: excluded directory 'example/demo' got a replace directive"
      exit 1
    else
      echo "PASS: example/ directories excluded from discovery"
    fi
    if grep -qF "mock-dep/testdata/fixtures" "$GOMOD"; then
      echo "FAIL: excluded directory 'testdata/fixtures' got a replace directive"
      exit 1
    else
      echo "PASS: testdata/ directories excluded from discovery"
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
    echo "==========================================="
    echo "SUCCESS-PATH TESTS PASSED"
    echo "==========================================="
    echo ""
    echo "Test 3 (validation) is a deliberately-failing derivation."
    echo "Verify it separately; it MUST fail with the validation message:"
    echo "  nix-build test.nix -A validationTest  # expect: exit 1 +"
    echo "    'private modules without local replace'"

    mkdir $out
    echo "all success-path tests passed" > $out/result.txt
  '';

  # Test 3 helper: a RUNNABLE script that asserts validationTest fails as
  # expected. Must be a script (not runCommand) because the Nix sandbox has no
  # `nix-store`, and a failing derivation cannot be in the closure of a passing
  # one. The drvPath context is discarded so building this script does NOT pull
  # validationTest into the build closure.
  #
  # Build + run:
  #   nix-build test.nix -A verifyValidation -o result-vv
  #   ./result-vv/bin/verify-validation
  verifyValidation = pkgs.writeShellApplication {
    name = "verify-validation";
    runtimeInputs = [ pkgs.nix ];
    meta.description = "Verify that validationTest fails with the expected error message";
    text = ''
      set +e
      log=$(nix-store -r ${builtins.unsafeDiscardStringContext validationTest.drvPath} 2>&1)
      if echo "$log" | grep -q "private modules without local replace"; then
        echo "PASS: validation caught missing dep with clear error"
      else
        echo "FAIL: validation did not emit the expected error"
        echo "$log" | tail -8
        exit 1
      fi
    '';
  };
}

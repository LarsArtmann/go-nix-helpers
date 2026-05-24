# go-nix-helpers

Shared Nix helpers for LarsArtmann Go repositories.

## `mkPreparedSource.nix`

Prepares Go source with local dependency replacement for Nix sandbox builds.

Go repos with private dependencies can't fetch them inside the Nix sandbox (no SSH, no network).
This helper copies flake-input deps into `_local_deps/` and injects `replace` directives into `go.mod`.

### Usage

Add as a flake input:

```nix
inputs = {
  go-nix-helpers = {
    url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
    flake = false;
  };
};
```

Then in outputs:

```nix
mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
  inherit pkgs lib;
  goPkg = pkgs.go_1_26;
};
preparedSrc = mkPreparedSource {
  name = "my-app";
  version = "1.0.0";
  src = srcFiltered;
  deps = {
    "github.com/larsartmann/go-output" = go-output;
  };
  subModules = {
    "github.com/larsartmann/go-output" = [ "enum" "escape" ];
  };
};
```

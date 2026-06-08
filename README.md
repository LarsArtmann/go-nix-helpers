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
```

### Major version suffixes (`/v2`, `/v3`, …)

Go modules at v2+ use a `/vN` suffix in the import path. `mkPreparedSource` handles
this automatically — the repo name is extracted from the path, stripping the version
suffix so the local directory name is always the repo name (not `v2`, `v3`, etc.).

```nix
deps = {
  "github.com/larsartmann/go-output" = go-output;
  "github.com/larsartmann/go-filewatcher/v2" = go-filewatcher;
  "github.com/LarsArtmann/gogenfilter/v3" = gogenfilter;
};
```

This produces `_local_deps/go-output`, `_local_deps/go-filewatcher`,
`_local_deps/gogenfilter` — no collisions even with multiple `/v2` deps from
different repos.

### Sub-modules

For repos with independent Go sub-modules (each with their own `go.mod`):

```nix
subModules = {
  "github.com/larsartmann/go-output" = [ "enum" "escape" ];
};
```

### Full example

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
    "github.com/larsartmann/go-filewatcher/v2" = go-filewatcher;
  };
  subModules = {
    "github.com/larsartmann/go-output" = [ "enum" "escape" ];
  };
};
```

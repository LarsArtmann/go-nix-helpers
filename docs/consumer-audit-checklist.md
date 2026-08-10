# Consumer Audit Checklist — go-nix-helpers "Superb Usage"

> Systematic criteria for verifying that a Go repository uses go-nix-helpers
> correctly and idiomatically. Work through each section per repo.

---

## 1. Module adoption

- [ ] Uses `flakeModules.go-standard` (NOT `mkGoFlake.nix`, NOT raw `mkPreparedSource`)
- [ ] Import line: `imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];`
- [ ] Config block is `go-standard = { ... }` (not the old mkGoFlake attrset)

## 2. Flake inputs (minimalism)

- [ ] Exactly 3 required inputs: `nixpkgs`, `flake-parts`, `go-nix-helpers`
- [ ] NO `treefmt-nix` input (bundled internally by the composite module)
- [ ] NO `systems` input unless `go-standard.systems = import inputs.systems;` is used
- [ ] `go-nix-helpers` is a real flake input (NOT `flake = false`) when using the module
- [ ] `go-nix-helpers.inputs.nixpkgs.follows = "nixpkgs"` is set
- [ ] `flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs"` is set
- [ ] Each private dep input has `flake = false`

## 3. Required config

- [ ] `pname` is set and matches the repo/binary name
- [ ] `vendorHash` is a real hash (NOT the `sha256-AAA...` placeholder)
- [ ] `description` is meaningful (NOT the default "A LarsArtmann Go project")

## 4. Private deps (if applicable)

- [ ] Every `github.com/larsartmann/*` require in go.mod has a matching flake input
- [ ] Every private dep input is listed in `deps = { "import/path" = inputs.X; }`
- [ ] GOPRIVATE is NOT set manually (auto-injected via `autoGoPrivate` when `deps` is set)
- [ ] Public repos matching the private pattern are listed in `publicDeps`
- [ ] No stale local replace directives in go.mod (`/home/...`, `./...`, `../...`)

## 5. No unnecessary overrides

These are all defaults — flag if set redundantly:

- [ ] `enableCheck` not set to `true` (it's the default)
- [ ] `enableOverlay` not set to `true` (it's the default)
- [ ] `enableGolangciLint` not set to `true` (it's the default)
- [ ] `enableGofumpt` not set to `true` (it's the default)
- [ ] `enableGoimports` not set to `true` (it's the default)
- [ ] `enableNixfmt` not set to `true` (it's the default)
- [ ] `enableGopls` not set to `true` (it's the default)
- [ ] `enableGovulncheck` not set to `true` (it's the default)
- [ ] `proxyVendor` not set to `true` (it's the default)
- [ ] `goPkgAttr` not set to `"go_1_26"` (it's the default)
- [ ] `src` not set to `self.outPath` or `./.` (it's the default)
- [ ] `subPackages` not set to `[ "." ]` (it's the default)

## 6. Verification commands

Run these in each repo and confirm they pass:

```bash
nix flake check          # all checks pass
nix build                # binary builds
nix run .#test           # go test -race -v ./... passes
nix run .#lint           # golangci-lint passes (if enabled)
nix fmt -- --ci          # formatting clean (0 changed)
```

## 7. flake.lock hygiene

- [ ] `flake.lock` is committed
- [ ] No stale inputs (inputs that were removed but still in lock file)
- [ ] `go-nix-helpers` points to current master commit

## 8. Migration status (if repo was on old setup)

- [ ] NO reference to `mkGoFlake.nix` anywhere
- [ ] NO reference to the `go-flake-parts` template
- [ ] NO manual `mkPreparedSource` import (use `deps` option instead)
- [ ] NO manual treefmt-nix wiring
- [ ] NO manual `systems` wiring

---

## Quick triage script

Run this in a consumer repo for a fast first pass:

```bash
echo "=== Module adoption ==="
grep -q 'flakeModules.go-standard' flake.nix \
  && echo "OK: uses go-standard module" \
  || echo "WARN: NOT using go-standard module"

echo "=== Deprecated patterns ==="
grep -q 'mkGoFlake' flake.nix && echo "WARN: mkGoFlake still referenced" || echo "OK: no mkGoFlake"
grep -q 'go-flake-parts' flake.nix && echo "WARN: old template referenced" || echo "OK: no old template"
grep -q 'treefmt-nix' flake.nix && echo "WARN: unnecessary treefmt-nix input" || echo "OK: no treefmt-nix input"

echo "=== go-nix-helpers as real flake (not flake=false) ==="
# Check if go-nix-helpers block contains flake = false
awk '/go-nix-helpers = \{/{found=1} found && /flake = false/{print "WARN: go-nix-helpers has flake=false"; found=0} found && /\}/{found=0}' flake.nix
awk '/go-nix-helpers = \{/{found=1} found && /flake = false/{f=1} found && /\}/{if(!f) print "OK: go-nix-helpers is real flake"; found=0; f=0}' flake.nix

echo "=== Placeholder vendorHash ==="
grep -q 'sha256-AAA' flake.nix && echo "WARN: placeholder vendorHash" || echo "OK: no placeholder"

echo "=== Redundant default overrides ==="
for opt in enableCheck enableOverlay enableGolangciLint enableGofumpt enableGoimports enableNixfmt enableGopls enableGovulncheck proxyVendor; do
  grep -q "^\s*${opt} = true" flake.nix && echo "NOTE: ${opt} = true is the default (can remove)"
done

echo "=== Follows chains ==="
grep -q 'nixpkgs.follows' flake.nix || echo "NOTE: consider adding inputs.X.inputs.nixpkgs.follows"
```

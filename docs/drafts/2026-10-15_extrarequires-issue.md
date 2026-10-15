# mkPreparedSource: first-class `extraRequires` for prepared-source-only go.mod require entries

`go-nix-helpers` @ `ad423c8`, consumer: go-aichat @ `v0.2.1`.

## Problem

When a prepared source's module graph needs a `require` entry that the
CI-canonical `go.mod` must NOT carry, the only seam is `postPatchExtra`
(`mkPreparedSource.nix:112`) — so the consumer hand-writes a sed one-liner
against the generated `go.mod`.

Concrete case: go-aichat's `chatstore` sub-module builds on go-cqrs-lite
SHA-pinned; the unpruned replaced tree needs
`github.com/larsartmann/go-cqrs-lite/claiming/v4` in the module graph, but
the proxy-tidied `chatstore/go.mod` must not list it (CI runs
`go mod tidy && git diff --exit-code` and would remove it). The require
entry is a prepared-source-only concern, and today it ships as raw sed in
the consumer flake:

```nix
sed -i '/^replace (/i require github.com/larsartmann/go-cqrs-lite/claiming/v4 v4.0.1 // indirect' $out/go.mod
```

That is fragile in exactly the ways this repo's own vendoring guidance warns
about — anchors, delimiters, first-match ordering — and every consumer with
the same shape reinvents it.

## Proposal

**`extraRequires ? { }` on `mkPreparedSource`**: attrset of module path →
version, emitted as `require` entries (`// indirect`) in the prepared
`go.mod` at the point where `postPatchExtra` currently runs.
`postPatchExtra` stays for everything else.

## Why the builder should own it

- The entry shape (`// indirect` comment, insertion before the `replace (`
  block) is builder knowledge, not consumer knowledge.
- A structured attrset removes all three sed hazards (no anchors, no
  delimiter choice, no first-match surprises) and is self-documenting at
  the call site, next to `requireDeps` (`mkPreparedSource.nix:106`), which
  already owns the private-dep mapping this composes with.
- The go-aichat case would shrink from a `runCommand` wrapper with gnused
  to one argument.

💘 Generated with Crush

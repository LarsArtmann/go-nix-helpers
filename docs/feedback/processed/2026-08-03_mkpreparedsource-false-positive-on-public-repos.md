# Feedback: mkPreparedSource false-positive on public LarsArtmann repos

**From:** Standup-Killer project session (2026-08-03)  
**Severity:** Medium — causes incorrect workarounds, misleading error messages, unnecessary SSH inputs  
**Files:** `mkPreparedSource.nix`, `mkGoFlake.nix`

---

## Summary

`mkPreparedSource` treats **every** `github.com/larsartmann/*` repo as private, but some are public and served by proxy.golang.org. The validation then fails for public repos that the Go proxy can resolve transparently, leading users to add unnecessary `git+ssh://` flake inputs for repos that don't need them.

---

## The Problem in Detail

### 1. `privateDepPattern` is too broad

`mkPreparedSource.nix:101`:

```nix
privateDepPattern ? "github\\.com/[Ll]ars[Aa]rtmann/",
```

This blanket-matches ALL repos under the LarsArtmann GitHub account. The validation script (`validateScript`, lines 269-301) then greps `go.mod` require blocks for this pattern and demands every match have a local `replace` directive.

But these repos are **public** and on the Go proxy:

| Repo                                     | GitHub visibility  | proxy.golang.org  |
| ---------------------------------------- | ------------------ | ----------------- |
| `github.com/larsartmann/go-atomic-write` | `"private": false` | v0.4.1 available  |
| `github.com/larsartmann/go-ndjson`       | `"private": false` | v0.0.1 available  |
| `github.com/larsartmann/go-sse`          | `"private": false` | v0.3.0 available  |
| `github.com/larsartmann/go-output`       | `"private": false` | v0.35.0 available |
| `github.com/larsartmann/go-branded-id`   | `"private": false` | v0.5.1 available  |

These do not need SSH flake inputs. They resolve through the Go module proxy like any standard public dependency.

### 2. The error message is misleading

When a public LarsArtmann repo appears in `go.mod` without a flake input, `validateScript` produces:

```
=======================================================
mkPreparedSource: private modules without local replace:

  github.com/larsartmann/go-atomic-write
  github.com/larsartmann/go-ndjson
  github.com/larsartmann/go-sse

These modules are required in go.mod but have no replace
directive. Add the missing repos to your flake.nix inputs
and deps map.
=======================================================
```

This says "private modules" and tells the user to "add the missing repos to your flake.nix inputs and deps map." For genuinely private repos this is correct guidance. For **public** repos this is wrong — it leads the user to add unnecessary SSH flake inputs, which:

- Requires SSH key access for repos that are publicly cloneable
- Adds unnecessary entries to `flake.lock`
- Makes the build depend on SSH authentication for public resources
- Breaks CI runners without SSH keys for repos that don't need them

### 3. `mkGoFlake.nix` does not forward `validatePrivateDeps` or `privateDepPattern`

`mkPreparedSource.nix` has the escape hatches:

```nix
validatePrivateDeps ? true,     # line 100
privateDepPattern ? "github\\.com/[Ll]ars[Aa]rtmann/",  # line 101
```

But `mkGoFlake.nix:97-106` only forwards a subset of parameters:

```nix
preparedSrc = mkPreparedSource {
  name = pname;
  inherit
    version
    src
    deps
    subModules
    postPatchExtra
    ;
};
```

`validatePrivateDeps` and `privateDepPattern` are **not forwarded**. Projects using `mkGoFlake.nix` cannot toggle validation without switching to manual `mkPreparedSource` usage (Option B in the SKILL.md), losing all the convenience of `mkGoFlake.nix`.

### 4. What happened in practice

In Standup-Killer, `go-atomic-write`, `go-ndjson`, and `go-sse` appear as indirect dependencies (pulled in by `go-output`, `go-sse` by `cqrs-htmx`, etc.). The validation blocked the build, and following the error message's guidance, we added SSH flake inputs for all three — even though they are public repos. The build passed, but the fix was architecturally wrong.

The gotcha table in `SKILL.md` mentions this case:

> | Public LarsArtmann repo in `go.mod` | `mkPreparedSource` validation fails because repo is not in `deps` | Set `validatePrivateDeps = false;` |

But this workaround is only available when calling `mkPreparedSource` directly. Projects using `mkGoFlake.nix` have no way to set it.

---

## Suggested Fixes

### Fix A: Forward `validatePrivateDeps` and `privateDepPattern` through `mkGoFlake.nix` (minimal, backward-compatible)

```nix
# mkGoFlake.nix — add to parameter list:
  validatePrivateDeps ? true,
  privateDepPattern ? "github\\.com/[Ll]ars[Aa]rtmann/",

# mkGoFlake.nix — add to mkPreparedSource call:
  preparedSrc = mkPreparedSource {
    name = pname;
    inherit
      version
      src
      deps
      subModules
      postPatchExtra
      validatePrivateDeps    # <-- add
      privateDepPattern      # <-- add
      ;
  };
```

Projects with public LarsArtmann deps can then set `validatePrivateDeps = false;` in their `mkGoFlake` config.

**Drawback:** Disabling validation entirely loses the safety net for genuinely private repos.

### Fix B: Add a `publicDeps` exclusion list (more precise)

```nix
# mkPreparedSource.nix — new parameter:
  publicDeps ? [ ],  # List of module paths to exclude from private validation

# In validateScript, filter out public deps:
  REQUIRED=$(
    awk '...' go.mod \
    | grep -E '${privateDepPattern}' \
    | grep -vF -f <(printf '%s\n' ${lib.concatMapStringsSep " " (d: "'${d}'") publicDeps}) \
    | sort -u
  )
```

Projects can list known-public repos:

```nix
# In project flake.nix via mkGoFlake:
  publicDeps = [
    "github.com/larsartmann/go-atomic-write"
    "github.com/larsartmann/go-ndjson"
    "github.com/larsartmann/go-sse"
  ];
```

**Advantage:** Keeps validation active for genuinely private repos while allowing specific exclusions.

### Fix C: Improve the error message (quick win, independent of A/B)

Change the wording to not assume the modules are private:

```
=======================================================
mkPreparedSource: modules without local replace:

  github.com/larsartmann/go-atomic-write
  github.com/larsartmann/go-ndjson

These modules match the private dependency pattern and have
no replace directive. Either:
  1. Add the repos to flake.nix inputs and deps map (if private)
  2. Set validatePrivateDeps = false (if any are public)
  3. Add them to publicDeps (if mixed public/private)
=======================================================
```

This prevents users from blindly following guidance that only applies to private repos.

---

## Recommendation

Implement **Fix A + Fix C** as the immediate improvement (minimal change, backward-compatible, better error message). Consider **Fix B** as a follow-up for projects with a mix of public and private LarsArtmann deps.

---

## Reproduction

1. Create a Go project using `mkGoFlake.nix`
2. Add a public LarsArtmann repo as a dependency: `go get github.com/larsartmann/go-atomic-write@v0.4.1`
3. Do NOT add it to the `deps` map
4. Run `nix build .#default`
5. Build fails with the "private modules without local replace" error
6. The repo is public and the Go proxy can serve it, but there is no way to tell `mkGoFlake.nix` to skip validation for it

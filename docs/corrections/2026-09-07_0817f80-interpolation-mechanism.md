# Correction: 0817f80 commit-message mechanism

**Corrects:** commit `0817f80` ("fix: escape Nix interpolation in go.mod
replace-validation grep", 2026-09-07) — the recorded RATIONALE, not the code.

**What the commit message claims:** a "single-quoted shell fragment" /
"regex mismatch" mechanism — that the shell "received a pattern with the
module path already expanded ... or produced a literal '$' mismatch in the
regex".

**What actually happened:** the grep pattern lived inside a Nix
**indented string** (`''...''`). In indented strings, `${` still starts
Nix interpolation (only `''${` escapes it). The unescaped `${mod}`
therefore interpolated the Nix variable `mod` at EVAL time — and `mod`
did not exist in that scope, so evaluation itself errored. There was no
regex mismatch and no wrong-scope expansion at runtime; the breakage was
a Nix eval error, which is why it surfaced as `nix flake check` /
`nix build` failing during evaluation, not as a misbehaving grep inside
the sandbox.

(The message even hedges mid-sentence — "except that is NOT ..." — a sign
it was written from the diff rather than from the failure.)

**Why this matters:** anyone debugging this code class later will be
misdirected toward shell-quoting analysis. The correct mental model is:
**in Nix indented strings, `${` interpolates unless written `''${`** —
the same rule that produced the `escapeShellArg`/`[.]`-vs-`\.` guards in
`mkPreparedSource.nix` today (see the comment block near
`explicitVersionNormalize`).

**Why the commit isn't rewritten:** rewriting others' (or even own,
shared) commits rewrites history downstream consumers may have pinned;
the 2026-09-07 session already confirmed CV's `vendorHash` re-pin
(`sha256-sKpKP6…`) against the code as committed, which is correct.

**Verification trail:** `docs/status/2026-09-07_21-15_nix-review-eval-breakers-status.md`
item 6 first recorded the discrepancy; this note is the promised
correction.

_Correction written 2026-09-25._

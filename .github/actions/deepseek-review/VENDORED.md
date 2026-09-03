# Vendored: hustcer/deepseek-review (MIT)

Local copy of the `hustcer/deepseek-review` GitHub Action so Nexus can carry
a small patch the upstream project does not ship yet.

- **Upstream source:** https://github.com/hustcer/deepseek-review
- **Vendored commit:** `02734b66d5b7dbbeb4836774f7ab6dc3602339a6` (2026-08-23,
  post-v1.21 fixes for diff filtering / glob grouping).
- **License:** MIT — see `LICENSE` (unchanged from upstream).
- **Vendored files:** `action.yaml` and `nu/` (the composite action's runtime)
  plus `LICENSE`. Tests, docs, and release tooling are not vendored.
- **How to re-vendor:** re-copy from the upstream commit above and re-apply
  the patch below; when upstream ships the fix, drop this directory and point
  the workflow back at the upstream pin.

## Nexus patch (divergence from upstream)

**File:** `nu/diff.nu` — `apply-file-filters` (plus a local
`apply-file-glob-to-regex` helper mirroring upstream `util.nu glob-to-regex`)

**Problem:** upstream pipes the PR diff into `awk` through nushell
(`… | try { ^awk … }`). Inside the action's module context the subprocess
deadlocks — awk blocks with 0% CPU once the diff (and awk's filtered output)
exceed the OS pipe-buffer size (~64 KB). Symptom: the review step hangs
silently for the full job timeout on PRs with more than ~1,300 inserted
lines, before any DeepSeek API call is made (no tokens consumed).
Reproduced locally against Nexus PR #12's ~89 KB diff: the action hangs
there; skipping the awk step entirely makes it complete; the identical awk
program over the same diff finishes in ~10 ms via a plain shell pipe.

**Fix:** implement the include/exclude file filtering in pure nushell
(`reduce` over `lines`, block semantics matching upstream: a `diff --git`
header decides whether the whole hunk is kept — `--include` keeps only
matching files, `--exclude` drops matching files, exclude wins). No `awk`
subprocess, no pipes, no deadlock. The old `prepare-awk` import is dropped.

**Validation:** the local repro of the Nexus PR #12 diff (89 KB, 21 files)
now passes the filter stage (content length printed) and proceeds to the
DeepSeek API call; previously it hung indefinitely at the awk stage.

# `scripts/_legacy/` — wrapped legacy checkers

The six scripts in this directory are **actively used**, not dead code. They contain
the original cross-bundle check logic from the pre-redesign system-design skill:

| Script | Active wrapper | CR |
|--------|----------------|-----|
| `check-analytics-coverage.sh`     | `../check-analytics-coverage.sh`     | CR-SD15 |
| `check-architecture-coverage.sh`  | `../check-architecture-coverage.sh`  | CR-SD14 |
| `check-dependency-layering.sh`    | `../check-dependency-layering.sh`    | CR-SD16 |
| `check-placeholder-json.sh`       | `../check-placeholder-json.sh`       | CR-SD17 |
| `check-readme-references.sh`      | `../check-readme-references.sh`      | CR-SD18 |
| `check-single-source-of-truth.sh` | `../check-single-source-of-truth.sh` | CR-SD19 |

## How they're used

Each active wrapper in `scripts/check-*.sh` delegates to the corresponding legacy
script via `scripts/lib/sd_legacy_wrapper.sh`, then translates the legacy script's
output into the §9 contract (Finding dicts via `sd_lint.emit()`, 3-state returncode).
The split is intentional:

- The **legacy script** preserves the original detection logic (regex patterns,
  cross-file traceability checks, etc.) — these have working test coverage and
  match prior behavior.
- The **active wrapper** owns the §9 contract (stdout shape, returncode semantics,
  CR-Sxx mapping). Future per-criterion refinements happen in the wrapper, not here.

## Why not inline the legacy code into the wrapper?

Inlining was considered during the redesign (commit `e8a281f`) but deferred because:
1. The legacy scripts have idiosyncratic regex / file-walking logic that benefits
   from being kept verbatim during the transition.
2. The wrapper boundary makes it easy to swap the implementation later without
   touching the §9 contract surface.
3. Inlining ~2,400 lines into 6 wrappers would obscure the delegation pattern that
   makes the wrappers easy to audit.

When confidence is high that the legacy logic is stable and well-tested, future
work can collapse each wrapper + legacy pair into a single script. Until then,
**do not delete this directory** — the active wrappers depend on it.

## Maintenance rules

- ✅ Edit a legacy script in place if you find a bug in its detection logic.
- ✅ Edit the active wrapper to refine the §9 contract (CR id, severity, message).
- ❌ Do not call any `_legacy/*.sh` directly from orchestration files or other
   scripts — only the matching active wrapper should reach in here.
- ❌ Do not add new scripts to `_legacy/` — new checkers live in `scripts/` directly
   following the §9 contract from day one.

# Delivery Discipline — Autoforge Anti-Pattern Rules

> **All autoforge sub-agents read this file.** It defines the patterns that
> are forbidden in code and tests, and the signals that are required before
> any gate (Tester PASS, Reviewer APPROVE, Module APPROVE, phase integration
> PASS, acceptance PASS) is allowed to flip green.
>
> The autoforge pipeline does **not** trust agents to be diligent. It
> structurally rejects work that contains the patterns below. Whenever a
> rule references "REJECT", the gate (Reviewer / Module Agent / Integration
> Tester / Acceptance Tester / Orchestrator) must treat the violation as a
> blocking finding, regardless of whether other tests are passing.
>
> Background: 2026-04-27 retro analysis "Autoforge PRD Delivery Shortfall
> Root-Cause Analysis". The countermeasures in §九 of that document are the
> source of every rule in this file.

---

## A. Forbidden Test Patterns (Soft-Pass)

Soft-pass tests look green but cannot detect a missing implementation. They
are **prohibited**. If found, the gate REJECTs and the Developer must rewrite
the test to a strict assertion AND fix any underlying defect the rewrite
exposes.

| ID | Forbidden pattern | Why it fails | Required replacement |
|----|-------------------|--------------|----------------------|
| SP1 | Multi-status acceptance: `expect([200, 400, 403, 404, 409]).toContain(res.status)` | Accepts both implemented and unimplemented behaviour identically | One specific expected status per test path |
| SP2 | Warn-and-continue: `if (after.ok()) { console.warn('not enforced') } else { /* nothing */ }` | Failure is silent; CI stays green when behaviour regresses | Hard `expect(after.ok()).toBe(true)` (or `false`, whichever PRD requires) |
| SP3 | Placeholder comment: `// will assert once X lands`, `// TODO: tighten when wired` | Defers the contract; the deferral is invisible to CI | Either implement the assertion now, or `test.skip(...)` with a GitHub issue link in the comment |
| SP4 | Empty test body / single `expect(true).toBe(true)` / no assertions | No signal | Real assertions or delete the test |
| SP5 | Catch-all `try { ... } catch { /* ok either way */ }` around the path under test | Swallows the failure that proves the bug | Catch only the specific error type the PRD says is expected; assert it |
| SP6 | Conditional skip on missing route/data: `if (res.status === 404) test.skip()` | The 404 IS the bug; skipping hides it | Remove the conditional skip; if the route is genuinely out-of-scope, mark the test `test.skip` with an issue link |
| SP7 | Mock-only verification of behaviour the PRD says is observable to the user | Tests the mock, not the system | At least one test per AC that exercises the real wired path (DB writes through, route registered, cookie set) |
| SP8 | Asserting on `console.warn` / log output as a substitute for asserting on user-visible state | Confirms the warning logged, not that the feature works | Assert on the user-observable state change |

**`test.skip` is the only legal way to defer a test.** Each `test.skip` MUST:

- Carry a comment of the form `// SKIP: <one-sentence reason>; tracked in <github-issue-url>`.
- Reference an open GitHub issue (URL or `org/repo#NNN`); in environments
  where issues are not yet enabled, a TODO file path inside the repo with
  the same level of structure is acceptable, but a bare `// TODO` is not.
- Be enumerated in the module / acceptance report's "Outstanding Debt" table.

A skipped test without an issue reference is treated identically to SP3.

---

## B. Forbidden Code Patterns (Silent Write-Path)

Code paths that "succeed" without doing anything observable are PRD violations
in disguise. They are **prohibited**. If found, the Reviewer REJECTs.

| ID | Forbidden pattern | Why it fails | Required replacement |
|----|-------------------|--------------|----------------------|
| SW1 | Silent zero-rows write: `_, _ = db.Exec(...)` (or equivalent) without checking RowsAffected | Update missed its row; caller treats it as success | Check RowsAffected; return a domain error when expected rows ≠ actual |
| SW2 | Model defined but never registered (e.g. `AutoMigrate` list missing it; ORM schema not updated) | Table never created; INSERTs fail or use a stale schema | Build-time or startup assertion that every owned model is registered; regression test |
| SW3 | Route handler defined but not mounted (router.Group / app.use never called) | Endpoint 404s; soft-pass tests above mask it | Smoke test that asserts the route returns the expected non-404 status; registration is exercised in module-level integration tests |
| SW4 | Middleware written but not inserted into the chain | Auth / logging / cookie-issuing logic never runs | Test that asserts the middleware's observable side effect (e.g. `Set-Cookie` header present) |
| SW5 | Cookie / header issued only on a code path that is unreachable from the deployed config | Production users never receive it | Integration test against the production wiring config |
| SW6 | Fall-open on missing context: `if ctx.Value("user") == nil { /* allow through */ }` | Auth bypass | Fail-closed: return error or 401/403 with a logged event |
| SW7 | Catch-all error swallow: `} catch { return nil }` returning success on unknown error | Bug becomes invisible | Log + propagate; only swallow errors the PRD explicitly says are recoverable, and only after asserting the type |
| SW8 | Feature flag defaults to disabled in production but tests run with flag forced on | Tests pass; users never see the feature | Test the production-default config path at least once per feature |

---

## C. Required Signals (Wiring & Registration)

Before any module gate flips green, the implementation MUST:

1. Register every owned model / table / collection with the schema layer
   (AutoMigrate, Alembic, Prisma, etc.).
2. Mount every owned route in the production router config and in every
   environment the PRD names as a target.
3. Insert every owned middleware in the chain that serves real traffic.
4. Wire every config / feature flag in `.env.example` and the deployment
   files referenced by the PRD's Deployment Architecture.
5. Have at least one test per acceptance criterion that exercises the
   wired path (not the mock). Mock-only tests are acceptable in addition,
   never as the sole signal.

A module that fails any of these is "implementation incomplete" — the
Reviewer REJECTs even if all its tests pass, because the tests are testing
an unwired stub.

---

## D. Out-of-Scope = GitHub Issue, Not Comment

The only legal forms of "we know about this but didn't fix it":

1. An open GitHub issue with: PRD reference (J-XXX or F-NNN-AC-NN), current
   state ("not implemented" / "partial" / "implemented but disabled"),
   user-visible impact, and a link to the line(s) of code that defer the
   work.
2. A `test.skip` with the same issue link (per A above).

The following are **prohibited** and trigger REJECT:

- `// TODO: ...` comments without an issue link.
- `// FIXME: ...` comments without an issue link.
- `// tracked as follow-up` / `// will revisit` and similar prose markers.
- README / design doc paragraphs that say "we'll add X later" without a
  corresponding issue.
- `console.warn("not yet implemented")` or runtime warnings as debt
  markers.

Reviewers, Integration Testers, and the Acceptance Tester search the diff
for these strings as part of their gate; matches are required findings.

---

## E. Naming Is a Contract

When a test file or test case is named after a PRD artifact (`J-XXX`,
`F-NNN-AC-NN`), its body MUST exercise that artifact's PRD-defined
sequence:

- `J-XXX-*.spec.ts` must traverse the touchpoint sequence in the PRD
  journey spec, not just hit one endpoint and assert a status code.
- `F-NNN-AC-N.spec.ts` (or test case named `test_F001_AC3_...`) must
  assert the specific behaviour the AC describes — not a generic "endpoint
  responds" probe.

A test whose name claims a PRD reference but whose body does not actually
verify that reference is treated as SP4 (no real assertions) — the
Reviewer / Acceptance Tester REJECTs.

---

## F. Bidirectional Traceability Closure

Every PRD acceptance criterion (`F-NNN-AC-NN`) and every E2E journey
scenario (`J-XXX-EE-NN`) must map to **at least one passing test** at the
appropriate layer (module integration, phase integration, or acceptance).
Conversely, every test named after a PRD artifact must map back to a real
PRD reference.

The Acceptance Tester writes `reports/traceability.json`:

```json
{
  "criteria": [
    {"id": "F-001-AC-1", "feature": "F-001", "tests": ["test_F001_AC1_smoke"], "status": "PASS"},
    {"id": "F-002-AC-3", "feature": "F-002", "tests": [], "status": "NOT_COVERED", "reason": "...", "issue": "org/repo#42"}
  ],
  "journeys": [
    {"id": "J-001-E2E-1", "journey": "J-001", "tests": ["j001_happy_path.spec.ts"], "status": "PASS"}
  ],
  "orphan_tests": []
}
```

Closure rules (each is a hard gate at acceptance):

- **No unmapped AC**: every AC and E2E scenario is in `criteria` or `journeys`.
  AC entries with `status = NOT_COVERED` MUST carry a non-empty `reason` and
  an `issue` field (per D above).
- **No orphan tests**: any test file or test case whose name encodes a PRD
  reference (`J-XXX`, `F-NNN-AC-NN`, `test_FNNN_*`, `test_JNNN_*`) appears in
  the `tests` list of the matching entry. Tests that do not encode such a
  reference live in module/integration test suites and are not enumerated
  here.
- **No naming-content mismatch** (per E above): the Acceptance Tester
  spot-checks that each enumerated test actually verifies the AC/journey
  it claims, by reading the test body and comparing it to the PRD section.

---

## G. Cross-Domain Contract Same-Source

When a payload shape (e.g. an event, a DTO) crosses domains — REST list
response, SSE frame, SPA parser, mobile client — the three sides MUST
share a single source of truth (OpenAPI schema, generated types, or a
contract test that asserts shape equivalence).

If the project does not yet have a single-source-of-truth generator, the
implementation MUST include at least one **cross-domain contract test**
that constructs an instance on one side and asserts every consumer parses
it without loss. Reviewer REJECTs if a cross-domain payload exists without
either a generator or a contract test.

---

## H. Full Local CI Is the Completion Gate

"Done" means: the project's complete CI command set passes locally, in the
worktree, on the Module Agent's / Integration Tester's / Acceptance
Tester's machine.

The Module Agent reads the project's CI command set from the
`Development Workflow` section of `conventions.md` (and PRD
architecture.md). Typical members:

- Compile / build (`go build ./...`, `npm run build`, `cargo build`, ...)
- Static analysis (`go vet`, `npm run lint`, `mypy`, ...)
- Type-check where separate (`tsc --noEmit`, ...)
- Unit + integration tests (with race detection / sanitizers if the
  conventions specify)
- E2E tests (Playwright, Cypress, or the project's equivalent) for any
  user-facing module
- Any project-specific check (license headers, generated-code freshness,
  schema drift, etc.)

**A module's Module Agent must run the full set before returning APPROVE.**
"My new tests pass" is not enough. If any item in the set is red — even
for a reason apparently unrelated to the current module's work (mock URL
drift, schema drift, a dependency upgrade leftover) — the gate stays red
until it is fixed or converted to a tracked issue with an explicit
`test.skip`.

The Phase Integration Tester runs the same full set. The Acceptance Tester
runs the same full set as the very last action before producing the
acceptance verdict.

---

## I. Reflex: Flip Soft-Pass to Strict on Sight

When any agent (Tester, Reviewer, Integration Tester, Acceptance Tester,
Developer, Module Agent) reads existing test code and notices an A-class
soft-pass, its first action is:

1. Rewrite the test to a strict assertion.
2. Run the test; observe the failure (if any).
3. Fix the underlying implementation defect that the strict assertion now
   exposes.
4. Commit both changes together: `test+fix(M-NNN): strict-assert <criterion> and resolve underlying gap`.

A soft-pass test discovered but not flipped is itself a finding — the
agent that left it in place is in violation of this rule.

---

## J. Report Language: User-Visible, Not Layer

Status reports, module reports, integration reports, and acceptance
reports phrase progress in **user-observable language**:

- **Use:** "J-001 end-to-end verified; F-001-AC-3 strictly asserted PASS;
  three Outstanding Debt items tracked as issues #42, #43, #44."
- **Do not use:** "backend tests pass; frontend tests pass; 217 tests
  green."

Test counts may appear as supporting data, never as the headline metric.
A report that leads with "N tests passing" without naming which PRD
artifacts those tests cover is itself a violation of E and F.

---

## K. Long-Run Re-Anchor

After every phase completes (in Step 2) and before each fix-cycle round
(in Steps 2 / 3), the Orchestrator re-anchors to this discipline file:

- Re-read this file's section headers.
- Run the full local CI set (H above) — not just the new tests.
- Search the diff since the last re-anchor for forbidden patterns
  (A, B, D substrings).
- Refresh `traceability.json` (F above) and confirm the closure rules
  still hold.

Standards drift across a long run is physical. The re-anchor is the
counter-pressure.

---

## L. Strict Scrutiny of Every Deferral

In the retro, the dominant failure pattern was **"deferred because hard,"
silently re-classified as out-of-scope.** Deferral is a load-bearing
decision and is treated as such here: it is not a velocity tool.

Every entry under "Out-of-Scope / Deferred Work" (in any plan, module
plan, or report) MUST satisfy ALL of:

1. **Item field** names a concrete deliverable (≥ 12 characters; not
   "polish UX", "edge cases", "tech debt", "refactor", "improvements").
2. **Reason field** is a *cause*, not a *complexity excuse*. The
   following reason phrases are **forbidden** and trigger REJECT:
   - "too complex" / "complexity" / "complicated"
   - "too hard" / "difficult" / "hard to implement"
   - "no time" / "out of time" / "ran out of time"
   - "will do later" / "do it later" / "later iteration" without a
     specific iteration name
   - "needs refactor" / "needs refactoring" without an issue
   - "scope creep" / "out of scope" as a self-referential explanation
   - "TBD" / "TODO" / "follow-up" / "we'll revisit" / "later"
   - Empty / single-word reasons.

   Acceptable reason patterns are observable causes: dependency on an
   un-merged upstream PR; absence of a third-party API contract;
   regulatory blocker; explicit PRD scoping decision linked from the
   item.

3. **Tracked-In field** carries an `owner/repo#NNN` issue link (per §D)
   that itself contains the PRD reference and the user-visible impact.

4. **Item is not also claimed.** If the same AC id (`F-NNN/ACK`) appears
   in this module's `Acceptance Criteria Mapping` as a PASS row, it
   cannot also appear as Out-of-Scope. A row claiming both is a
   contradiction — pick one and write the other off.

5. **Re-evaluated each fix-cycle.** The Orchestrator's re-anchor (§K)
   re-reads every Out-of-Scope entry and confirms the issue is still
   open and the cause still holds. Stale deferrals (issue closed but
   item still listed; cause resolved upstream) are blockers.

The module Reviewer, Integration Tester, and Acceptance Tester treat
every deferral as a high-cost claim: the burden of proof is on the
deferrer. "It would be a lot of work" is **not** an acceptable answer
when the work is in scope of the PRD.

---

## M. E2E Tests: Assert Outcomes, Cover Failure Paths

E2E tests fail in two specific ways that the previous iterations
repeatedly missed. Both are blockers.

### M.1 No "no error == success"

A test that only proves the absence of an error has not proven the
feature works. The following are **prohibited** as the *sole* assertion
in an E2E (or integration) test:

- `expect(...).not.toThrow()` with no follow-up assertion.
- `expect(err).toBeNull()` / `expect(error).toBeUndefined()` without
  asserting the post-condition (response body, DB row, UI state).
- Go: bare `assert.NoError(t, err)` at the end of the test body.
- Python: `with pytest.raises(...): pass` — exception type unverified.
- Comments framing success as absence: `// should not raise`,
  `# should not error`.
- Selenium / Playwright: `await page.click(...)` followed only by
  `expect(page).not.toHaveURL("/error")` — a 200-response error page is
  still "success" to that assertion.

**Required:** every E2E test asserts the user-visible outcome that the
acceptance criterion says will happen. Concretely:

- **HTTP**: status code AND response body shape AND, where the AC
  promises persistence, a follow-up read (GET / DB query) that confirms
  the new state.
- **UI**: the new screen / element / text / disabled-state that the AC
  promises is queried and asserted.
- **Side effects**: emails, queue messages, audit-log rows, webhook
  fires — when the AC names them, the test asserts they actually
  occurred (test double or real receiver).

### M.2 Happy Path Is Half a Test

Every journey covered by traceability MUST have at least one
**negative scenario** alongside the happy path. A negative scenario is
one of:

- **error**: an explicit precondition violation listed in the PRD
  (invalid input, unauthorized actor, missing dependency, conflicting
  state). The test asserts the *specific* error response — status code,
  error code, error message — promised by the AC.
- **boundary**: an edge value that the PRD or its data-model bounds
  (zero, max length, expiry, empty list, exactly-one item, last page).
- **concurrency / idempotency**: when the AC names retries, double
  submits, or simultaneous actors, those paths are tested.

A journey whose traceability lists only `kind: happy` scenarios is
incomplete. Either add the negative scenario, or open an issue and mark
the missing scenario `NOT_COVERED` with that issue link (per §F).

`reports/traceability.json` MUST therefore record a `kind` field on
each journey scenario:

```json
"journeys": [
  {
    "id": "J-001",
    "scenarios": [
      { "kind": "happy",    "test": "tests/e2e/J-001-checkout.spec.ts", "status": "PASS" },
      { "kind": "error",    "test": "tests/e2e/J-001-checkout-card-declined.spec.ts", "status": "PASS" },
      { "kind": "boundary", "test": "tests/e2e/J-001-checkout-empty-cart.spec.ts", "status": "PASS" }
    ],
    "status": "PASS"
  }
]
```

The Acceptance Tester REJECTs any journey that lacks at least one
non-`happy` scenario unless the traceability file documents the gap
with a tracked issue.

---

## N. Missing Dependency = Implement It, Don't Abandon

The retro identified a recurring failure: when a Developer / Module
Agent discovered that an upstream dependency was unimplemented (a
function that should exist on M-001 but doesn't yet, a route the
journey calls but no module owns, a schema field referenced in the
plan but never declared), it gave up on the **current** module —
returning APPROVE with a stub, an early-return, a "TODO: needs M-001"
comment, or a `test.skip`. This is the single biggest source of
silent debt in the pipeline.

**The rule: a missing dependency in scope of the current PRD/design is
a unit of work to be completed, not a reason to stop.** Abandoning a
module because its dependency is unimplemented is forbidden.

When a sub-agent encounters a missing in-scope dependency:

1. **Verify the dependency is truly in-scope.** It is in-scope if (a)
   it appears in the design's module list, (b) it is referenced by a
   journey touchpoint or feature AC in the PRD, or (c) any module's
   plan in this autoforge run names it as a dependency. If none of
   these hold and the dep is genuinely external (third-party API,
   un-merged platform PR), §D / §L apply instead.

2. **Do NOT stub, mock past, or `// TODO` the call site.** Do not
   return APPROVE with a fake implementation. Do not skip the test
   that exercises the dep. Do not invent a substitute interface.

3. **Escalate to the orchestrator with `PLAN_REVISION_NEEDED`** —
   issue type `UPSTREAM_INSUFFICIENT` (the upstream module is missing
   functionality this module needs) or `UPSTREAM_NOT_IMPLEMENTED` (no
   module owns the capability yet). The orchestrator's job, on
   receiving this signal, is one of:

   - Re-dispatch the upstream module's pipeline to add the missing
     surface in *this* round (default action).
   - If no module owns it, dispatch the Planner to allocate the work
     to the right module (or split a new module M-NEW) and run it
     before resuming this one.
   - Only after both of the above are exhausted may the orchestrator
     return DECISION_REQUEST to the user.

4. **The current module is paused, not closed.** The Module Agent
   does not return APPROVE; it returns PLAN_REVISION_NEEDED. State is
   persisted (`module-state-M-{id}.json`) so execution resumes once
   the upstream work lands.

5. **No "skip the failing test" workaround.** A test that fails
   because a downstream call returns `not implemented` MUST stay
   failing (not red-but-skipped, not flipped to a softer assertion)
   until the upstream module ships the call. The Tester does not
   adjust the test to make it green.

The orchestrator's re-anchor (§K) explicitly looks for stalled
"upstream waiting" modules and does not declare a phase complete
while any module is in that state for an in-scope dependency.

**Forbidden patterns that signal abandonment** (Reviewer / Integration
Tester / Acceptance Tester scan the diff and module reports for these
and treat each as REJECT):

- `// stub for M-XXX` / `// pending M-XXX implementation`.
- `if (!feature) return; // M-XXX not ready` — short-circuit guards
  that bypass the dep silently.
- `test.skip("waiting on M-XXX", ...)` without an issue link.
- Module Status row "BLOCKED on M-XXX" where M-XXX is also listed in
  this autoforge run's plan (i.e., it is in-scope and should have
  been implemented, not waited on).
- Acceptance report Verdict "PASS with caveats: M-XXX not yet built"
  when M-XXX is part of the design.

---

## Quick Self-Check Before Returning a PASS

Before any sub-agent reports PASS / APPROVE, it must answer YES to all:

1. No A-class soft-pass test patterns in any file I touched or read?
2. No B-class silent write-path patterns in any file I touched or read?
3. Every owned model registered, route mounted, middleware inserted (C)?
4. Every TODO / FIXME / "tracked as follow-up" converted to an issue (D)?
5. Every PRD-named test actually exercises its PRD reference (E)?
6. Traceability closure holds for the artifacts in scope (F)?
7. Cross-domain shapes are generator-bound or contract-tested (G)?
8. Full local CI set was run on the current diff and is green (H)?
9. Soft-pass tests I encountered were flipped, not preserved (I)?
10. My report uses user-visible language (J)?
11. Every Out-of-Scope row passes the §L scrutiny (concrete item, causal
    reason, open issue, not also claimed elsewhere)?
12. Every E2E test I added or read asserts the user-visible
    post-condition, not just the absence of an error (§M.1)?
13. Every journey in scope has at least one negative / boundary
    scenario alongside the happy path, or a tracked issue noting the
    gap (§M.2)?
14. No in-scope dependency was abandoned, stubbed, or skipped this
    round — every missing upstream surface is either implemented or
    escalated as PLAN_REVISION_NEEDED (§N)?

Any "no" is a blocker. Fix it, or surface it as a finding / issue, before
flipping the gate.

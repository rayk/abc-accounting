# Contract Authoring Spec

**Status:** Agreed in design session 2026-06-23. Supersedes the brief/harness machinery in
`WORKSPACE_PATTERN_SPEC.md` — the `withContext` / `forImplementation` / `CONTEXT` / `TYPEDEF:` /
`sealed XxxError` header / `tool/harness.dart` machinery is fiction and is deleted on adoption.

**Scope:** the general contract-first authoring practice for Lucid Commons bounded packages.
`abc_accounting` is the development **fixture**, not the product. Engine = `bnd_eac`, a **general, independent** package (depends only on checks/glados/fpdart/test).
The **Lucid-specific bindings** — `cmo_failures`, `cmo_model`, the `Validated` handling, the
steering lens — layer *above* it, in each package's contract kit today; they extract into a shared
`cmo_dsl` only when a second package proves the need (accretion). `cmo_dsl` is **not** assumed.
Foundations (full support, assumed): `package:checks` (assertions), `cmo_failures`
(Tier-0 failure values), `glados` (property testing), `fpdart` (functional transport).
New mechanisms are Dart packages only — no codegen, write-and-run Dart throughout: `fake_async`
1.3.3 and `async` 2.13.1 are already transitive `test` deps (no pubspec change needed);
`parameterized_test` 2.0.3 requires an explicit `dev_dependencies` entry and SDK `>=3.8.0`.

**North star:** a contract drives an ALCA to implement via red→green TDD, exposing the *smallest
sufficient* surface. Every artifact derives from one declaration — so the map cannot drift from
the territory.

---

## 1. Principles

1. **Single source of truth.** Inventory, steering, tags, and IDs all derive from the declaration.
   Declaration↔binding joins are **enforced**: an unbound rule, or a binding citing an unknown
   rule, is a hard error.
2. **Run-to-red.** A contract is not implementable until it compiles, runs, and fails *red*.
   Signatures are **real declared interface symbols**, unimplemented (throw via the registration
   seam) — never paper. Every inventory import must resolve against the target package's
   `pubspec.yaml`; an unresolvable import is a hard error.
3. **Accretion, not modification** (post-publish): published semantics are frozen forever; new
   behaviour = a new symbol / new namespace, old and new concurrent. Draft phase churns freely.
   "Published vs draft" is an explicit state.
4. **Data-oriented, immutable, functional** (fpdart): types are inert data (standard types in/out,
   no behaviour); behaviour lives only in the one abstraction + the signatures.
5. **No barrels.** Interface packages declare published symbols directly in their public library,
   so a symbol's library URI *is* its importable path.
6. **Two ALCA surfaces, gated by the harness:** an **orientation inventory** (what to build) and
   **failure steering** (composed on red). We produce harness-ready outputs; we do not build the
   harness — we only guarantee its interface (stable IDs + tags + structured sidecar).

---

## 2. Declaration surface

```dart
final ledgerTypes = Contract(
  name: 'ledger_type_contract', version: Version(0, 1, 0),
  purpose: 'The Ledger and the types it knows.', tags: {'ledger', 'types'},
)
  ..type<AccountStatus>(describe: 'Whether the account can transact', structure: '(bool canTransact)')
  ..type<Money>(describe: 'A monetary value')
  ..type<Ledger>(describe: 'Tracks the movement of value');

final accountOpening = Contract(
  name: 'account_opening', version: Version(0, 1, 0),
  purpose: 'Open an account.', dependsOn: {ledgerTypes}, tags: {'operations', 'account'},
)
  ..signature(openAccount,                        // the REAL interface fn → File:/Function: via mirrors; unimplemented ⇒ red
      purpose:    'Creates a new Ledger for the given AccountId.',
      invariants: [accountOpenIsTransactable],    // [Rule<T>]
      failures:   [openingRejectedInsufficient]); // [FailureMode<E>]
```

- **`importable` (library URI) is derived via mirrors** — from the declared symbols' libraries
  (no barrels). The old contract-side scaffold *and* the File: override are both retired.
- **Structure and function/type-string fields are AUTHORED, drift-checked** — `dart:mirrors` erases
  extension types and typedefs: `Money` → `int`, `AccountId`/`Version` → `String`/`int`,
  `LedgerResult = Future<Either<LedgerError, AccountState>>` → bare `Future`. For any symbol
  bearing an extension type or typedef, the structure, parameter types, and return type are
  **authored strings** (see §7 inventory), NOT mirror output. The `type_config.dart` /
  `typeOverrides` pattern is RETAINED for this purpose — do not retire it.
  Plain enums and classes (e.g. `AccountStatus`) mirror fine.
  The `describe()`-based drift check (§8) is the mechanism guarding these authored strings — not
  a nice-to-have but the lint that keeps authored ↔ declared in sync.
- **Errors are `type<E>` registrations** referenced by `FailureMode<E>` — there is no separate
  `error` concept (an error is a concrete value type like any other; DIP applies to behaviour,
  not data).
- **Types may come from shared packages** (symmetric to failures). `type<T>` accepts `T` declared
  in a third package — DDD value objects from the Lucid types library, errors from the fixture's
  own sealed hierarchy, etc. Each symbol's importable derives from *its own* declaring library,
  so a contract's import set spans packages (contracted interface + types + failures).

### `requires` / `ensures(old())` / `effects` — three optional `..signature` clauses

```dart
..signature(transferFunds,
    purpose:    'Move value between two Ledger accounts.',
    invariants: [balanceNonNegative],
    failures:   [insufficientFunds],
    requires:   [                             // PRECONDITIONS — input-domain predicates
      (args) => args.amount > Money.zero,     // desugars to a guard-rejection check;
      (args) => args.from != args.to,         // auto-derives a negative Case per predicate
    ],                                        // feeds MISSING_GUARD steer if absent
    ensures:    [                             // POSTCONDITIONS relative to pre-state
      (old, result) => result.fold(           // `old(x)` = SUT pre-state captured before act;
        (_) => true,                          //   resolves via softCheck on the settled result
        (s)  => s.balance == old.balance - args.amount),  // INPUT-RELATIVE fact declared once
    ],
    effects:    [persist(Account), emit(TransferCompleted)]);  // declared side-effects
```

**Three-category resolution of the Rule vs Case-then tension** (updates the note above):
- **Intrinsic `Rule<T>`** — true of ANY valid result regardless of input (`status == open`).
- **Input-relative `ensures`/`old()`** — declared once on the signature; `old(x)` binds the
  captured pre-state before the act; the postcondition is verified via `softCheck` on the
  settled result (`balance == old(balance) - amount`, `version == old(version) + 1`).
- **Per-case `then`** — bespoke expectations for a single witness or region.

`requires` desugars to a guard-rejection check for each predicate and auto-derives a negative
`Case` feeding a `MISSING_GUARD` steer — fewer hand-authored negative cases. `ensures` does NOT
replace per-case `then`; it captures the class of facts that are true across all valid inputs.

`effects` declares the expected side-effects (e.g. `persist(Account)`, `emit(TransferCompleted)`).
The harness verifies "no effect committed on a rejection/failure" and "at-most-once emit". This
makes prose steers ("create no Ledger") mechanically checkable. All three clauses are Dart-native
lists/small helpers on `..signature` — no new language.

### Rule — positive invariant (reusable, executable, drift-proof)

```dart
final accountOpenIsTransactable = Rule<AccountState>(
  id:        'state-open',                                       // kebab, unique-in-contract → tag rule-state-open
  text:      'A newly opened account must have status == open',  // ONE atomic normative invariant
  condition: (it) => it.has((s) => s.status, 'status').equals(AccountStatus.open),
);
```

`describe(condition)` is surfaced beside `text` → active drift *detection*, not just prevention.
Atomic: one invariant per Rule (compound invariants split).

**Rule vs Case-then discipline.** A `Rule<T>` expresses an INTRINSIC invariant — true of ANY
valid result regardless of input (e.g. `status == open`, `balance >= Money.zero`, version
monotonic). Input-relative expectations (`balance == start + deposit`, `version == before + 1`)
belong in the per-case `then` clause, NEVER in a reusable `Rule`. Bool-shaped Rule conditions
yield `which = null` in the rejection — steering becomes unrenderable; prefer equals/relational
conditions so the render can show `field-value-vs-concrete`. Name roles distinctly:
`Rule<T>` (operates on result `T`) vs `Law<I>` / `Property<I>` (operates on inputs `I`).

### FailureMode — negative, over the `Left` branch

```dart
final openingRejectedInsufficient = FailureMode<InsufficientFunds>(
  // tag: failure-InsufficientFunds
  when:  'the opening deposit exceeds available funds',
  steer: 'return Left(InsufficientFunds(balance:…, requested:…)); create no Ledger',
  where: (it) => it                                           // OPTIONAL Condition<E>; isA<E>() implied
      .has((f) => f.balance, 'balance').isLessThan(f.requested),
);
```

`InsufficientFunds` carries `balance` (Money) and `requested` (Money) — see
`abc_accounting/lib/src/contract/vocabulary.dart`. There is no `.code` field and no
`extends DomainFailure`; the fixture's `LedgerError` is a sealed hierarchy (`sealed class
LedgerError with Value`) with structural value-equality via `mixin Value`.

Matcher = `isA<E>()` + optional field-`Condition<E>`. MUST NOT assume absence of `==` — the
pattern works for both value-equal `LedgerError` and any future identity-only `Failure`.
`rejects` matches the `FailureMode` **within** an `IList` Left (contains; optionally assert
count/set) for accumulated-validation shapes.

### Case — Given/When/Then, the unifying skeleton (lives in the binding)

```dart
Case('overdrawn opening is rejected',
  given: anOpening(deposit: 150, available: 100),  // witness (value) | region (where:) | law (forAll:)
  when:  openAccount,                              // defaults to the signature; explicit only for sequences
  then:  rejects(openingRejectedInsufficient));    // succeeds([Rule]) | rejects(FailureMode)
```

- The **`given` flavour picks the kind**: a value → **witness**; a predicate → **region**;
  `forAll(gen)` → **law**.
- `Boundary(inside:, outside:)` = two cases sharing a threshold `given` (the edge where bugs live).
- `then` picks positive vs negative.

---

## 3. Execution

- **Binding** supplies arrange/act only; assertions go through a `softCheck`-backed primitive
  (structure captured, not thrown): `bind(accountOpening, () { /* Cases… */ });`
- **`softCheck` / `softCheckAsync` → `Rejection{actual, which}` → composed steering.** No
  hand-written `reason:` strings. **`softCheck` is synchronous** — wiring it over a `Future` or
  `Stream` returns `null` (silent false-PASS). Use `softCheckAsync` for any async act. This is a
  hard trap: a green result over an unresolved `Future` is indistinguishable from a true pass.
- **Stream-shaped `then`:** the fixture exposes `Stream<AccountState> get changes`
  (`abc_accounting/lib/src/contract/ledger.dart`). Stream cases use a `then` family backed by
  `StreamQueue<AccountState>` (pulls ordered emissions via `.next`/`.peek`/`.take(n)`) rather than
  `StreamChecks` matchers — this sidesteps the earlier `OutsideTestException` concern: `StreamQueue`
  never calls `TestHandle.current`, and `package:checks` works inside a `fakeAsync` zone (zone-value
  lookup walks up to the test zone). Stream cases run **serial in a test zone**; parallel execution
  corrupts order. Tag these cases `kind-stream`. The `Rejection` shape is identical but
  position-indexed: `Got = "failed at emission index N"` / `"threw at step N"`. Sidecar ID segment:
  `seq-step-N`. `StreamQueue` works on broadcast streams (confirmed for `Stream<AccountState> get
  changes`); call `.cancel()` when done.
- **`runSequence` async driver** handles multi-step `when: sequence([...])` cases. Tag
  `kind-sequence`. Serial execution only.
- **Laws via glados, driven directly (NOT `.test()`):** the harness re-implements the ~30-line
  explore+shrink loop — glados's phases are private inside `.test()`; `Generator` and
  `Shrinkable` are public. Explore over `Generator<I>`, shrink the counterexample, re-`softCheck`
  for the structured `Rejection`. A law pairs a `Generator<Inputs>` with its OWN
  `Condition<Inputs>` (a `Law<I>` / `Property<I>`); it does NOT reuse a result `Rule<T>` as its
  predicate — that is a type error. Import `package:glados/glados.dart` `hide test`.
  Prefer a restricted generator (`any.positiveInt.map(Money.new)`) over `assume()` — `assume()`
  discards samples and skews the distribution. State the generator domain in the law's `given`
  so a shrunk witness (`Money(0)`) is interpretable without context.
  The sidecar carries TWO separate seeds: `gladosSeed` (exploration) and `orderingSeed` (test
  order). The harness owns the glados int seed — `dart:math Random` has no `.seed` getter, so
  the seed is stored and re-passed for repro.
- **Red-by-throw first-class:** the FIRST red is an unimplemented-seam THROW (`ops => throw
  UnimplementedError()`), not a settled `Either`. Wrap the act, synthesize
  `Got: threw UnimplementedError (unimplemented seam)`,
  `Steer = signature.purpose + the case's declared then`. Distinguish seam-throw ("implement the
  body") from domain-reject ("reject before mutating", settled `Left`).
- **`parameterized_test` for tables** (`parameterized_test 2.0.3` — NOT transitive; add explicitly
  to `dev_dependencies`; requires SDK `>=3.8.0`). The middle ground between one witness and a full
  glados law. Use `parameterizedTest(description, rows, body)` where each row is a `List` of
  arguments; per-row options via `.options(tags: 'kind-boundary', skip: ..., timeout: ...)`. Three
  canonical uses:
  - **`Boundary` pair** — inside/outside samples sharing a threshold, each a row; tags derive
    per-row (`kind-boundary`).
  - **Enumerated `region` samples** — multiple witnesses for a stated region, one row each.
  - **Negative-case table** — `(input, expectedFailureMode)` rows covering the full failure-mode
    matrix; compresses many hand-authored `Case`s. Per-row tags keep derived hyphen tags and stable
    IDs working per row (confirmed). Also `parameterizedGroup` for grouped row families.

- **Selection:** native `dart test --tags` with the derived convention; boolean tag selectors
  scope the inner loop (`"contract-account_opening && failure-InsufficientFunds"`).
- **Identity:** stable hierarchical IDs `contract/signature/unit:id`
  (e.g. `account_opening/openAccount/rule:state-open`). Readable for the ALCA; stable key for the
  harness's statistics ("failing 4 runs running").
- **Sidecar:** one structured object → two sinks (human render + JSON keyed by stable ID):
  `{id, kind, given, when, then, outcome, rejection|diagnostics, tags, gladosSeed, orderingSeed}`.

### §3a — Async, streams & time

**Principle:** spec the OBSERVABLE TIMELINE, never control flow. No `await`/`Future` in the
contract declaration; the harness mechanism is `fakeAsync`+`StreamQueue` for deterministic replay.

**Lifecycle clause** — observable state machine for async/stream signatures:

```dart
..signature(submitTransfer, ...,
    lifecycle: Lifecycle(
      states:    [pending, settled, failed],
      pending:   ensures(noEffectCommitted),     // no mutation while in-flight
      onCancel:  ensures(noEffect),
      onFailure: ensures(stateUnchanged),
    ),
    timing: Timing(
      within: Duration(seconds: 5), else_: TimeoutFailure,
      settles: Duration(seconds: 10),
      retry:  Retry(max: 3, on: NetworkFailure),
    ),
    concurrency: Concurrency(
      idempotentBy: requestId,
      atomic:       true,
      atMostOnce:   emit,
      isolation:    snapshot,
      ordered:      emit,
    ),
    compensate: onFailure(revert(AccountState)));
```

Maps to Riverpod `AsyncValue` (loading/data/error) — resolves the Riverpod-provider gap.

New temporal `then` forms: `state is X` · `within(5.seconds) state is X` · `eventually state is X`.

**Mechanisms (cite verified APIs):**

- **`fakeAsync`** (`fake_async 1.3.3`, already a transitive `test` dep):
  `fakeAsync((async) { async.elapse(6.seconds); async.flushTimers(); async.flushMicrotasks(); })`.
  Virtual clock; deterministic. Every temporal/concurrency check runs inside this zone — e.g.
  `async.elapse(6.seconds)` to trip a 5 s deadline; `async.flushTimers()` for "eventually settles".
  Sharp edges: real I/O escapes the zone; `DateTime.now()` and `Stopwatch` are NOT intercepted —
  use `clock.now()` from `package:clock`, which `fakeAsync` auto-wires; nested `elapse` throws.
- **`StreamQueue<T>`** (`async 2.13.1`, already a `test` dep): wraps `Stream<AccountState> get
  changes`; pulls ordered emissions via `.next`, `.peek`, `.take(n)`; `.eventsDispatched` for
  count assertions; `.cancel()` when done. Replaces the earlier `StreamChecks`/test-zone approach.
  **Broadcast-stream ordering constraint (verified):** `StreamQueue` subscribes then immediately
  *pauses* on construction; it resumes only while a `.next`/`.take` request is pending, so events
  emitted with no outstanding request are **silently dropped** (`eventsDispatched` stays 0 — a
  green-but-asserts-nothing trap, exactly what the practice exists to prevent). Pattern: pull
  first, then emit — `final next = queue.next; controller.add(x); async.flushMicrotasks();`.
  Steering for stream failures is position-indexed (emission index N); sidecar records the schedule
  for reproducibility. Tag `kind-stream`.
- **`CancelableOperation`** (`async`): `CancelableOperation.fromFuture(f, onCancel: ...)` —
  `.cancel()` / `.valueOrCancellation()`. Use for cancel/atomicity-under-cancel checks.
- **`FutureGroup<T>` / `StreamGroup<T>`** (`async`): fan-out concurrency and merged-stream cases.
- **`Result.capture(future)` / `Result.release(captured)`** (`async`): BOTH STATIC — there is no
  instance `.release()`; use `Result.release(await Result.capture(f))` to unwrap.
- Stream/sequence cases run **serial** in a test zone; tag `kind-stream` / `kind-sequence`.
  Steering is position-indexed; the schedule is recorded in the sidecar for reproducibility.

---

## 4. External foundations — full integration

> **§4.1 / §4.2 are CO-EVOLUTION TARGETS, not the fixture's present state.** The fixture
> (`abc_accounting`) currently imports zero `cmo_*` packages. Its `LedgerError` is a sealed
> hierarchy with value-equality via `mixin Value` (`abc_accounting/lib/src/contract/vocabulary.dart`).
> The design below describes the intended Lucid layer once `cmo_failures` / `cmo_model` co-evolve
> with `bnd_eac`. Do not treat this section as describing the fixture today.

*These bindings live in the **Lucid layer** (contract kit today; a future `cmo_dsl` only if
accretion justifies it), keeping the general `bnd_eac` engine free of stack-specific deps.
"Full support" means the Lucid layer integrates them fully; the engine keeps its generics unbounded.*

### 4.1 Failures — `cmo_failures` (co-evolution target)

- `FailureMode<E extends Failure>` bound to the Tier-0 sealed `Failure`. The engine reads its
  fixed fields directly (no cast/reflection): `message`, `category`(`.retryable`), `blame`,
  `recovery`, `diagnostics{what, expected, actual}`, `scenario`, `tags`, `trail`.
- **Default steering = `failure.toString()`** (already authored *as* an ALCA prompt) and map
  `diagnostics.expected/actual` → the `Then`/`Got` rows of the steering.
- `category` / `recovery` feed the harness's retry & statistics decisions.
- Match by **type + field-conditions, `isA<E>()` implied** — MUST NOT assume absence of `==`
  (the pattern works for both value-equal `LedgerError` and identity-only `Failure`). Domain
  errors do NOT automatically extend any common subtype — check the real sealed hierarchy.
  Example using the fixture's real variant fields:
  ```dart
  final openingRejectedInsufficient = FailureMode<InsufficientFunds>(
    when:  'the opening deposit exceeds available funds',
    steer: 'return Left(InsufficientFunds(balance:…, requested:…)); create no Ledger',
    where: (it) => it
        .has((f) => f.balance, 'balance').isLessThan(it.requested),
  );
  ```
  (`InsufficientFunds` carries `balance` and `requested`; no `.code` field; no `extends DomainFailure`.)
- **Fixture import set today** (derived, not hand-listed):
  `{package:abc_accounting/..., package:fpdart/...}`. No `package:cmo_failures` until co-evolution
  lands.
- Logistics: git dependency (`publish_to: none`); it pins `fpdart ^1.1.0` — compatible with the
  workspace's `1.2.0`.

### 4.2 Domain types — DDD value objects (`cmo_model` v0.2.0, early-stage; co-evolution target)

A contracted package draws its domain **types** from `cmo_model` (Tier-1 "citable ground-truth
vocabulary"); the DSL references them first-class, mirroring the failures side.

- **Bind `type<T extends ValueObject>`** — the deliberate sibling to `cmo_failures.Failure`. The
  bound buys the value-equality guarantee + `is ValueObject`, but the marker is **empty**
  (`abstract interface class ValueObject {}`): the engine reads structure from `Equatable.props` +
  `toString()` (`stringify => true`) + the smart-constructor signature, **not** marker members.
  Keep an unbounded escape hatch until cmo_model stabilises. (`ScalarValue<T extends Object>` holds
  the `.value`; `CompositeValue` is also a bare marker.)
- **Value equality holds** (via `Equatable`, type-discriminated) — confirms the contrast: VOs are
  value-equal (`equals(...)` directly), Failures identity-only (type+fields).
- **Validation accumulates failures.** Smart constructors are free functions
  `raw → Either<IList<Failure>, VO>`, aliased **`Validated<T>`**; the Left is an *`IList`* of
  `cmo_failures.Failure` (not fail-fast). So `rejects` supports both a single `Left(E)` and
  "the `IList<Failure>` Left **contains** this `FailureMode`" (optionally assert count/set).
- **Smart constructors are contracted signatures** — `emailAddressOf(String) → Validated<EmailAddress>`
  is a `signature`: positive (valid → `Right(vo)`), negative (invalid → `rejects` over the IList).
  No new machinery; the package's own tests already follow this shape by hand.
- **Constraints are not reflectable** (invariants live in constructor bodies; the internal
  `Spec`/`Predicate` algebras aren't exported/attached). So invariants are **declared as our
  `Rule`s in the contract**, not auto-derived from the type — which single-source wants anyway.
- **`Map<String,dynamic>` is an ESCAPE HATCH, not the default.** Using bare maps introduces
  false-passes (a `null` actual on a map field means the key may be absent or misnamed — steering
  cannot distinguish). Close these in the kit: typed `field<R>()` accessor with a `containsKey`
  guard + key-set validation at Rule registration; prefer real value objects so discriminators are
  compile-checked. Steering hint when actual is bare-null on a map field: "key may be absent or
  misnamed".
- **Blocker [state]:** cmo_model's public barrels don't resolve today — they import a renamed-away
  `src/kernel_old/` (`values.dart`/`scalars.dart`/`validation.dart` broken; README empty; CHANGELOG
  pre-rename). Implementation is real/green via deep imports. Pin a known-good commit and either
  deep-import `src/kernel/...` or **fix the barrels first** (`kernel_old → kernel` + re-point
  `Validated`) — a co-evolution task.

---

## 5. glados — full integration (see §3 Laws)

- Public `Generator<T>` (`= Shrinkable<T> Function(Random, int)`) / `Shrinkable<T>` primitives;
  deterministic via `ExploreConfig(random: Random(seed))` (default `Random(42)`).
- fpdart generators built via `map`/`oneOf`/`combine` (no built-in support); custom domain via
  `any.simple` / `combine2..10` / `choose`. Register defaults with `Any.setDefault<T>`.
- Risks banked: glados 1.1.7 (~2yr, unverified uploader) but already a workspace dep, runs on
  Dart 3.12; its SDK upper bound may need a future `dependency_overrides`/vendor. Shrink is
  greedy/local (small, not globally minimal); single-threaded — tune `numRuns` for expensive
  properties; always write `any.<type>` inside `Any` extensions.

---

## 6. Tags convention (all derived)

`contract-<name>` · `sig-<name>` · `rule-<id>` · `failure-<E>` · `case-<id>` ·
`kind-<positive|negative|boundary|law|stream|sequence>`

**Tag delimiter is HYPHEN.** Dart's `--tags` parser requires hyphenated identifiers:
`dart test --tags 'contract:account_opening'` fails with "Expected end of input" (exit 64);
`@Tags(['sig:deposit'])` fails with "Tags must be hyphenated Dart identifiers".
`kind-stream` and `kind-sequence` mark stream-shaped and multi-step sequence cases respectively.

Stable hierarchical **sidecar IDs** (`contract/signature/rule:state-open`) retain `:` and `/`
as structural separators — they are never passed to `--tags`.

---

## 7. ALCA artifacts

**Inventory integrity:** every import in the inventory MUST resolve against the target package's
`pubspec.yaml` — an unresolvable import is a hard error (extends Principle 2). Failure types must
match the real interface return type; read the declared sealed hierarchy and the typedef
(`LedgerResult = Future<Either<LedgerError, AccountState>>` in `abc_accounting/lib/src/contract/ledger.dart`).
Function and type fields are built from **authored strings**, not mirror output (mirrors erase
extension types and typedefs — see §2).

**Orientation inventory** — per signature, from the declaration *alone* (before any implementation):

```json
{"kind":"inventory","contract":"account_opening","file":"lib/src/contract/ledger.dart",
 "function":"openAccount(AccountId) → Future<Either<LedgerError, AccountState>>",
 "imports":["package:abc_accounting/abc_accounting.dart","package:fpdart/fpdart.dart"],
 "purpose":"Creates a new Ledger for the given AccountId.",
 "grounding":"AccountState.empty(id)",
 "dependsOn":["ledger_type_contract"],
 "invariants":[{"id":"state-open","text":"A newly opened account must have status == open"}],
 "failures":[{"type":"InsufficientFunds","when":"the opening deposit exceeds available funds"}],
 "tags":["contract-account_opening","sig-openAccount"]}
```

`grounding` is optional: a concrete seed artifact (authored from interface vocabulary) that
grounds the case without contaminating the declaration-derived `purpose`.

**Steering (Steer-first render)** — per failing unit, keyed by stable ID:

```
account_opening/openAccount/case-overdrawn-opening
  Steer  Return Left(InsufficientFunds(balance: Money(0), requested: Money(150)));
         create no AccountState
  Got    Right(AccountState(id: AccountId('acc-1'), status: AccountStatus.open, …))
           ← rejection.actual
  Given  AccountState.empty(AccountId('acc-1')), deposit Money(150), available Money(0)
  When   openAccount
  Then   rejects InsufficientFunds where balance < requested
```

Steering conventions (ALCA panel):
1. **Steer-first in machine output** (`ID → Steer → Got → Given → When → Then`). Steer-last is
   retained for human-readable reports only.
2. **Positive imperative** (verb-first; never "do not …").
3. **Typed Dart literals** (`Money(0)` not `0`; `AccountStatus.open` not `'open'`;
   `Left(AmountMustBePositive(amount))`).
4. **Constructor signature primary**, `toString()` secondary (subordinate "Rendered as:" line).
5. **Stable-ID header** on every block.
6. **Steer template:** "[positive verb] [domain object] [to/with/via] [exact named artifact]" —
   name `AccountState.empty(id)`, never "the initial state".
7. **Boundaries as math** (`minorUnits > 0`, not "strictly positive").
8. **`IList<Failure>` matching** = contains-any-order unless order is a stated invariant.
9. Given/When/Then retained but **subordinate to the Steer line**.

**`failureClass` field** — every steering block carries a `failureClass` tag that routes the
repair-directive shape:

| `failureClass`  | Directive shape |
|-----------------|----------------|
| `MISSING_SYMBOL` | "implement the body" — seam threw; no settlement yet |
| `MISSING_GUARD`  | "reject before mutating" — body runs but no domain guard present (`requires` predicate failed) |
| `POSTCONDITION`  | "`ensures`/`old()` violated" — settled result differs from pre-state expectation |
| `TEMPORAL`       | "timing/lifecycle constraint missed" — attach deterministic fakeAsync schedule as REPRODUCER |
| `CONCURRENCY`    | "ordering/idempotency/atomicity violated" — attach interleaving as REPRODUCER (not "flaky") |
| `POLICY`         | "policy rule violated" — wrong Left variant or missing Right guard |
| `COMPENSATION`   | "rollback not applied" — saga/compensate clause not reached |

`MISSING_SYMBOL` vs `MISSING_GUARD` cleanly distinguishes the seam-throw ("implement the body")
from the domain reject ("reject before mutating, settled Left") — finishing the seam-throw item.
For `TEMPORAL`/`CONCURRENCY`, the deterministic `fakeAsync` schedule / interleaving is attached as
a REPRODUCER — these failures are NOT flaky; the virtual clock guarantees replay.

**DO NOT guardrail** — prepended to every steering render:

```
DO NOT edit, weaken, or skip this test.
DO NOT throw — return a settled value (Left or Right) per the declared failures.
DO NOT mutate state before a guard check passes.
If this check appears wrong, escalate SPEC_SUSPECT to the human author — do not self-edit.
```

Integrity guarantee: the ALCA never sees the test source (the harness gates access to the
declaration only), which structurally forecloses test-cheating — our equivalent of hash-locking.
The only legal escape from a genuinely-wrong check is a `SPEC_SUSPECT` escalation to the human.

**Seam-throw (unimplemented)** — the FIRST red is a throw, not a settled `Either`:

```
account_opening/openAccount/case-overdrawn-opening
  Steer  Return Left(InsufficientFunds(balance: Money(0), requested: Money(150)));
         create no AccountState. (implement the body — seam threw)
  Got    threw UnimplementedError (unimplemented seam)
  Given  AccountState.empty(AccountId('acc-1')), deposit Money(150), available Money(0)
  When   openAccount
  Then   rejects InsufficientFunds where balance < requested
```

---

## 8. Open / deferred

- The **harness** itself — separate mission; we only guarantee its interface (IDs + tags + sidecar).
- **`cmo_model` barrels broken** (`kernel_old` rename) — pin/fix before importing its public API;
  integration designed in §4.2. Co-evolve it (as with `bnd_eac`).
- **DSL home (decided):** `bnd_eac` stays general & independent (the engine, unbounded generics).
  The Lucid bindings (`E extends Failure`, `T extends ValueObject`, `Validated`, the steering lens)
  live in the **contract kit** now; `cmo_dsl` is **not** assumed — it accretes only when a second
  Lucid package needs the same glue (the stack's own anti-scaffolding rule).
- **Test execution (resolved):** `test_randomize_ordering_seed: random` MUST be paired with
  re-authoring the order-dependent scenario
  (`abc_accounting_contract/lib/src/scenarios/001_account_lifecycle.dart`, which uses a shared
  `late Ledger` across groups) into a single sequence body with `runSequence` — not a standalone
  config line. Record `orderingSeed` (+ `threwType?`) in the sidecar. Stream and sequence cases
  are always serial; parallel execution is only safe for hermetic witness/region/law cases.
- **Steering language (resolved):** folded into §7 (Steer-first render; positive imperative; typed
  Dart literals; constructor-signature primary; stable-ID header; Steer template; math boundaries;
  IList contains-any-order; GWT retained-subordinate). The only remaining minor open items are
  cosmetic rendering preferences — no further panel review needed.
- **`describe()`-based drift check (resolved — not nice-to-have):** the mechanism that guards
  authored type-strings (see §2 mirrors note). Must run at contract load time; a mismatch is a
  hard error, not a warning.
- **Publish-vs-draft** state machine (formalise the accretion boundary).
- Inherited fix-now cleanups (dead `isFactoryRegistered`, `di/providers.dart` "public interfaces"
  wording, the "Never modified" provenance stamps, duplicate architecture tests) — fold during the
  fixture migration.

---

## 9. Next: fixture-first build

Write the wished-for `account_opening` contract against a local `bnd_eac` override → it fails for
the *right* reason (engine doesn't support it yet) → build the engine in this order until
green-then-red. `abc_accounting` proves each feature as it lands. Contracts in
`abc_accounting_contract/lib/src/contracts/001_open.dart` .. `008_change_feed.dart` and scenarios
in `abc_accounting_contract/lib/src/scenarios/001_account_lifecycle.dart` are the fixture targets.

Engine build sequence:

1. Mirror-derived library URI + authored type-strings with `describe()` drift guard.
2. `Rule` / `FailureMode` / `Case` / `Boundary` / law; `softCheck` / `softCheckAsync`.
3. `requires`/`ensures(old())`/`effects` clauses on `..signature`; auto-derived negative cases for
   `requires`; `MISSING_GUARD` steer; `POSTCONDITION` steer with old-binding.
4. Async/temporal family: `fakeAsync` virtual-clock harness; `StreamQueue`-backed stream-`then`
   (replaces `StreamChecks`); `CancelableOperation` for cancel/atomicity; `FutureGroup`/`StreamGroup`
   for concurrency; `lifecycle`/`timing`/`concurrency`/`compensate` clauses on `..signature`.
5. `failureClass` field + DO-NOT guardrail block in the steering render; `TEMPORAL`/`CONCURRENCY`
   reproducers attach the fakeAsync schedule/interleaving.
6. `parameterized_test` table runner for `Boundary` pairs, region samples, and negative-case
   tables; add `parameterized_test: ^2.0.3` to `dev_dependencies` with SDK `>=3.8.0` constraint.
7. `runSequence` async driver; seam-throw first-class; harness re-implements the glados
   explore+shrink loop (not `.test()`); sidecar with `gladosSeed` + `orderingSeed`;
   `cmo_failures` binding; derived tags + stable IDs.

---

## 10. Unverified — mechanical lints that may improve contract correctness

> **Status: UNVERIFIED / speculative.** Nothing here is built or validated. These are candidate
> *mechanical* checks (an analyzer rule, a structural scan, or a contract-load-time assertion) that
> *might* catch authoring mistakes — listed for later evaluation, NOT part of the proven design.
> Several restate a verified *finding* as an as-yet-unproven *lint*. Promote an entry out of this
> section only after prototyping it and confirming it catches the real mistake without false positives.

**Declaration & shape**
- **Bool-shaped Rule** — a `Rule.condition` bottoming out in `isTrue()` / a bare bool renders
  `which = null` (unsteerable); require equals/relational conditions.
- **Non-atomic Rule** — a `Rule.text` containing a conjunction ("and", comma-joined clauses) should
  be split into separate Rules.
- **Mirror-structure assumption** — a `type<T>` / `signature` over an extension-type or typedef that
  relies on mirror-derived structure instead of an authored type-string.
- **`old()` misplacement** — `old(...)` used anywhere except inside an `ensures` clause.
- **FailureMode field existence** — a `FailureMode.where` accessing a field the error variant does
  not declare (e.g. `.code` on `LedgerError`); resolve against the real sealed hierarchy.

**Tags & identity**
- **Colon in a `--tags` tag** — any derived/authored tag containing `:` or `.` (illegal in
  `dart test --tags`); stable sidecar IDs are exempt (never passed to `--tags`).
- **Stream/sequence not serial** — a stream-shaped or `sequence(...)` case missing
  `kind-stream` / `kind-sequence` (it would run in parallel and corrupt order).

**Execution & async**
- **Sync `softCheck` over an async act** — wiring a synchronous `softCheck` over a `Future`/`Stream`
  (silent false-PASS); require `softCheckAsync`.
- **StreamQueue emit-before-pull** — emitting to a broadcast controller before a `.next`/`.take`
  request is pending (events dropped; `eventsDispatched` stays 0).
- **Real time/IO inside `fakeAsync`** — `DateTime.now()` / `Stopwatch` / real I/O in a `fakeAsync`
  body (escapes the virtual clock; use `clock.now()`).
- **`assume()` in a law** — skews the generator distribution; prefer a restricted generator.
- **`Result.release` as instance** — it is static (`Result.release(captured)`), not an instance method.

**Steering quality**
- **Negative phrasing** — "do not" / "must not" / "does not" in `Rule.text` or `FailureMode.steer`
  (the renderer concatenates verbatim — no negation inversion); require a positive imperative.
- **Untyped map hop** — a `Condition` doing a dynamic `m['k']` access without a typed `field<R>()`
  + `containsKey` guard (vacuous false-pass on a missing key).

**Coverage**
- **Unbound / unknown-rule join** — a declared `Rule`/`FailureMode` with no binding, or a binding
  citing an unknown unit (the §1 enforced join, surfaced as a standing lint).
- **Unexercised failure mode** — a declared `FailureMode` with no `requires` predicate or negative
  `Case` that triggers it (declared but never proven reachable).
- **Declared-but-unasserted `effects`** — a signature declaring `effects` that no case asserts
  (commit / rollback / at-most-once).
- **Inventory import resolves** — any inventory import absent from the target `pubspec.yaml` graph.

**Hygiene**
- **Stale provenance stamp** — a "Never modified" / `Authored:` stamp on a file whose git history
  shows later modification.

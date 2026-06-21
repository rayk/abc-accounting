# `ref-examplar` — Specification

A **reference exemplar** for idiomatic, functional Dart built on
[`fpdart`](https://pub.dev/packages/fpdart). The *code* is the deliverable; the
*domain* is only a vehicle. The exemplar exists to demonstrate, in one cohesive,
compiling, tested program:

1. A **complete public-interface surface** — every Dart language feature that can
   define a public API, used at least once, idiomatically.
2. A **complete behavioral surface** — sync & async, stream & sink, stateless &
   stateful, immutable data, and both idempotent & non-idempotent operations.
3. A **functional implementation** — robust, total, composition-first, leaning on
   fpdart and on a few elegant techniques under-used in mainstream Dart.

> **Status:** DRAFT for review. Section 14 lists open decisions.

> **Repository structure (current):** the code is **one released package**,
> `abc_accounting`, containing the token-guarded `Ledger` interface (in
> `lib/src/contract/`) **and** its implementation — so it is consumable directly
> from a git tag (`git: { url, ref }`, no `path:`/overrides). A **dev-only**
> sibling, `contracts_for_abc_accounting`, holds the conformance suite + reference
> implementation + SUT switch and **path-depends on `abc`**. See `README.md` and
> `LIFECYCLE.md` for the current layout. (This collapsed an earlier
> three-package federated workspace — `itfn`/`contracts`/`abc`; §18 still describes
> that rationale, and "the contract" now lives inside `abc`.) Sections that say
> "package `ref_examplar`" describe `abc_accounting`.

---

## 1. Purpose & non-goals

**Purpose.** Be the canonical thing a developer (or a code generator) reads to
answer *"what does well-written functional Dart with fpdart look like?"* Every
construct is present on purpose and is annotated with *why*, not just *what*.

**Non-goals.**

- Not a tutorial that builds up concepts gradually — it is a finished reference.
- Not domain-accurate finance software. The ledger is a teaching vehicle.
- Not a Flutter app. Pure Dart, so the functional + Riverpod patterns stand on
  their own without UI noise. (A Flutter binding could be a later sibling.)
- Not exhaustive of fpdart — it features the load-bearing types, not every helper.

---

## 2. Audience & usage

- **Primary:** an LLM / code generator that should imitate this style, and the
  engineers who review such output.
- **Secondary:** a developer adopting fpdart who wants one correct, copy-able
  pattern per concern.

Read top-to-bottom, `lib/ref_examplar.dart` (the barrel) is the table of
contents; each public symbol links (in doc comments) to the concept it exemplifies.

---

## 3. Guiding principles

| # | Principle | Concretely |
|---|-----------|------------|
| P1 | **Totality over exceptions.** Public functions never throw for expected outcomes. | Errors are values: `Either` / `TaskEither` of a `sealed LedgerError`. |
| P2 | **Parse, don't validate.** Illegal states are unrepresentable. | `extension type` newtypes, smart constructors returning `Either`. |
| P3 | **Composition over orchestration.** Behavior is built by combining small arrows. | Kleisli composition, `Do` notation, `Monoid`/`Semigroup` folds. |
| P4 | **Effects at the edges.** The core is pure; effects are described, then run. | `ReaderTaskEither` describes; the runtime interprets at `main`. |
| P5 | **Dependencies are data.** No service locators or hidden globals. | `Reader` environment + Riverpod `Provider` overrides as the only seams. |
| P6 | **Immutability by default.** State changes produce new values. | `final` fields, `const` ctors, `copyWith`, persistent updates. |
| P7 | **Document the law, not just the type.** | Idempotency, associativity, identity are stated and property-tested. |
| P8 | **Designed test-first.** Testability is a constraint on the *interface*, not a later concern. | Every effect is an injectable, hand-fakeable seam; every output is observable; every unit is constructible in isolation; the build order is red→green→refactor. |

---

## 4. Technology & versions

| Dependency | Pin | Role |
|------------|-----|------|
| Dart SDK | `>=3.5.0 <4.0.0` | extension types, records, patterns, sealed types |
| `fpdart` | `^1.2.0` | functional core (v2 is pre-release — **not** used) |
| `riverpod` | `^2.6.0` | pure-Dart DI/override seam (not `flutter_riverpod`) |
| `fast_immutable_collections` | `^11.0.0` | persistent `IList` for the event log |
| `test` | `^1.25.0` | unit tests |
| `glados` | `^1.1.7` | property-based tests for the algebraic laws |
| `dart_arch_test` | `^0.3.1` | encode the layering rules as executable tests |
| `mutation_test` | `^1.8.0` | mutation-test the pure logic to measure test strength |
| `coverage` | `^1.15.0` | produce `lcov.info` to focus the mutation run |

No `build_runner`/codegen in the canonical version — providers are written by
hand so the override mechanism is fully visible. (A `riverpod_generator` variant
may be noted in comments but is out of scope.)

---

## 5. Domain vehicle — a reactive, event-sourced account ledger

> ⚠️ **Swappable.** Any domain with the same *shape* works (a thermostat, a chat
> room, a KV cache with a change feed). The ledger is chosen because money makes
> idempotency vivid. If you prefer another vehicle, say so — only Section 5 changes.

The system models a single **account** as a fold over an immutable **event** log:

- **Commands** are requests (may be rejected): `Deposit`, `Withdraw`,
  `SetDailyLimit`, `Freeze`, `Close`.
- **Events** are facts (already happened): `Deposited`, `Withdrawn`,
  `LimitSet`, `Frozen`, `Closed`.
- A pure **reducer** `(AccountState, LedgerEvent) -> AccountState` rebuilds state.
- A pure **decider** `(AccountState, LedgerCommand) -> Either<LedgerError, List<LedgerEvent>>`
  validates a command against current state.
- A **runtime** holds live state, persists events, and broadcasts a read-model
  **stream**, accepting commands through a **sink**.

This split (decide → evolve) is the functional core/imperative shell pattern.

---

## 6. Public-interface inventory

Every Dart construct that can form a public API appears at least once. The
exemplar is incomplete until each row is satisfied.

| Dart feature | Symbol in the exemplar | Why this feature here |
|--------------|------------------------|------------------------|
| `extension type` (zero-cost newtype) | `AccountId`, `Money`, `Version` | Make primitives type-safe at no runtime cost; rarely used in Dart. |
| `sealed class` (closed ADT) | `LedgerCommand`, `LedgerEvent`, `LedgerError`, `AccountStatus`* | Exhaustive `switch`; the backbone of total functions. |
| `final class` (concrete, non-extensible) | `AccountState`, `Deposited`, … | Immutable value types; closed to inheritance. |
| `abstract interface class` (pure contract) | `LedgerRepository`, `Clock`, `IdGenerator` | Implement-only boundary; the async/effect edges — and every source of nondeterminism, made injectable for tests. |
| `abstract class` (extensible base) | `EventStore<S, E>` | Shared template behavior with hooks subclasses extend. |
| `mixin` / `mixin class` | `Auditable`, `JsonCodec<T>` | Compose orthogonal capabilities onto types. |
| `typedef` (alias) | `Reducer<S, E>`, `Decider<S, C, E>`, `LedgerEffect<A>` | Name function types & the effect alias to keep signatures legible. |
| top-level **function** | `applyEvent`, `decide`, `balanceOf`, `replay` | The pure, stateless core. |
| **generics** (incl. bounds) | `EventStore<S, E>`, `Reducer<S, E>`, `Id<T extends Object>` | Reusable, type-safe machinery. |
| `enum` (enhanced, with members) | `AccountStatus { open, frozen, closed }` | Small fixed sets with behavior/data. |
| `extension` (methods on existing types) | `MoneyArithmetic`, `EitherChecks`, `StreamReadModel` | Fluent combinators without wrapper types. |
| **records** (structural tuples) | decider returns, `(state, events)` | Lightweight multi-returns; replaces `Tuple2`. |
| **callable object** (`call`) | `LedgerReducer` implements `Reducer` via `call` | A function *and* a value; first-class behavior. |
| const constructors / `const` API | `Money.zero`, `AccountState.empty` | Compile-time canonical values. |
| **Riverpod provider** (overridable) | `clockProvider`, `idGeneratorProvider`, `ledgerRepositoryProvider`, `accountControllerProvider` | The user-override seam (Section 11) — and the test-double injection point. |

\* `AccountStatus` may be modeled as an `enum` *or* a `sealed class`; chosen as
`enum` so both an enhanced-enum and sealed-ADT example exist.

---

## 7. Behavioral matrix

| Behavior | Where it lives | Notes |
|----------|----------------|-------|
| **sync** | `applyEvent`, `decide`, `balanceOf`, `replay` | Total, pure, exception-free. |
| **async** | `LedgerRepository.load/append`, `AccountController` runtime | Modeled as `TaskEither` / `ReaderTaskEither`, never raw `Future` at the boundary. |
| **stream** | `AccountController.states : Stream<AccountState>` | Broadcast read-model feed; derived, replay-safe. |
| **sink** | `AccountController.commands : Sink<LedgerCommand>` | Ingest point; backpressure & ordering documented. |
| **stateless** | the pure core (§ functions above), `LedgerRepository` impls | No instance held between calls. |
| **stateful** | `AccountController` over an `IORef<AccountState>` | Live state in a functional mutable cell (fpdart `IORef`). |
| **immutable** | all domain types | `final`/`const`, `copyWith`, no setters. |
| **idempotent** | `setDailyLimit`, `freeze`, `close`, all reads, `load`; **plus** any command carrying a stable `idempotencyKey` (deduped) | Applying twice ⇒ same resulting state. Property-tested. |
| **non-idempotent** | `deposit`, `withdraw` (without a key) | Each call advances `Version` and appends an event. |

The **idempotency-key** mechanism (any command may carry a `CommandId`;
re-applying a seen id is a no-op returning the prior result) is a deliberate
"elegant, rarely-seen" feature that makes idempotency *first-class* rather than
incidental.

---

## 8. fpdart usage map

| fpdart construct | Used for | Site |
|------------------|----------|------|
| `Option<A>` | absence without `null` | `findAccount`, last-event lookups |
| `Either<LedgerError, A>` | sync validation / decisions | `decide`, smart constructors |
| `TaskEither<LedgerError, A>` | async, fallible IO | `LedgerRepository` |
| `ReaderTaskEither<LedgerEnv, LedgerError, A>` | async effect + injected deps | `LedgerEffect<A>` alias; use-cases |
| `IORef<AccountState>` | functional in-memory state | `AccountController` |
| `State<AccountState, A>` | the pure transition as a state computation | `runCommand` (contrast with `IORef` runtime) |
| `Unit` | "no meaningful value" | command acks |
| `Predicate<A>` | composable boolean tests | limit/balance guards (`.and`, `.not`) |
| **Do notation** | readable sequential composition | use-cases, repository flows |
| `Monoid` / `Semigroup` | combine money & accumulate errors | `Money` sum, validation accumulation |
| `Eq` / `Order` | law-abiding equality & ordering | `Money`, `Version` |
| Kleisli / `compose` / `flatMap` | arrow composition | wiring decide→persist→broadcast |

**Error accumulation:** fpdart 1.x has no built-in `Validation`. The exemplar
implements accumulation explicitly: validators return
`Either<NonEmptyChain<LedgerError>, A>` where `NonEmptyChain` combines via a
`Semigroup`, demonstrating applicative-style error gathering for multi-field
input (e.g. opening parameters) versus fail-fast `Either` for command decisions.

---

## 9. Module structure

```
contract/                      # package ref_examplar_contract — the handover artifact
  pubspec.yaml
  dart_test.yaml               # the `pending` tag (skips the red conformance demo)
  lib/
    ref_examplar_contract.dart # barrel: Ledger, LedgerFactory, value/event/error types
    conformance.dart           # ledgerAcceptance(factory) + UnimplementedLedger
    src/
      ledger.dart              # abstract interface Ledger; LedgerResult/LedgerFactory
      ids.dart                 # extension types: AccountId, Money, Version, CommandId
      events.dart              # sealed LedgerEvent + final subclasses
      errors.dart              # sealed LedgerError, IList-backed NonEmptyChain
      state.dart               # final AccountState
      status.dart              # enum AccountStatus
      value.dart               # Value equality mixin
  test/
    ids_test.dart              # every Money/Version operator and boundary
    conformance_pending_test.dart  # suite vs UnimplementedLedger (pending ⇒ red)
pubspec.yaml                   # package ref_examplar — the implementation (depends on contract)
lib/
  ref_examplar.dart            # TIGHT public API: re-exports contract + facade + seam
  ref_examplar_internals.dart  # advanced surface (pure core), for white-box tests
  src/
    domain/
      commands.dart            # sealed LedgerCommand + final subclasses (internal)
    core/
      typedefs.dart            # typedefs Reducer/Decider
      evolve.dart              # applyEvent / replay / LedgerReducer (callable)
      decide.dart              # decide(): Either<LedgerError, IList<Event>>
      event_store.dart         # abstract class EventStore<S,E> (extensible base)
      validation.dart          # applicative accumulating validator (NonEmptyChain)
      algebra.dart             # Eq/Order/Monoid/Semigroup instances
    effects/
      env.dart                 # LedgerEnv record; LedgerEffect<A> alias
      repository.dart          # abstract interface LedgerRepository; in-memory impl
      clock.dart               # abstract interface Clock; SystemClock
      id_generator.dart        # abstract interface IdGenerator; MonotonicIdGenerator
      use_cases.dart           # ReaderTaskEither pipelines (handle, deposit, …)
    runtime/
      controller.dart          # AccountController: IORef state, Stream out, Sink in
    api/
      ledger.dart              # abstract interface Ledger; LedgerResult typedef
      account_ledger.dart      # AccountLedger implements Ledger (the SUT)
    di/
      providers.dart           # Riverpod providers (overridable); ledgerProvider
example/
  ref_examplar_example.dart    # runnable main(): wires container, drives the sink
  extensions/
    v1_substitution.dart       # SnapshottingLedgerRepository (same sig, new process)
    v2_composition.dart        # transfer() + withAudit()/retrying() (new sig via composition)
    v3_new_behavior.dart       # LedgerProjection + StatementProjection (new contract)
test/
  support/
    fakes.dart                 # FixedClock, SeqIdGenerator, InMemoryLedgerRepository (hand-written, no mock lib)
    generators.dart            # glados generators for commands/events/Money
  contract/
    ledger_repository_contract.dart  # shared suite EVERY LedgerRepository impl must pass
  acceptance/
    account_ledger_acceptance_test.dart  # binds the contract conformance suite to the SUT (green)
  domain/
    money_laws_test.dart       # Monoid identity+associativity, Eq/Order laws (property-based)
    validation_test.dart       # applicative error accumulation
  core/
    decide_test.dart           # every LedgerError branch; decisions pure & exhaustive
    evolve_test.dart           # applyEvent determinism; replay == left fold
    idempotency_test.dart      # keyed ⇒ idempotent; unkeyed deposit ⇒ version advances
  effects/
    use_cases_test.dart        # ReaderTaskEither run against a fake LedgerEnv record
  runtime/
    controller_test.dart       # sink→stream causality, broadcast, dispose cleanup
  extensibility/
    extensibility_test.dart    # exercises all 3 extension vectors against the unchanged core
  architecture/
    architecture_test.dart     # dart_arch_test layering rules (§17)
```

---

## 10. Public API sketch (illustrative signatures)

```dart
// ── ids.dart ────────────────────────────────────────────────────────────────
extension type const AccountId(String value) {}
extension type const Version(int value) {
  Version get next => Version(value + 1);
}
/// Money as integer minor units; a Monoid under addition.
extension type const Money(int cents) implements Object {
  static const Money zero = Money(0);
  Money operator +(Money other) => Money(cents + other.cents);
  bool get isNegative => cents < 0;
}

// ── events.dart / commands.dart ──────────────────────────────────────────────
sealed class LedgerEvent { const LedgerEvent(); }
final class Deposited extends LedgerEvent { final Money amount; ... }
// … Withdrawn, LimitSet, Frozen, Closed

sealed class LedgerCommand {
  const LedgerCommand({this.idempotencyKey});
  final CommandId? idempotencyKey; // present ⇒ command is idempotent
}
final class Deposit extends LedgerCommand { final Money amount; ... }

// ── errors.dart ──────────────────────────────────────────────────────────────
sealed class LedgerError { const LedgerError(); }
final class InsufficientFunds extends LedgerError { ... }
// NonEmptyChain<E>: a Semigroup for applicative error accumulation.

// ── reducer.dart ─────────────────────────────────────────────────────────────
typedef Reducer<S, E> = S Function(S state, E event);
typedef Decider<S, C, E> = Either<LedgerError, List<E>> Function(S state, C cmd);

S applyEvent(AccountState s, LedgerEvent e); // total, sync
final class LedgerReducer { AccountState call(AccountState s, LedgerEvent e) => ...; }

// ── event_store.dart ─────────────────────────────────────────────────────────
abstract class EventStore<S, E> {            // extensible base
  S get initial;
  S apply(S s, E e);                          // subclass hook
  S replay(Iterable<E> events) => events.fold(initial, apply);
}

// ── repository.dart / clock.dart ─────────────────────────────────────────────
abstract interface class Clock { DateTime now(); }
abstract interface class LedgerRepository {  // implement-only boundary
  TaskEither<LedgerError, IList<LedgerEvent>> load(AccountId id);
  TaskEither<LedgerError, Unit> append(AccountId id, List<LedgerEvent> events);
}

// ── env.dart / use_cases.dart ────────────────────────────────────────────────
typedef LedgerEnv = ({LedgerRepository repo, Clock clock, IdGenerator ids});
typedef LedgerEffect<A> = ReaderTaskEither<LedgerEnv, LedgerError, A>;

LedgerEffect<AccountState> handle(AccountId id, LedgerCommand cmd); // decide→persist→evolve

// ── controller.dart ──────────────────────────────────────────────────────────
final class AccountController {
  Stream<AccountState> get states;     // read-model feed (broadcast)
  Sink<LedgerCommand> get commands;    // ingest
  AccountState get current;            // snapshot from IORef
  Future<void> dispose();
}

// ── providers.dart ───────────────────────────────────────────────────────────
final clockProvider = Provider<Clock>((_) => const SystemClock());
final ledgerRepositoryProvider =
    Provider<LedgerRepository>((_) => InMemoryLedgerRepository());
final accountControllerProvider =
    Provider.family<AccountController, AccountId>((ref, id) => ...);
```

---

## 11. The Riverpod override seam

Defaults are production-ish; users override by *providing their own
implementation of the public interfaces* — no edits to the exemplar required:

```dart
final container = ProviderContainer(overrides: [
  // swap the async boundary for a real DB, or a deterministic test double
  ledgerRepositoryProvider.overrideWithValue(PostgresLedgerRepository(pool)),
  // pin time for reproducibility
  clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026))),
]);
```

This demonstrates: a `Provider` (stateless dep), `Provider.family` (parameterized
by `AccountId`), and `overrideWithValue` / `overrideWith` as the user extension
point. The interfaces in §10 are exactly what a user implements.

---

## 12. Conventions the exemplar must model

- **No `throw` across public boundaries.** Convert at the edge; carry
  `LedgerError`. (`Object`-typed catches only inside repository impls, mapped to
  `LedgerError`.)
- **No `null` in public APIs.** Use `Option`; `null` allowed only for the
  optional `idempotencyKey` field, which is itself documented.
- **Exhaustive `switch`** over every `sealed`/`enum`; no `default` clause, so new
  variants break compilation (a feature).
- **Smart constructors** return `Either`/`Option`; raw constructors stay private
  where invariants exist.
- **Effects described, run once.** `ReaderTaskEither` values are pure until
  `.run(env)` at `main`/tests.
- **Doc comments state the law** (idempotent? total? associative?) and link the
  concept.
- **Naming:** `decide`/`apply`/`replay`/`handle` for the canonical FP roles;
  `…Effect` for `ReaderTaskEither` aliases.

---

## 13. Testability & TDD design

Testability is a property of the **interface**, asserted before any
implementation exists. The public surface in §10 is constrained by five rules,
and the internals are built in a fixed red→green→refactor order.

### 13.1 The five testability invariants (must hold for every public symbol)

| Invariant | Rule | How the design satisfies it |
|-----------|------|------------------------------|
| **I1 — Seams** | Every effect and every source of nondeterminism sits behind a narrow `abstract interface class`. | `LedgerRepository`, `Clock`, `IdGenerator`. No `DateTime.now()`, `Random`, or IO is called directly in the core. |
| **I2 — Purity** | The decision/evolution core is pure & total, so it needs no setup, doubles, or teardown. | `decide`, `applyEvent`, `replay`, `balanceOf` are top-level pure functions of their inputs. |
| **I3 — Effects as values** | Async logic is a *value* (`ReaderTaskEither`) run against an explicit env, never an ambient `Future`. | `LedgerEffect<A>` is `.run(testEnv)` with a fake `LedgerEnv` record — no Riverpod needed to test logic. |
| **I4 — Observability** | Every unit exposes its outcome for assertion without reaching past the interface. | Controller exposes `current` (snapshot) + `states` (stream); use-cases return `Either`; the sink is the only input. |
| **I5 — Isolation** | Every unit is constructible alone; no global/singleton state couples tests. | Each test builds its own `LedgerEnv` record or `ProviderContainer`; `IORef` state is per-controller. |

### 13.2 Test doubles: hand-written fakes, state-based assertions

Because every seam is a *narrow* interface, the exemplar uses **hand-written
fakes** (`FixedClock`, `SeqIdGenerator`, `InMemoryLedgerRepository`) and asserts
on resulting **state**, not on interactions. No `mockito`/`mocktail` — a
deliberate choice to keep tests refactor-proof and the seams honestly small.
(Interaction-style mocking is called out as an *anti-pattern* for this codebase.)

### 13.3 Contract tests for interfaces

`LedgerRepository` ships a reusable **contract test** —
`ledgerRepositoryContract(LedgerRepository Function() make)` — a suite that any
implementation must pass. The in-memory fake runs it in CI; a real
`PostgresLedgerRepository` would run the *same* suite. This makes the interface's
behavior, not just its shape, the spec — and lets users TDD their own override
against a ready-made oracle.

### 13.4 TDD build order (how the internals are implemented)

The implementation is written outside-in along the dependency arrows, each step
starting from a failing test:

1. **Laws & values** — `Money`/`Version` algebra; write `money_laws_test` first.
2. **Decider** — `decide` against `decide_test` (one red test per `LedgerError`).
3. **Evolver** — `applyEvent`/`replay` against `replay_test`.
4. **Idempotency** — keyed vs unkeyed semantics against `idempotency_test`.
5. **Repository contract** — write `ledgerRepositoryContract`, then make the
   in-memory fake green.
6. **Use-cases** — `handle` (`ReaderTaskEither`) against `use_cases_test` using
   the fake env.
7. **Runtime shell** — `AccountController` against `controller_test` (sink→stream).
8. **Wiring** — providers + `ProviderContainer` overrides; smoke `example`.

Each layer is fully green before the next begins; the pure layers (1–4) carry
the most logic and the most tests, the shell (7) stays thin.

### 13.5 Determinism

Tests are deterministic by construction: time via `FixedClock`, ids via
`SeqIdGenerator`, async via running the `Task` to completion (no real timers).
The same command sequence always yields the same events, state, and stream output.

---

## 14. Testing strategy (what each test proves)

| Test | Proves |
|------|--------|
| `domain/money_laws_test.dart` | `Money` Monoid identity + associativity; `Eq`/`Order` laws (property-based via `glados`). |
| `core/decide_test.dart` | every `LedgerError` branch reachable; decisions pure & exhaustive (no `default`). |
| `core/replay_test.dart` | `applyEvent` determinism; `replay == events.fold(initial, apply)`. |
| `core/idempotency_test.dart` | **idempotent:** `handle(k) ∘ handle(k) == handle(k)` for keyed commands; **non-idempotent:** `Version` strictly advances for unkeyed deposits. |
| `contract/ledger_repository_contract.dart` | append-then-load round-trips; ordering preserved; load of unknown id is empty — for *any* impl. |
| `effects/use_cases_test.dart` | `handle` run against a fake `LedgerEnv` yields the right `Either` and persisted events. |
| `runtime/controller_test.dart` | sink→stream causality, broadcast semantics, snapshot consistency, `dispose` cleanup, override-injected fakes. |

Property-based tests generate command sequences and assert the algebraic laws
hold across them; example-based tests pin the named scenarios and each error branch.

---

## 15. Decisions (resolved)

1. **Domain vehicle** — *keep* the event-sourced ledger.
2. **Persistent collections** — use **`fast_immutable_collections`** (`IList`).
3. **Error accumulation** — *include* the applicative `NonEmptyChain` validator
   (multi-field `OpenAccount`) alongside fail-fast `Either` for command decisions.
4. **Property tests** — *include* `glados` for the algebraic laws.
5. **Mocking** — *hand-written fakes* + state-based assertions (no `mocktail`).
6. **Deliverable** — spec **+ full working, tested implementation**, built
   test-first in the §13.4 order.

---

## 16. Extensibility model — the three vectors

The exemplar's API is designed to be extended **without modifying the core**,
along three deliberately distinct vectors. The boundary that makes this safe:

> **Closed data, open behavior.** The domain ADTs (`LedgerCommand`,
> `LedgerEvent`, `LedgerError`) are `sealed` — closed, for exhaustiveness and
> totality. The *behavior* layer (repositories, effects, use-cases, projections)
> is open. All three vectors operate on behavior; none touch the sealed core.

| Vector | Intent | Mechanism (Dart + fpdart) | Worked example |
|--------|--------|---------------------------|----------------|
| **V1 — Substitute** | Same signature, different *process/order* of the implementation. | Implement an `abstract interface class`, or override the hooks of the `EventStore` template; swap via a Riverpod `overrideWith`. The contract is unchanged. | `SnapshottingLedgerRepository` — same `LedgerRepository` signature, folds from periodic snapshots instead of replaying the whole log. |
| **V2 — Compose** | A *new* signature, built by composing existing types & functions. | Higher-order functions over the `LedgerEffect<A>` alias; decorators delegating to an inner interface; Kleisli/`Do` composition; `extension` combinators. | `transfer(from, to, amount)` composed from two existing `handle` calls; `withAudit(effect)` / `retrying(repo)` wrappers. |
| **V3 — Add** | A *new* signature for *new* behavior, plugged into existing seams. | A brand-new `abstract interface class` + `typedef` + top-level function + Riverpod provider, consuming the existing events/state. Nothing existing is edited. | `LedgerProjection<R>` read-model interface + `StatementProjection` deriving a monthly statement from the event log. |

Each vector ships as user-side code under `example/extensions/` (it imports only
the public barrel) and is verified by `test/extensibility/` — proving the core is
genuinely closed to modification yet open to extension (Open/Closed, demonstrated
three ways).

---

## 17. Architecture rules as tests

The layering in §9 is not a convention to be eroded — it is enforced by
`dart_arch_test` in `test/architecture/architecture_test.dart`:

- **Downward-only dependencies** via `defineLayers({di → api → runtime →
  effects → core → domain}).enforceDirection(graph)`.
- **Domain purity**: `src/domain/**` and `src/core/**` must not depend on
  `src/effects/**`, `src/runtime/**`, or `src/di/**` (`shouldNotDependOn`).
- **No cycles** in the package (`shouldBeFreeOfCycles`).
- **Effects isolation**: only `src/effects/**` and `src/di/**` may reach the
  injectable boundaries; the pure core stays free of IO/DI imports.

The graph is built once with `Collector.buildGraph('lib')`; violations fail CI
with the offending edge named.

---

## 18. The federated workspace & outside-in conformance

The repository is a **pub workspace of three packages**, in the style of
Flutter's federated-plugin architecture ([`plugin_platform_interface`](https://pub.dev/packages/plugin_platform_interface)).
Dependencies point inward only.

| Package | Contains | Depends on |
|---------|----------|-----------|
| **`itfn_accounting`** | The **token-guarded `Ledger` base** (`extend` + `Ledger.token`; members default to `UnimplementedError`), the `LedgerFactory` seam, and the value/event/error types. | nothing else |
| **`contracts_for_abc_accounting`** | The conformance suite `ledgerAcceptance(name, factory)`, the `UnimplementedLedger` stub, the green in-memory **`ReferenceLedger`**, and the **`LedgerUnderTest`** switch. | `itfn` only |
| **`abc_accounting`** | The real implementation: `AccountLedger extends Ledger`, the functional core, the override seam, Riverpod wiring. `abc_accounting.dart` (tight) / `abc_accounting_internals.dart` (white-box). | `itfn`; dev `contracts` |

**Why a token-guarded base, not a bare interface?** A class must `extend Ledger`
and pass `Ledger.token`; one that merely `implements` it fails `Ledger.verify`
(checked by the conformance harness for every SUT). The pay-off is the
federated-plugin one: a method added to `Ledger` later gets a default
`UnimplementedError` body, so existing implementations keep compiling instead of
breaking. It also makes the stub intrinsic — `UnimplementedLedger` overrides
nothing.

### 18.1 The outside-in (double-loop) workflow & the phase gate

The conformance suite (`contracts`) is the **outer loop** — authored to completion
against `itfn` alone, with no implementation. It is a standalone deliverable: an
implementation is "done" exactly when the suite goes green. Unit tests (`abc`)
are the **inner loop**.

The structural enablers:

1. **Phase separation by package.** During *contracting* only `itfn` + `contracts` are
   in scope. `contracts` runs the suite **green** against its `ReferenceLedger` (proof
   the spec is executable) and **red** against `UnimplementedLedger`. No
   implementation exists.
2. **The `LedgerFactory` seam + the `LedgerUnderTest` switch** ("the switch in the
   contract package"): a settable factory in `contracts`, defaulting to the stub. An
   implementation registers itself at runtime — `LedgerUnderTest.factory = (id) =>
   AccountLedger.open(...)` — with no conditional imports and no `contracts → abc`
   dependency.
3. **A `pending` tag** (`contracts/dart_test.yaml`) so the red spec is
   committable without breaking CI.

```
itfn + contracts (contracting)                         abc (implementation)
  reference ─► green   stub ─► red(pending)   ──►   extend Ledger, register the
        the conformance suite, authored first        switch, run the SAME suite ─► green
```

- `contracts/test/reference_conformance_test.dart` — the suite **green**
  against `ReferenceLedger`, plus the switch and token-guard checks.
- `contracts/test/pending_conformance_test.dart` — the suite **red**
  against the stub, tagged `pending`:
  `cd contracts && dart test --run-skipped -t pending`.
- `contracts/test/abc_conformance_test.dart` — binds the switch to the real
  `AccountLedger` (built from the public API) and runs the *same* suite (green).

Because the suite is factory-parameterised, it doubles as a conformance kit for
any future `Ledger` — point the switch at it and it must pass.

---

## 19. Mutation testing

`mutation_test` (`mutation_test.xml`) measures whether the suite actually
*detects* defects, scoped to the pure logic (`core/**` plus the value-arithmetic
of `domain/ids.dart`/`state.dart`) — where a surviving mutant is a real test gap
rather than noise from data-only classes. The run is focused by coverage:

```bash
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json --report-on=lib
dart run mutation_test -c coverage/lcov.info -f md mutation_test.xml
```

The first run surfaced genuine gaps (the `Money`/`Version` operators had no
direct test; the `DailyLimitExceeded.attempted` value and a negative daily-limit
case were unasserted); those are now covered by `ids_test.dart` and stronger
`decide`/`validation` assertions.

---
```
Sources for fpdart facts: pub.dev/packages/fpdart (v1.2.0, Oct 2025),
fpdart API docs, SandroMaglione/fpdart on GitHub.
```

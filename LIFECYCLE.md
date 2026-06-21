# How the packages work together — the full lifecycle

One contract, expressed as an interface, is designed and proven *before* it is
implemented, then implemented against an executable conformance suite. The
interface and the implementation ship as **one released package**; the
conformance suite is a **dev-only** sibling.

> **Structure note.** This started as a three-package federated workspace
> (`itfn` interface / `contracts` conformance / `abc` implementation). It was then
> **collapsed** so that `abc_accounting` is the *only released package* (interface
> **and** implementation together), making it consumable directly from a git tag.
> `contracts_for_abc_accounting` remains as a dev-only kit that now depends on `abc`. The
> phase narrative below is unchanged; only the package boundaries moved (the
> interface lives in `abc/lib/src/contract/` instead of a separate package).

---

## 1. The two packages

| Package | Role | Contains | Depends on | Released? |
|---------|------|----------|------------|-----------|
| **`abc_accounting`** | **Contract + implementation** | The token-guarded `Ledger` base, `LedgerFactory`/`LedgerResult`, the value/event/error types (`Money`, `AccountState`, …) **and** `AccountLedger` + the functional core + Riverpod wiring. | nothing non-hosted (`fpdart`, `riverpod`, `fic`) | **yes** |
| **`contracts_for_abc_accounting`** | **Conformance kit** | `ledgerAcceptance(name, factory)`, `UnimplementedLedger`, `ReferenceLedger`, `LedgerUnderTest`. | `abc` (path) | no (dev-only) |

### The dependency rule

```
   abc_accounting   (the released package; depends on nothing non-hosted)
        ▲
        │ (path, dev-only)
   contracts_for_abc_accounting  (the conformance kit; never released)
```

- `contracts → abc`: the kit depends on the released package (the interface lives
  there now). It is still *written against* the `Ledger` interface and a
  `LedgerFactory` seam — it just no longer has the compile-time guarantee that
  the implementation is out of scope.
- **Nothing depends on `contracts`**, and `abc` has **no non-hosted dependency**, so a
  downstream consumes `abc` from a git tag with `git: { url, ref }` — no `path:`,
  no `dependency_overrides`. `contracts` never enters the consumer's graph.

---

## 2. Lifecycle at a glance

```
  ┌─ CONTRACTING (only itfn + contracts in scope) ───────────────────────────────┐
  │                                                                          │
  │  1. design the interface ............................. itfn_accounting   │
  │  2. write the conformance suite ...... contracts_for_abc_accounting  → RED vs stub     │
  │  3. write a reference implementation .. contracts_for_abc_accounting → GREEN vs ref    │
  │                                                                          │
  └──────────────────────────────┬───────────────────────────────────────────┘
                                 │  HAND OVER {itfn + contracts}
                                 ▼
  ┌─ IMPLEMENTATION (abc added) ─────────────────────────────────────────────┐
  │                                                                          │
  │  4. extend the interface ............. abc_accounting (AccountLedger)     │
  │  5. inner-loop TDD on the internals .. abc_accounting (unit tests)        │
  │  6. register & run the SAME suite .... abc_accounting → GREEN vs SUT      │
  │                                                                          │
  └──────────────────────────────┬───────────────────────────────────────────┘
                                 │
                                 ▼
  ┌─ EVOLUTION ──────────────────────────────────────────────────────────────┐
  │  add a method to Ledger (defaults keep old impls compiling), or add a     │
  │  scenario to the suite (turns red until every impl satisfies it).         │
  └──────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Phase 1 — Design the interface (`itfn_accounting`)

You write the **contract** as a token-guarded base class
(`itfn_accounting/lib/src/ledger.dart`):

```dart
abstract class Ledger {
  Ledger({required Object token}) { _tokens[this] = token; }   // records the token
  static final Object _token = Object();
  static Object get token => _token;
  static void verify(Ledger instance) {                        // checked per SUT
    if (!identical(_tokens[instance], _token)) throw AssertionError(/* … */);
  }

  // Every member has a DEFAULT body that throws — so the stub is intrinsic and
  // adding a member later does not break existing implementations.
  LedgerResult deposit(Money amount, {Option<CommandId> idempotencyKey = const None()})
      => throw UnimplementedError();
  // … withdraw / setDailyLimit / freeze / closeAccount / id / state / changes / dispose
}

typedef LedgerFactory = Future<Ledger> Function(AccountId id);   // the SUT seam
```

The package also defines the data the contract speaks in (`Money`,
`AccountState`, `LedgerEvent`, `LedgerError`, …). It depends on nothing else and
tests its own value types (`itfn_accounting/test/ids_test.dart`).

**Why a token-guarded base, not a bare `interface`?** Implementations must
`extend Ledger` and pass `Ledger.token`; a class that only `implements Ledger`
records no token and fails `Ledger.verify`. The pay-off is the federated-plugin
one: a method added to `Ledger` tomorrow gets the default `UnimplementedError`
body, so yesterday's implementations keep compiling.

After the collapse the interface lives at `lib/src/contract/` inside `abc`; its
value types are exercised by `test/contract/`:

```bash
dart analyze && dart test test/contract
```

---

## 4. Phase 2 — Author the conformance (`contracts_for_abc_accounting`) → red

The conformance suite (`contracts/lib/src/conformance.dart`) is the
**executable specification**, written against the interface and parameterised by
a `LedgerFactory` — it never names a concrete class:

```dart
void ledgerAcceptance(String name, LedgerFactory factory) {
  group('Ledger acceptance: $name', () {
    late Ledger ledger;
    setUp(() async {
      ledger = await factory(const AccountId('sut'));
      Ledger.verify(ledger);          // the SUT must `extend` the base
    });
    // scenarios: deposit/withdraw, overdraw rejected, daily limit, freeze/close,
    // keyed idempotency, a multi-transaction running balance with a change-stream …
  });
}
```

Bound to the stub it is **red** — every scenario throws `UnimplementedError`:

```dart
// contracts/test/pending_conformance_test.dart   (tagged `pending`)
void main() => ledgerAcceptance('pre-implementation', (_) async => UnimplementedLedger());
```

```bash
cd contracts && dart test --run-skipped -t pending   # every scenario red: UnimplementedError
```

The `pending` tag (`contracts/dart_test.yaml`) keeps this red spec
committable without breaking CI — the default run skips it.

---

## 5. Phase 3 — A reference implementation (`contracts_for_abc_accounting`) → green

Still inside `contracts`, a small in-memory `ReferenceLedger`
(`reference_ledger.dart`) makes the suite **green**. This proves the spec is
*executable and self-consistent* (not merely red against a stub) and becomes the
behavioral yardstick any real implementation must match:

```dart
// contracts/test/reference_conformance_test.dart
ledgerAcceptance('ReferenceLedger', ReferenceLedger.open);   // GREEN
```

The **switch** (`switch.dart`) ties contracting together — a settable factory,
defaulting to the stub, that the suite can run against:

```dart
abstract final class LedgerUnderTest {
  static LedgerFactory _factory = _stub;                      // default = red
  static LedgerFactory get factory => _factory;
  static set factory(LedgerFactory value) => _factory = value;
  static void useReference() => _factory = ReferenceLedger.open;   // → green
  static void runConformance(String name) => ledgerAcceptance(name, _factory);
}
```

```bash
cd contracts && dart analyze && dart test    # suite green vs ReferenceLedger; the stub spec stays pending
```

---

## 6. Phase 4 — Handover

At this point `{itfn_accounting, contracts_for_abc_accounting}` is a complete, self-contained
deliverable: the interface, the data types, an executable specification, a green
reference, and the switch — with **no implementation in scope**. It builds and
tests on its own. You hand it over; the implementer's job is to make
`ledgerAcceptance` green against *their* code.

---

## 7. Phase 5 — Implement (`abc_accounting`) → green

The implementer fills in `abc_accounting` — extending the `Ledger` base that now
lives in its own `lib/src/contract/`. `contracts_for_abc_accounting` (which **path-depends on
`abc`**) then runs the same suite against the real implementation.

1. **Extend the interface** (`api/account_ledger.dart`):

   ```dart
   final class AccountLedger extends Ledger {
     AccountLedger._(this._controller) : super(token: Ledger.token);   // passes the guard
     static Future<Ledger> open(LedgerEnv env, AccountId id) async => …;
     // overrides deposit/withdraw/… delegating to the functional core
   }
   ```

2. **Inner-loop TDD** drives the internals — the pure core (`decide`, `evolve`),
   the effects, the stream/sink controller — under fast unit/property tests
   (`abc_accounting/test/{domain,core,effects,runtime}/`). The outer loop (the
   conformance suite) stays red until these are done; the inner loop turns them
   green one at a time.

3. **Register the switch and run the same suite** against the real SUT
   (`contracts/test/abc_conformance_test.dart`):

   ```dart
   void main() {
     LedgerUnderTest.factory = (id) => AccountLedger.open(testEnv(), id);  // bind the switch
     LedgerUnderTest.runConformance('AccountLedger');                      // SAME suite → green
   }
   ```

   The implementation is injected **at runtime through the factory** — the suite
   in `contracts` only ever names the `Ledger` interface and the `LedgerFactory` seam.
   The architecture of `abc`'s own internals
   (`di → api → runtime → effects → core → domain`) is itself enforced by
   `dart_arch_test` (`abc_accounting/test/architecture/`).

```bash
dart analyze && dart test     # abc's unit/property/architecture suites, all green
```

---

## 8. Phase 6 — Evolution

- **Add a capability to the interface.** Add a method to `Ledger` with a default
  `UnimplementedError` body. Existing implementations keep compiling (they
  inherit the default); you then add a conformance scenario and implement the
  method where it's supported. The token guard is what makes the default safe.
- **Tighten the contract.** Add a scenario to `ledgerAcceptance`. It immediately
  turns **every** implementation's acceptance run red until each satisfies it —
  one suite, enforced everywhere.
- **A second implementation.** A remote service, a decorator, a different
  storage engine — point `LedgerUnderTest.factory` (or call `ledgerAcceptance`)
  at it and it must pass the identical suite. The suite is a reusable conformance
  kit, not a one-off test.

---

## 9. How a conformance run actually wires up (runtime)

```
ledgerAcceptance(name, factory)                       [contracts]
        │  setUp:
        ▼
   ledger = await factory(id)        ── stub | reference | AccountLedger
        │
        ▼
   Ledger.verify(ledger)             ── rejects anything not `extend`ing the base   [itfn]
        │
        ▼
   run each scenario against `ledger` ── pure assertions on Money/AccountState/...  [itfn types]
```

The seam is the `LedgerFactory`. The *same* suite, the *same* assertions, run
against the stub (red), the reference (green), or the production `AccountLedger`
(green) — selected purely by which factory is bound. That substitutability,
plus the inward-only dependency rule, is what lets the contract be designed and
proven before — and independently of — any implementation.

---

## 10. Commands by phase

```bash
# The released package: interface (lib/src/contract) + implementation
dart test                                            # unit/property/architecture + conformance shape
dart run example/ref_examplar_example.dart

# The dev-only conformance kit
cd contracts && dart test                      # suite GREEN vs ReferenceLedger AND vs AccountLedger (+ switch/guard)
cd contracts && dart test --run-skipped -t pending   # suite RED vs the stub

# Everything, in dependency order (the definition of done)
./tool/verify.sh
```

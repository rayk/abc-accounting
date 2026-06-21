/// `abc_accounting` — the **single released package**: the Ledger contract *and*
/// its functional implementation.
///
/// The **tight, usage-based public API**: the token-guarded [Ledger] base,
/// [LedgerFactory], and the value/event/error types (the contract), plus the
/// concrete implementation and the override seam:
///
/// - **`AccountLedger`** — the concrete system under test; **`ledgerProvider`** —
///   the wired entry point.
/// - **override seam** — `LedgerRepository`, `Clock`, `IdGenerator`, `LedgerEnv`,
///   and the Riverpod providers.
///
/// It deliberately does *not* re-export the pure core (the decider, evolver,
/// typeclass algebra, validators, the command ADT, …) — those internals live
/// behind `package:abc_accounting/abc_accounting_internals.dart`.
///
/// Because the interface lives here, this is the only package downstreams need;
/// the `contracts_for_abc_accounting` conformance kit is a dev-only sibling that depends on it.
library;

// The contract (interface + value/event/error types).
export 'src/contract/contract.dart';

// The concrete implementation.
export 'src/api/account_ledger.dart';

// The override seam + Riverpod wiring.
export 'src/di/providers.dart';
export 'src/effects/clock.dart';
export 'src/effects/env.dart' show LedgerEnv;
export 'src/effects/id_generator.dart';
export 'src/effects/repository.dart';

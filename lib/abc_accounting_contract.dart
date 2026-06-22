/// `abc_accounting` — the **contract-only view** of the released package.
///
/// Exports just the contract layer: the token-guarded [Ledger] base, the
/// [LedgerFactory]/[LedgerResult] seam, `contractVersion`, and the value /
/// event / error vocabulary (`Money`, `AccountState`, `LedgerError`, …) — and
/// **nothing** from the implementation layers (`AccountLedger`, the providers,
/// the effect seams).
///
/// This is the surface the conformance kit (`contracts_for_abc_accounting`) and
/// any other implementer authors against. Because it cannot see the
/// implementation, the executable contract can be written and proven
/// (reference-green, stub-red) with **no implementation in scope** — restoring
/// the contract-before-implementation lifecycle even though the contract and
/// the implementation ship in one released package.
///
/// The full barrel — `package:abc_accounting/abc_accounting.dart` — additionally
/// re-exports `AccountLedger`, the Riverpod wiring, and the effect seams; it is
/// what downstream *consumers* and the implementation-phase conformance binding
/// (`test/abc_conformance_test.dart`) import.
library;

export 'src/contract/contract.dart';

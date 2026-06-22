/// `contracts_for_abc_accounting` — the **dev-only conformance kit** for `abc_accounting`.
///
/// The reusable conformance suite ([ledgerAcceptance]), the pre-implementation
/// stub ([UnimplementedLedger]), a green [ReferenceLedger], and the
/// [LedgerUnderTest] switch.
///
/// Since the [Ledger] contract was collapsed into the released `abc_accounting`
/// package, this kit depends on `abc_accounting` directly. It re-exports only
/// the **contract-only** view (the `Ledger` surface + vocabulary), never the
/// implementation — so authoring against this barrel keeps the implementation
/// out of scope. It is never published — `abc_accounting` is the only released
/// artifact — so this `abc → contracts` is purely a development-time dependency.
library;

// Contract-only re-export (not the full barrel): the kit authors against the
// contract, so the implementation stays out of scope. The implementation-phase
// binding (test/abc_conformance_test.dart) imports the full barrel directly.
export 'package:abc_accounting/abc_accounting_contract.dart';

export 'src/conformance.dart';
// The per-boundary `package:checks` matchers (Either branch unwrap + the
// AccountState field accessors), reusable when authoring further Ledger tests.
export 'src/ledger_checks.dart';
export 'src/reference_ledger.dart';
export 'src/switch.dart';

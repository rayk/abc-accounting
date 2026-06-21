/// `contracts_for_abc_accounting` — the **dev-only conformance kit** for `abc_accounting`.
///
/// The reusable conformance suite ([ledgerAcceptance]), the pre-implementation
/// stub ([UnimplementedLedger]), a green [ReferenceLedger], and the
/// [LedgerUnderTest] switch.
///
/// Since the [Ledger] contract was collapsed into the released `abc_accounting`
/// package, this kit depends on `abc_accounting` directly (and re-exports it for
/// convenience). It is never published — `abc_accounting` is the only released
/// artifact — so this `abc → contracts` is purely a development-time dependency.
library;

export 'package:abc_accounting/abc_accounting.dart';

export 'src/conformance.dart';
export 'src/reference_ledger.dart';
export 'src/switch.dart';

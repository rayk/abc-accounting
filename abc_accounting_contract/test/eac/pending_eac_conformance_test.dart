/// Pending EAC conformance — same new-DSL suite bound to
/// [UnimplementedLedger].
///
/// Tagged `pending` so the default `dart test` SKIPS it (CI stays
/// green).  Run explicitly to observe the red:
///
/// ```bash
/// dart test test/eac/pending_eac_conformance_test.dart \
///   --run-skipped -t pending
/// ```
///
/// Every test fails with a `SeamThrew`-driven assertion because every
/// `Ledger` member throws `UnimplementedError`.
@TestOn('vm')
@Tags(['pending'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:abc_accounting_contract/src/eac/ledger_conformance.dart';
import 'package:test/test.dart';

void main() {
  eacLedgerConformance(
    'UnimplementedLedger (new DSL)',
    (_) async => UnimplementedLedger(),
  );
}

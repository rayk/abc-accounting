/// Order-dependent account-lifecycle scenario, bound to the reference.
///
/// Drives the `scenarios/001_account_lifecycle.dart` sequence serially via
/// `runSequence`: deposit → freeze → deposit-on-frozen (rejects
/// `AccountNotActive`). The steps share one live `Ledger`, so order matters.
@TestOn('vm')
library;

import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:abc_accounting_contract/src/scenarios/001_account_lifecycle.dart';
import 'package:test/test.dart';

void main() {
  accountLifecycleScenario(ReferenceLedger.open);
}

@TestOn('vm')
@Tags(['pending'])
library;

import 'package:abc_accounting_contract/abc_accounting_contract.dart';
import 'package:test/test.dart';

/// The conformance suite in its **pre-implementation, red** state: bound to the
/// [UnimplementedLedger], every scenario throws `UnimplementedError`. This is
/// what a contract looks like the moment it is written, before any behavior
/// exists.
///
/// Tagged `pending` so the default `dart test` skips it (CI stays green). Run it
/// explicitly to watch the red:
///
/// ```bash
/// dart test --run-skipped -t pending
/// ```
///
/// An implementation makes the *same* suite green by binding the switch to its
/// own factory (see `abc_accounting`'s conformance test).
void main() {
  ledgerAcceptance(
    'pre-implementation (UnimplementedLedger)',
    (_) async => UnimplementedLedger(),
  );
}

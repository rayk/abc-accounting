/// Reference EAC conformance — same new-DSL suite bound to the
/// in-package [ReferenceLedger].
///
/// GREEN: every assertion holds.  This is the proof that the
/// spec is self-consistent and executable before any production
/// implementation exists.
@TestOn('vm')
library;

import 'package:abc_accounting_contract/src/ledger_conformance.dart';
import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:test/test.dart';

void main() {
  eacLedgerConformance('ReferenceLedger (new DSL)', ReferenceLedger.open);
}

import 'package:abc_accounting/abc_accounting.dart';

import 'ledger_conformance.dart';
import 'reference_abc_accounting.dart';

/// The **switch in the contract package**: a settable factory that selects
/// which implementation the conformance suite runs against — the federated
/// instance-registration pattern, but for the system under test.
///
/// It defaults to [UnimplementedLedger] (the red, pre-implementation state).
/// During contracting you can point it at the in-package [ReferenceLedger]
/// (green). An implementation package sets it to its own factory before
/// running the suite — no conditional imports, and this package never depends
/// on any implementation.
abstract final class LedgerUnderTest {
  /// The currently selected system-under-test factory.
  /// Defaults to [UnimplementedLedger] (red). Assign to switch the SUT.
  static LedgerFactory factory = _stub;

  static Future<Ledger> _stub(AccountId id) async => UnimplementedLedger();

  /// Point the switch at the in-package reference implementation (green).
  static void useReference() => factory = ReferenceLedger.open;

  /// Point the switch back at the unimplemented stub (the default, red).
  static void useStub() => factory = _stub;

  /// Run the conformance suite against whatever the switch currently selects.
  static void runConformance(String name) =>
      eacLedgerConformance(name, factory);
}

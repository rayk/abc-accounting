// Unlike the contract-phase tests, this implementation-phase binding imports
// the FULL abc_accounting barrel — it names the concrete AccountLedger and its
// effect seams to build the real SUT. The conformance suite it runs still only
// names the Ledger interface + the LedgerFactory seam.
import 'package:abc_accounting/abc_accounting.dart';
import 'package:contracts_for_abc_accounting/contracts_for_abc_accounting.dart';
import 'package:test/test.dart';

/// The implementation phase: bind the [LedgerUnderTest] switch to abc's real
/// `AccountLedger` — assembled from abc's *public* API — and run the same
/// conformance suite that was authored against the reference. Green.
Future<Ledger> _openAbc(AccountId id) => AccountLedger.open(
      (
        repo: InMemoryLedgerRepository(),
        clock: const SystemClock(),
        ids: MonotonicIdGenerator(const SystemClock()),
      ),
      id,
    );

void main() {
  LedgerUnderTest.factory = _openAbc;
  LedgerUnderTest.runConformance('AccountLedger');

  test('AccountLedger passes the Ledger token verification', () async {
    final ledger = await _openAbc(const AccountId('v'));
    expect(() => Ledger.verify(ledger), returnsNormally);
    await ledger.dispose();
  });
}

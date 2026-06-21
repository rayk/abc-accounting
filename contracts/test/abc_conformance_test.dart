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

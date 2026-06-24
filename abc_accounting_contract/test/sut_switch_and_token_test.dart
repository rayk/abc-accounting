/// SUT-switch + token-guard invariants (preserved from the retired legacy
/// `reference_conformance_test.dart`).
///
/// These are interface-level guarantees independent of the conformance DSL:
/// the [LedgerUnderTest] switch defaults to the red stub and can be pointed at
/// the green reference, and [Ledger.verify] rejects an implementation that does
/// not pass the shared construction token.
@TestOn('vm')
library;

import 'package:abc_accounting_contract/abc_accounting_contract.dart';
import 'package:test/test.dart';

/// A wrong-token implementation: it `extends Ledger` but does not pass
/// `Ledger.token`, so [Ledger.verify] rejects it (the same way an
/// `implements Ledger` class — which never runs the constructor — is rejected).
final class _WrongTokenLedger extends Ledger {
  _WrongTokenLedger() : super(token: Object());
}

void main() {
  group('the SUT switch (the switch in the contract package)', () {
    tearDown(LedgerUnderTest.useStub);

    test('defaults to the unimplemented stub (red)', () async {
      final sut = await LedgerUnderTest.factory(const AccountId('x'));
      expect(() => sut.deposit(const Money(1)), throwsUnimplementedError);
    });

    test('can be switched to the reference implementation (green)', () async {
      LedgerUnderTest.useReference();
      final sut = await LedgerUnderTest.factory(const AccountId('x'));
      final result = await sut.deposit(const Money(10));
      expect(
        result.match((_) => false, (s) => s.balance == const Money(10)),
        isTrue,
      );
      await sut.dispose();
    });
  });

  group('the token guard', () {
    test('a Ledger that does not pass the shared token is rejected', () {
      expect(
        () => Ledger.verify(_WrongTokenLedger()),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the reference implementation passes verification', () async {
      final sut = await ReferenceLedger.open(const AccountId('x'));
      expect(() => Ledger.verify(sut), returnsNormally);
      await sut.dispose();
    });
  });
}

@Tags(['deposit'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract: deposit happy path and AmountMustBePositive rejection.
void depositContract(LedgerFactory factory) {
  group('deposit — happy path', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule('deposit adds money; the new balance reflects the amount.')
        ..filterTypes({AccountState});
      ledger = await factory(const AccountId('sut-deposit-happy'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('deposit increases the balance', () async {
      check(await ledger.deposit(const Money(500)))
          .success
          .balance
          .equals(const Money(500));
    });
  });

  group('deposit — AmountMustBePositive', () {
    late Ledger ledger;

    setUpAll(
      () => ledgerBrief
        ..setRule(
          'Zero or negative deposit amount is rejected with '
          'AmountMustBePositive. State is unchanged.',
        )
        ..filterTypes({AmountMustBePositive, AccountState, Money}),
    );

    setUp(() async {
      ledger = await factory(const AccountId('sut-deposit-positive'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('zero amount is rejected', () async {
      final before = ledger.state;
      check(await ledger.deposit(Money.zero))
          .failure
          .isA<AmountMustBePositive>();
      check(ledger.state).equals(before);
    });

    test('negative amount is rejected', () async {
      final before = ledger.state;
      check(await ledger.deposit(const Money(-1)))
          .failure
          .isA<AmountMustBePositive>();
      check(ledger.state).equals(before);
    });
  });
}

@Tags(['withdraw'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract: withdraw happy path, InsufficientFunds rejection, and
/// AmountMustBePositive rejection.
void withdrawContract(LedgerFactory factory) {
  group('withdraw — happy path', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule('withdraw removes money when funds suffice.')
        ..filterTypes({AccountState});
      ledger = await factory(const AccountId('sut-withdraw-happy'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('withdraw decreases the balance', () async {
      await ledger.deposit(const Money(500));
      check(await ledger.withdraw(const Money(120)))
          .success
          .balance
          .equals(const Money(380));
    });
  });

  group('withdraw — InsufficientFunds', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'A withdrawal exceeding the balance is rejected with '
          'InsufficientFunds and leaves state unchanged.',
        )
        ..filterTypes({AccountState, InsufficientFunds});
      ledger = await factory(const AccountId('sut-withdraw-insufficient'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('overdraw is rejected and leaves state unchanged', () async {
      await ledger.deposit(const Money(100));
      final before = ledger.state;
      check(await ledger.withdraw(const Money(1000)))
          .failure
          .isA<InsufficientFunds>();
      check(ledger.state).equals(before);
    });
  });

  group('withdraw — AmountMustBePositive', () {
    late Ledger ledger;

    setUpAll(
      () => ledgerBrief
        ..setRule(
          'Zero or negative withdraw amount is rejected with '
          'AmountMustBePositive. State is unchanged.',
        )
        ..filterTypes({AmountMustBePositive, AccountState, Money}),
    );

    setUp(() async {
      ledger = await factory(const AccountId('sut-withdraw-positive'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('zero amount is rejected', () async {
      final before = ledger.state;
      check(await ledger.withdraw(Money.zero))
          .failure
          .isA<AmountMustBePositive>();
      check(ledger.state).equals(before);
    });

    test('negative amount is rejected', () async {
      final before = ledger.state;
      check(await ledger.withdraw(const Money(-1)))
          .failure
          .isA<AmountMustBePositive>();
      check(ledger.state).equals(before);
    });
  });
}

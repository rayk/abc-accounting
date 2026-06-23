@Tags(['withdraw'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract for [Ledger.withdraw].
/// Authored: 2026-06-22. Never modified after initial authoring.
void withdrawContract(LedgerFactory factory) {
  late Ledger sut;
  setUp(() async => sut = await factory(const AccountId('withdraw')));
  tearDown(() => sut.dispose());

  group('withdraw — happy path', () {
    setUpAll(() => ledgerBrief
      ..setRule('A withdrawal within the balance decreases the balance.')
      ..filterTypes({AccountState, Money}));

    test('balance decreases by the withdrawn amount', () async {
      await sut.deposit(const Money(500));
      check(await sut.withdraw(const Money(120)))
          .success
          .balance
          .equals(const Money(380));
    }, tags: 'withdraw_happy_balance');
  }, tags: 'withdraw_happy');

  group('withdraw — InsufficientFunds', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'A withdrawal exceeding the balance is rejected with '
        'InsufficientFunds and leaves state unchanged.',
      )
      ..filterTypes({InsufficientFunds, AccountState, Money}));

    test('overdraw is rejected and leaves state unchanged', () async {
      await sut.deposit(const Money(100));
      final before = sut.state;
      check(await sut.withdraw(const Money(1000)))
          .failure
          .isA<InsufficientFunds>();
      check(sut.state).equals(before);
    }, tags: 'withdraw_insufficient_funds_overdraw');
  }, tags: 'withdraw_insufficient_funds');

  group('withdraw — AmountMustBePositive', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'Zero or negative withdrawal amount is rejected with '
        'AmountMustBePositive. State is unchanged.',
      )
      ..filterTypes({AmountMustBePositive, AccountState, Money}));

    test('zero amount returns AmountMustBePositive', () async {
      final before = sut.state;
      check(await sut.withdraw(Money.zero)).failure.isA<AmountMustBePositive>();
      check(sut.state).equals(before);
    }, tags: 'withdraw_amount_positive_zero');

    test('negative amount returns AmountMustBePositive', () async {
      final before = sut.state;
      check(await sut.withdraw(const Money(-1)))
          .failure
          .isA<AmountMustBePositive>();
      check(sut.state).equals(before);
    }, tags: 'withdraw_amount_positive_negative');
  }, tags: 'withdraw_amount_positive');
}

@Tags(['deposit'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract for [Ledger.deposit].
/// Authored: 2026-06-22. Never modified after initial authoring.
void depositContract(LedgerFactory factory) {
  late Ledger sut;
  setUp(() async => sut = await factory(const AccountId('deposit')));
  tearDown(() => sut.dispose());

  group('deposit — happy path', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'A positive deposit increases the balance by the deposited amount.',
      )
      ..filterTypes({AccountState, Money}));

    test('balance increases by the deposited amount', () async {
      check(await sut.deposit(const Money(500)))
          .success
          .balance
          .equals(const Money(500));
    }, tags: 'deposit_happy_balance');

    test('version advances after deposit', () async {
      check(await sut.deposit(const Money(100)))
          .success
          .version
          .equals(const Version(1));
    }, tags: 'deposit_happy_version');
  }, tags: 'deposit_happy');

  group('deposit — AmountMustBePositive', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'Zero or negative deposit amount is rejected with '
        'AmountMustBePositive. State is unchanged.',
      )
      ..filterTypes({AmountMustBePositive, AccountState, Money}));

    test('zero amount returns AmountMustBePositive', () async {
      final before = sut.state;
      check(await sut.deposit(Money.zero)).failure.isA<AmountMustBePositive>();
      check(sut.state).equals(before);
    }, tags: 'deposit_amount_positive_zero');

    test('negative amount returns AmountMustBePositive', () async {
      final before = sut.state;
      check(await sut.deposit(const Money(-1)))
          .failure
          .isA<AmountMustBePositive>();
      check(sut.state).equals(before);
    }, tags: 'deposit_amount_positive_negative');
  }, tags: 'deposit_amount_positive');
}

@Tags(['daily_limit'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract for [Ledger.setDailyLimit].
/// Authored: 2026-06-22. Never modified after initial authoring.
void setDailyLimitContract(LedgerFactory factory) {
  late Ledger sut;
  setUp(() async => sut = await factory(const AccountId('daily-limit')));
  tearDown(() => sut.dispose());

  group('setDailyLimit — happy path', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'setDailyLimit stores the limit; subsequent withdrawals within '
        'it succeed.',
      )
      ..filterTypes({AccountState, Money}),);

    test('withdrawal within the daily limit succeeds', () async {
      await sut.deposit(const Money(1000));
      await sut.setDailyLimit(const Money(500));
      check(await sut.withdraw(const Money(300)))
          .success
          .balance
          .equals(const Money(700));
    }, tags: 'daily_limit_happy_success',);
  }, tags: 'daily_limit_happy',);

  group('setDailyLimit — DailyLimitExceeded', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'A withdrawal beyond the daily limit is rejected with '
        'DailyLimitExceeded.',
      )
      ..filterTypes({DailyLimitExceeded, AccountState, Money}),);

    test('withdrawal exceeding the daily limit returns DailyLimitExceeded',
        () async {
      await sut.deposit(const Money(1000));
      await sut.setDailyLimit(const Money(300));
      check(await sut.withdraw(const Money(400)))
          .failure
          .isA<DailyLimitExceeded>();
    }, tags: 'daily_limit_exceeded_over',);
  }, tags: 'daily_limit_exceeded',);
}

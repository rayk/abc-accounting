@Tags(['daily_limit'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract: daily withdrawal limit — happy path and DailyLimitExceeded.
void setDailyLimitContract(LedgerFactory factory) {
  group('daily limit — happy path', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'setDailyLimit stores the limit; subsequent withdrawals within it '
          'succeed.',
        )
        ..filterTypes({AccountState});
      ledger = await factory(const AccountId('sut-daily-limit-happy'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('withdrawal within the daily limit succeeds', () async {
      await ledger.deposit(const Money(1000));
      await ledger.setDailyLimit(const Money(500));
      check(await ledger.withdraw(const Money(300)))
          .success
          .balance
          .equals(const Money(700));
    });
  });

  group('daily limit — DailyLimitExceeded', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'A withdrawal beyond the daily limit is rejected with '
          'DailyLimitExceeded.',
        )
        ..filterTypes({AccountState, DailyLimitExceeded});
      ledger = await factory(const AccountId('sut-daily-limit-exceeded'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('the daily limit is enforced', () async {
      await ledger.deposit(const Money(1000));
      await ledger.setDailyLimit(const Money(300));
      check(await ledger.withdraw(const Money(400)))
          .failure
          .isA<DailyLimitExceeded>();
    });
  });
}

@Tags(['change_feed'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract: every successful state-changing op emits the new state exactly
/// once, in order.
void changeFeedContract(LedgerFactory factory) {
  group('change feed', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'Every successful state-changing op emits the new state '
          'exactly once, in order.',
        )
        ..filterTypes({AccountState});
      ledger = await factory(const AccountId('sut-change-feed'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('a series of transactions yields the expected running balance',
        () async {
      final balances = <int>[];
      final sub =
          ledger.changes.listen((s) => balances.add(s.balance.minorUnits));

      await ledger.deposit(const Money(200)); // 200
      await ledger.deposit(const Money(50)); //  250
      await ledger.withdraw(const Money(30)); // 220
      await ledger.setDailyLimit(const Money(1000)); // 220 (limit set)
      await ledger.withdraw(const Money(20)); //  200
      await pumpEventQueue();

      check(ledger.state).balance.equals(const Money(200));
      await sub.cancel();
      // Every state-changing op emits exactly once, in order.
      check(balances).deepEquals([200, 250, 220, 220, 200]);
    });
  });
}

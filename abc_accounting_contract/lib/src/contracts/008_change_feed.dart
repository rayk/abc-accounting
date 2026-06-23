@Tags(['change_feed'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';

/// Contract for [Ledger.changes] — the state-change stream.
/// Authored: 2026-06-22. Never modified after initial authoring.
void changeFeedContract(LedgerFactory factory) {
  late Ledger sut;
  setUp(() async => sut = await factory(const AccountId('change-feed')));
  tearDown(() => sut.dispose());

  group('changes — emits new state after each successful operation', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'Every successful state-changing operation emits the new state '
        'exactly once on [Ledger.changes], in the order the operations '
        'were applied.',
      )
      ..filterTypes({AccountState, Money}),);

    test('a series of operations yields states in order', () async {
      final balances = <int>[];
      final sub =
          sut.changes.listen((s) => balances.add(s.balance.minorUnits));

      await sut.deposit(const Money(200));
      await sut.deposit(const Money(50));
      await sut.withdraw(const Money(30));
      await sut.setDailyLimit(const Money(1000));
      await sut.withdraw(const Money(20));
      await pumpEventQueue();

      await sub.cancel();
      check(balances).deepEquals([200, 250, 220, 220, 200]);
    }, tags: 'change_feed_ordering_balance',);
  }, tags: 'change_feed_ordering',);
}

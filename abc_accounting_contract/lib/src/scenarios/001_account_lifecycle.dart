@Tags(['scenario'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../ledger_checks.dart';

/// Stateful end-to-end scenario: one shared SUT, state carries across groups.
///
/// Each group tags itself with 'scenario_lifecycle' so the runner can target
/// just this scenario. The outer setUpAll/tearDownAll create and dispose the
/// single shared [Ledger]; the groups execute in sequence and verify the
/// cumulative state.
void accountLifecycleScenario(LedgerFactory factory) {
  group('account lifecycle scenario', () {
    late Ledger ledger;

    setUpAll(() async {
      ledger = await factory(const AccountId('sut-lifecycle'));
      Ledger.verify(ledger);
    });

    tearDownAll(() => ledger.dispose());

    group(
      'lifecycle: deposit funds',
      () {
        test('deposit increases balance', () async {
          check(await ledger.deposit(const Money(500)))
              .success
              .balance
              .equals(const Money(500));
        });

        test('balance reflects total deposits', () async {
          await ledger.deposit(const Money(200));
          check(ledger.state).balance.equals(const Money(700));
        });
      },
      tags: 'scenario_lifecycle',
    );

    group(
      'lifecycle: freeze account',
      () {
        test('freeze succeeds', () async {
          await ledger.freeze();
          check(ledger.state).status.equals(AccountStatus.frozen);
        });

        test('deposit on frozen account returns AccountNotActive', () async {
          check(await ledger.deposit(const Money(10)))
              .failure
              .isA<AccountNotActive>();
        });
      },
      tags: 'scenario_lifecycle',
    );

    group(
      'lifecycle: close account',
      () {
        test('closeAccount succeeds', () async {
          await ledger.closeAccount();
          check(ledger.state).status.equals(AccountStatus.closed);
        });

        test('deposit on closed account returns AccountNotActive', () async {
          check(await ledger.deposit(const Money(10)))
              .failure
              .isA<AccountNotActive>();
        });

        test('withdraw on closed account returns AccountNotActive', () async {
          check(await ledger.withdraw(const Money(10)))
              .failure
              .isA<AccountNotActive>();
        });
      },
      tags: 'scenario_lifecycle',
    );
  });
}

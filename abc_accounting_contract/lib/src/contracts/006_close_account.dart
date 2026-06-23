@Tags(['close_account'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract for [Ledger.closeAccount].
/// Authored: 2026-06-22. Never modified after initial authoring.
void closeAccountContract(LedgerFactory factory) {
  late Ledger sut;
  setUp(() async => sut = await factory(const AccountId('close-account')));
  tearDown(() => sut.dispose());

  group('closeAccount — terminal state', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'closeAccount sets status to closed. Closed is a terminal state.',
      )
      ..filterTypes({AccountState}),);

    test('closeAccount sets status to closed', () async {
      await sut.closeAccount();
      check(sut.state).status.equals(AccountStatus.closed);
    }, tags: 'close_account_terminal_status',);
  }, tags: 'close_account_terminal',);

  group('closeAccount — AccountNotActive', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'A closed account permanently rejects money movement with '
        'AccountNotActive.',
      )
      ..filterTypes({AccountNotActive, AccountState}),);

    test('closed account rejects deposit', () async {
      await sut.closeAccount();
      check(await sut.deposit(const Money(10)))
          .failure
          .isA<AccountNotActive>();
    }, tags: 'close_account_not_active_deposit',);

    test('closed account rejects withdraw', () async {
      await sut.closeAccount();
      check(await sut.withdraw(const Money(10)))
          .failure
          .isA<AccountNotActive>();
    }, tags: 'close_account_not_active_withdraw',);
  }, tags: 'close_account_not_active',);
}

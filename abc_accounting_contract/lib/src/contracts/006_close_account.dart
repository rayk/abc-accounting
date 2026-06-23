@Tags(['close_account'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract: close account — terminal state and subsequent commands rejected.
void closeAccountContract(LedgerFactory factory) {
  group('close account — terminal state', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'A closed account is terminal: status is closed.',
        )
        ..filterTypes({AccountState});
      ledger = await factory(const AccountId('sut-close-terminal'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('a closed account has status closed', () async {
      await ledger.closeAccount();
      check(ledger.state).status.equals(AccountStatus.closed);
    });
  });

  group('close account — AccountNotActive on subsequent commands', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'A closed account rejects further money movement with '
          'AccountNotActive.',
        )
        ..filterTypes({AccountState, AccountNotActive});
      ledger = await factory(const AccountId('sut-close-blocks'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('a closed account rejects deposit', () async {
      await ledger.closeAccount();
      check(await ledger.deposit(const Money(10)))
          .failure
          .isA<AccountNotActive>();
    });

    test('a closed account rejects withdraw', () async {
      await ledger.closeAccount();
      check(await ledger.withdraw(const Money(10)))
          .failure
          .isA<AccountNotActive>();
    });
  });
}

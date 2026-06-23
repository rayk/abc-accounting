@Tags(['freeze'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract: freeze — idempotent and blocks money movement.
void freezeContract(LedgerFactory factory) {
  group('freeze — idempotent', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'freeze is idempotent: calling it twice does not error and leaves '
          'the account frozen.',
        )
        ..filterTypes({AccountState});
      ledger = await factory(const AccountId('sut-freeze-idempotent'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('a frozen account rejects money movement (freeze is idempotent)',
        () async {
      await ledger.deposit(const Money(100));
      await ledger.freeze();
      await ledger.freeze(); // idempotent: no error, no change
      check(await ledger.deposit(const Money(10)))
          .failure
          .isA<AccountNotActive>();
    });
  });

  group('freeze — AccountNotActive blocks money movement', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'A frozen account rejects money movement with AccountNotActive.',
        )
        ..filterTypes({AccountState, AccountNotActive});
      ledger = await factory(const AccountId('sut-freeze-blocks'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('frozen account rejects deposit', () async {
      await ledger.freeze();
      check(await ledger.deposit(const Money(50)))
          .failure
          .isA<AccountNotActive>();
    });

    test('frozen account rejects withdraw', () async {
      await ledger.deposit(const Money(100));
      await ledger.freeze();
      check(await ledger.withdraw(const Money(10)))
          .failure
          .isA<AccountNotActive>();
    });
  });
}

@Tags(['freeze'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract for [Ledger.freeze].
/// Authored: 2026-06-22. Never modified after initial authoring.
void freezeContract(LedgerFactory factory) {
  late Ledger sut;
  setUp(() async => sut = await factory(const AccountId('freeze')));
  tearDown(() => sut.dispose());

  group('freeze — idempotent', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'freeze is idempotent: calling it twice does not error and '
        'the account remains frozen.',
      )
      ..filterTypes({AccountState}));

    test('calling freeze twice does not error', () async {
      await sut.freeze();
      await sut.freeze(); // second call must not throw
      check(sut.state).status.equals(AccountStatus.frozen);
    }, tags: 'freeze_idempotent_double_call');
  }, tags: 'freeze_idempotent');

  group('freeze — AccountNotActive', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'A frozen account rejects money movement with AccountNotActive.',
      )
      ..filterTypes({AccountNotActive, AccountState}));

    test('frozen account rejects deposit', () async {
      await sut.freeze();
      check(await sut.deposit(const Money(50)))
          .failure
          .isA<AccountNotActive>();
    }, tags: 'freeze_not_active_deposit');

    test('frozen account rejects withdraw', () async {
      await sut.deposit(const Money(100));
      await sut.freeze();
      check(await sut.withdraw(const Money(10)))
          .failure
          .isA<AccountNotActive>();
    }, tags: 'freeze_not_active_withdraw');
  }, tags: 'freeze_not_active');
}

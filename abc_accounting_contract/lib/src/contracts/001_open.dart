@Tags(['open'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/matchers.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract for [Ledger] initial state.
/// Authored: 2026-06-22. Never modified after initial authoring.
void openContract(LedgerFactory factory) {
  late Ledger sut;
  setUp(() async => sut = await factory(const AccountId('open')));
  tearDown(() => sut.dispose());

  group('open — initial state', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'A fresh ledger opens at zero balance, version 0, status open.',
      )
      ..filterTypes({AccountState}));

    test('opens at zero balance, version 0, status open', () {
      checkAllOf<AccountState>(sut.state, [
        (Subject<AccountState> s) => s.balance.equals(Money.zero),
        (Subject<AccountState> s) => s.version.equals(const Version(0)),
        (Subject<AccountState> s) => s.status.equals(AccountStatus.open),
      ]);
    }, tags: 'open_initial_state');
  }, tags: 'open_initial');
}

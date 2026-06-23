@Tags(['open'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/matchers.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract: a fresh ledger has the correct initial state.
void openContract(LedgerFactory factory) {
  group('open — initial state', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'A fresh ledger opens at zero balance, version 0, status open.',
        )
        ..filterTypes({AccountState});
      ledger = await factory(const AccountId('sut-open'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('opens at zero balance, version 0, status open', () {
      // checkAllOf reports every violated invariant at once, so the
      // implementer fixes the whole opening state in a single pass.
      checkAllOf<AccountState>(ledger.state, [
        (Subject<AccountState> s) => s.balance.equals(Money.zero),
        (Subject<AccountState> s) => s.version.equals(const Version(0)),
        (Subject<AccountState> s) => s.status.equals(AccountStatus.open),
      ]);
    });
  });
}

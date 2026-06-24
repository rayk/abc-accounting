/// Account-lifecycle scenario (`001`).
///
/// A single order-dependent sequence driven serially by `runSequence`:
/// deposit → freeze → deposit-on-frozen (rejects `AccountNotActive`). Unlike a
/// witness/region/law case, the steps share one live `Ledger` and must run in
/// order, so this is authored as one sequence body rather than separate cases.
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

/// Registers the account-lifecycle sequence against [factory].
void accountLifecycleScenario(LedgerFactory factory) {
  testSequence<Ledger>(
    description: 'lifecycle: deposit → freeze → deposit-on-frozen rejects',
    sut: () => factory(const AccountId('eac-seq')),
    steps: [
      Step('deposit Money(100) succeeds', (l) async {
        final r = await l.deposit(const Money(100));
        check(r.isRight()).isTrue();
      }),
      Step('freeze succeeds', (l) async {
        final r = await l.freeze();
        check(r.isRight()).isTrue();
      }),
      Step(
        'deposit on frozen account rejects AccountNotActive',
        (l) async {
          final r = await l.deposit(const Money(50));
          r.match(
            (e) => check(e).isA<AccountNotActive>(),
            (_) => fail('expected Left(AccountNotActive)'),
          );
        },
      ),
    ],
    tags: {'contract-ledger', 'sig-lifecycle'},
  );
}

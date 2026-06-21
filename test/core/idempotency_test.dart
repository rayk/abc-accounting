import 'package:fpdart/fpdart.dart';
import 'package:abc_accounting/abc_accounting_internals.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

/// The idempotent / non-idempotent distinction, exercised end-to-end through
/// the `handle` use-case.
void main() {
  const id = AccountId('acc');

  AccountState ok(Either<LedgerError, AccountState> r) =>
      r.getOrElse((_) => fail('expected Right, got $r'));

  test('keyed command is idempotent: re-applying the same key is a no-op',
      () async {
    final env = testEnv();
    const key = Option.of(CommandId('k1'));

    final s1 = ok(await deposit(id, const Money(100), key: key).run(env));
    final s2 = ok(await deposit(id, const Money(100), key: key).run(env));

    expect(s1.balance, const Money(100));
    expect(s2, s1); // identical state, including version
    expect(s2.version, const Version(1));
  });

  test('unkeyed deposit is non-idempotent: version advances each call',
      () async {
    final env = testEnv();

    ok(await deposit(id, const Money(50)).run(env));
    final s = ok(await deposit(id, const Money(50)).run(env));

    expect(s.balance, const Money(100));
    expect(s.version, const Version(2));
  });

  test('idempotent transition does not advance version on repeat', () async {
    final env = testEnv();

    final v1 = ok(await setDailyLimit(id, const Money(500)).run(env)).version;
    final v2 = ok(await setDailyLimit(id, const Money(500)).run(env)).version;

    expect(v1, const Version(1));
    expect(v2, const Version(1)); // no-op emitted nothing
  });
}

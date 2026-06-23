import 'package:fpdart/fpdart.dart';
import 'package:abc_accounting_impl/abc_accounting_impl_internals.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

/// `handle` and friends, run against a fake [LedgerEnv] — no Riverpod needed to
/// test the logic (effects are values).
void main() {
  const id = AccountId('acc');

  AccountState ok(Either<LedgerError, AccountState> r) =>
      r.getOrElse((_) => fail('expected Right, got $r'));
  bool isLeft(Either<LedgerError, Object?> r) =>
      r.match((_) => true, (_) => false);

  test('handle persists events; currentState rebuilds from them', () async {
    final env = testEnv();

    await deposit(id, const Money(100)).run(env);
    await withdraw(id, const Money(30)).run(env);

    final state = ok(await currentState(id).run(env));
    expect(state.balance, const Money(70));
    expect(state.version, const Version(2));
  });

  test('a repository failure surfaces as a typed Left', () async {
    final env = testEnv(repo: const FailingLedgerRepository());

    final result = await deposit(id, const Money(10)).run(env);

    expect(result.match((l) => l, (_) => null), isA<StorageFailure>());
  });

  test('a rejected command persists nothing', () async {
    final env = testEnv();

    final rejected = await withdraw(id, const Money(10)).run(env); // no funds
    expect(isLeft(rejected), isTrue);

    final state = ok(await currentState(id).run(env));
    expect(state.version, const Version(0));
  });
}

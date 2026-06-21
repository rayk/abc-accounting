import 'package:fpdart/fpdart.dart';
// The contract was collapsed into abc_accounting, so this kit depends on it.
// It is still written against the Ledger *interface* and a LedgerFactory seam —
// it just no longer has the compile-time guarantee that the implementation is
// out of scope. Bind the factory to a stub/reference/real SUT to run.
import 'package:abc_accounting/abc_accounting.dart';
import 'package:test/test.dart';

/// A reusable, black-box **acceptance suite** written against the [Ledger]
/// *interface*, obtaining its system under test through a [LedgerFactory] seam.
///
/// Bind [factory] to [UnimplementedLedger] to author the spec before any
/// implementation exists (every scenario goes red with `UnimplementedError` —
/// the TDD "red"); bind it to a real implementation to make the spec pass. The
/// *same* suite later serves as a contract test for any future [Ledger].
void ledgerAcceptance(String name, LedgerFactory factory) {
  group('Ledger acceptance: $name', () {
    late Ledger ledger;
    setUp(() async {
      ledger = await factory(const AccountId('sut'));
      Ledger.verify(ledger); // the SUT must `extend` the token-guarded base
    });
    tearDown(() => ledger.dispose());

    AccountState ok(Either<LedgerError, AccountState> r) =>
        r.getOrElse((_) => fail('expected success, got $r'));
    LedgerError bad(Either<LedgerError, AccountState> r) =>
        r.match((e) => e, (_) => fail('expected failure, got $r'));

    test('opens at zero balance, version 0, status open', () {
      expect(ledger.state.balance, const Money(0));
      expect(ledger.state.version, const Version(0));
      expect(ledger.state.status, AccountStatus.open);
    });

    test('deposit increases the balance', () async {
      expect(
          ok(await ledger.deposit(const Money(500))).balance, const Money(500));
    });

    test('withdraw decreases the balance', () async {
      await ledger.deposit(const Money(500));
      expect(ok(await ledger.withdraw(const Money(120))).balance,
          const Money(380));
    });

    test('overdraw is rejected and leaves state unchanged', () async {
      await ledger.deposit(const Money(100));
      final before = ledger.state;
      expect(bad(await ledger.withdraw(const Money(1000))),
          isA<InsufficientFunds>());
      expect(ledger.state, before);
    });

    test('the daily limit is enforced', () async {
      await ledger.deposit(const Money(1000));
      await ledger.setDailyLimit(const Money(300));
      expect(bad(await ledger.withdraw(const Money(400))),
          isA<DailyLimitExceeded>());
    });

    test('a frozen account rejects money movement (freeze is idempotent)',
        () async {
      await ledger.deposit(const Money(100));
      await ledger.freeze();
      await ledger.freeze(); // idempotent: no error, no change
      expect(
          bad(await ledger.deposit(const Money(10))), isA<AccountNotActive>());
    });

    test('a closed account is terminal', () async {
      await ledger.closeAccount();
      expect(ledger.state.status, AccountStatus.closed);
      expect(
          bad(await ledger.deposit(const Money(10))), isA<AccountNotActive>());
    });

    test('a keyed deposit is idempotent across retries', () async {
      const key = Option.of(CommandId('retry-1'));
      final first =
          ok(await ledger.deposit(const Money(100), idempotencyKey: key));
      final second =
          ok(await ledger.deposit(const Money(100), idempotencyKey: key));
      expect(first.balance, const Money(100));
      expect(second, first); // applied exactly once
    });

    test('a series of transactions yields the expected running balance',
        () async {
      final balances = <int>[];
      final sub =
          ledger.changes.listen((s) => balances.add(s.balance.minorUnits));

      await ledger.deposit(const Money(200)); // 200
      await ledger.deposit(const Money(50)); //  250
      await ledger.withdraw(const Money(30)); // 220
      await ledger.setDailyLimit(const Money(1000)); // 220 (limit set)
      await ledger.withdraw(const Money(20)); //  200
      await pumpEventQueue();

      expect(ledger.state.balance, const Money(200));
      await sub.cancel();
      // Every state-changing op emits exactly once, in order.
      expect(balances, [200, 250, 220, 220, 200]);
    });
  });
}

/// A not-yet-implemented [Ledger]: every member throws `UnimplementedError`.
///
/// Because [Ledger] is a token-guarded base whose members default to throwing,
/// the stub is just the base with the token and **no overrides** — overriding
/// nothing *is* the unimplemented ledger. A [LedgerFactory] can yield it so the
/// suite runs in its pre-implementation, red state.
final class UnimplementedLedger extends Ledger {
  UnimplementedLedger() : super(token: Ledger.token);
}

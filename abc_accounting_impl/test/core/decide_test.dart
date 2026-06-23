import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fpdart/fpdart.dart';
import 'package:abc_accounting_impl/abc_accounting_impl_internals.dart';
import 'package:test/test.dart';

void main() {
  const id = AccountId('acc');
  final at = DateTime.utc(2026);
  const noCause = Option<CommandId>.none();
  final empty = AccountState.empty(id);
  final funded = replay(empty, [Deposited(amount: const Money(100), at: at)]);

  IList<LedgerEvent> eventsOf(Either<LedgerError, IList<LedgerEvent>> e) =>
      e.getOrElse((_) => <LedgerEvent>[].lock);
  LedgerError? errorOf(Either<LedgerError, IList<LedgerEvent>> e) =>
      e.match((l) => l, (_) => null);

  group('deposit', () {
    test('positive amount on open account emits Deposited', () {
      final r = decide(empty, const Deposit(Money(50)), at, noCause);
      expect(eventsOf(r), [Deposited(amount: const Money(50), at: at)]);
    });

    test('non-positive amount is rejected', () {
      final r = decide(empty, const Deposit(Money(0)), at, noCause);
      expect(errorOf(r), isA<AmountMustBePositive>());
    });

    test('deposit on a frozen account is rejected', () {
      final frozen = replay(empty, [Frozen(at: at)]);
      final r = decide(frozen, const Deposit(Money(10)), at, noCause);
      expect(errorOf(r), isA<AccountNotActive>());
    });
  });

  group('withdraw', () {
    test('within balance emits Withdrawn', () {
      final r = decide(funded, const Withdraw(Money(40)), at, noCause);
      expect(eventsOf(r), [Withdrawn(amount: const Money(40), at: at)]);
    });

    test('over balance → InsufficientFunds', () {
      final r = decide(funded, const Withdraw(Money(1000)), at, noCause);
      expect(errorOf(r), isA<InsufficientFunds>());
    });

    test(
        'over the daily limit → DailyLimitExceeded reporting the attempted total',
        () {
      final limited =
          replay(funded, [LimitSet(dailyLimit: const Money(30), at: at)]);
      final err =
          errorOf(decide(limited, const Withdraw(Money(40)), at, noCause));
      expect(err, isA<DailyLimitExceeded>());
      expect((err! as DailyLimitExceeded).attempted, const Money(40));
    });
  });

  group('idempotent transitions emit no event when state already holds', () {
    test('setting the same limit twice → second is a no-op', () {
      final limited =
          replay(empty, [LimitSet(dailyLimit: const Money(500), at: at)]);
      final r = decide(limited, const SetDailyLimit(Money(500)), at, noCause);
      expect(eventsOf(r), isEmpty);
    });

    test('freezing a frozen account → no-op', () {
      final frozen = replay(empty, [Frozen(at: at)]);
      final r = decide(frozen, const Freeze(), at, noCause);
      expect(eventsOf(r), isEmpty);
    });

    test('closing a closed account → no-op', () {
      final closed = replay(empty, [Closed(at: at)]);
      final r = decide(closed, const Close(), at, noCause);
      expect(eventsOf(r), isEmpty);
    });

    test('set limit on a closed account is rejected', () {
      final closed = replay(empty, [Closed(at: at)]);
      final r = decide(closed, const SetDailyLimit(Money(10)), at, noCause);
      expect(errorOf(r), isA<AccountNotActive>());
    });
  });

  group('deciderAt currying', () {
    test('produces a Decider that fixes now and cause', () {
      final Decider<AccountState, LedgerCommand, LedgerEvent> d =
          deciderAt(at, noCause);
      expect(d(empty, const Deposit(Money(5))),
          decide(empty, const Deposit(Money(5)), at, noCause));
    });
  });
}

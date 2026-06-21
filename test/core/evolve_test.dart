import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:abc_accounting/abc_accounting_internals.dart';
import 'package:test/test.dart';

void main() {
  const id = AccountId('acc');
  final at = DateTime.utc(2026);
  final empty = AccountState.empty(id);

  group('applyEvent', () {
    test('is deterministic', () {
      final e = Deposited(amount: const Money(100), at: at);
      expect(applyEvent(empty, e), applyEvent(empty, e));
    });

    test('deposit adds to balance and bumps version', () {
      final next =
          applyEvent(empty, Deposited(amount: const Money(100), at: at));
      expect(next.balance, const Money(100));
      expect(next.version, const Version(1));
    });

    test('withdraw subtracts and tracks withdrawnToday', () {
      final funded =
          applyEvent(empty, Deposited(amount: const Money(100), at: at));
      final next =
          applyEvent(funded, Withdrawn(amount: const Money(30), at: at));
      expect(next.balance, const Money(70));
      expect(next.withdrawnToday, const Money(30));
      expect(next.version, const Version(2));
    });

    test('limit set, freeze and close change the right fields', () {
      final limited =
          applyEvent(empty, LimitSet(dailyLimit: const Money(500), at: at));
      expect(limited.dailyLimit.toNullable(), const Money(500));

      final frozen = applyEvent(empty, Frozen(at: at));
      expect(frozen.status, AccountStatus.frozen);

      final closed = applyEvent(empty, Closed(at: at));
      expect(closed.status, AccountStatus.closed);
    });
  });

  group('replay', () {
    test('equals a left fold of applyEvent', () {
      final events = <LedgerEvent>[
        Deposited(amount: const Money(100), at: at),
        Withdrawn(amount: const Money(40), at: at),
        LimitSet(dailyLimit: const Money(500), at: at),
      ];
      expect(
        replay(empty, events),
        events.fold(empty, applyEvent),
      );
    });

    test('balanceOf projects the folded balance', () {
      final events = IList([
        Deposited(amount: const Money(100), at: at),
        Withdrawn(amount: const Money(40), at: at),
      ]);
      expect(balanceOf(replay(empty, events)), const Money(60));
    });
  });

  group('LedgerReducer (callable object)', () {
    test('behaves as the applyEvent function', () {
      final e = Deposited(amount: const Money(10), at: at);
      expect(ledgerReducer(empty, e), applyEvent(empty, e));
    });
  });
}

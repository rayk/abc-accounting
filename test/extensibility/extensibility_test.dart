import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:abc_accounting/abc_accounting.dart';
import 'package:test/test.dart';

import '../../example/extensions/v1_substitution.dart';
import '../../example/extensions/v2_composition.dart';
import '../../example/extensions/v3_new_behavior.dart';
import '../contract/ledger_repository_contract_test.dart'
    show ledgerRepositoryContract;
import '../support/fakes.dart';

/// Proves the three extension vectors work against the *unmodified* core, using
/// only the tight public API.
void main() {
  // ── Vector 1 — Substitute ─────────────────────────────────────────────────
  // The user's repository must satisfy the very same contract as the default.
  ledgerRepositoryContract(
    'JournaledLedgerRepository (V1 substitute)',
    JournaledLedgerRepository.new,
  );

  // ── Vector 2 — Compose ────────────────────────────────────────────────────
  group('V2 — composition', () {
    test('transfer moves money between two ledgers sharing an env', () async {
      final env = testEnv();
      final from = await AccountLedger.open(env, const AccountId('from'));
      final to = await AccountLedger.open(env, const AccountId('to'));
      await from.deposit(const Money(100));

      final result = await transfer(from, to, const Money(40));

      result.match(
        (_) => fail('expected Right'),
        (states) {
          expect(states.$1.balance, const Money(60)); // source
          expect(states.$2.balance, const Money(40)); // destination
        },
      );
      await from.dispose();
      await to.dispose();
    });

    test('transfer short-circuits when the source lacks funds', () async {
      final env = testEnv();
      final from = await AccountLedger.open(env, const AccountId('from'));
      final to = await AccountLedger.open(env, const AccountId('to'));

      final result = await transfer(from, to, const Money(40));
      expect(result.match((_) => true, (_) => false), isTrue); // Left
      expect(to.state.version, const Version(0)); // untouched

      await from.dispose();
      await to.dispose();
    });

    test('LoggingLedger decorates without changing behavior', () async {
      final env = testEnv();
      final inner = await AccountLedger.open(env, const AccountId('acc'));
      final logs = <String>[];
      final ledger = LoggingLedger(inner, logs.add);

      final result = await ledger.deposit(const Money(10));

      expect(result.match((_) => false, (s) => s.balance == const Money(10)),
          isTrue);
      expect(logs, hasLength(2));
      expect(logs.first, contains('deposit begin'));
      expect(logs.last, contains('deposit ok'));
      await ledger.dispose();
    });
  });

  // ── Vector 3 — Add ────────────────────────────────────────────────────────
  group('V3 — new behavior', () {
    test('StatementProjection derives a statement from the event log', () {
      final at = DateTime.utc(2026);
      final events = IList<LedgerEvent>([
        Deposited(amount: const Money(100), at: at),
        Withdrawn(amount: const Money(30), at: at),
        Deposited(amount: const Money(20), at: at),
        Frozen(at: at),
      ]);

      const projection = StatementProjection();
      final statement = projection.project(events);

      expect(statement.totalDeposits, const Money(120));
      expect(statement.totalWithdrawals, const Money(30));
      expect(statement.entries, 4);
    });
  });
}

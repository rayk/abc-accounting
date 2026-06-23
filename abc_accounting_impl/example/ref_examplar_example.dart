import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fpdart/fpdart.dart';
import 'package:abc_accounting_impl/abc_accounting_impl_internals.dart';
import 'package:riverpod/riverpod.dart';

import 'extensions/v3_new_behavior.dart';

/// A fixed clock, injected via the override seam, so the run is deterministic.
final class _FixedClock implements Clock {
  const _FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 1, 1, 9);
}

/// Drives a [Ledger] (obtained from [ledgerProvider]) through a few
/// transactions — including a keyed idempotent retry — then runs the V3
/// projection over the persisted log.
Future<void> main() async {
  final container = ProviderContainer(
    overrides: [clockProvider.overrideWithValue(const _FixedClock())],
  );

  const id = AccountId('alice');
  final ledger = await container.read(ledgerProvider(id).future);

  final subscription = ledger.changes.listen(
    (s) => print('balance=${s.balance.minorUnits} version=${s.version.value}'),
  );

  await ledger.setDailyLimit(const Money(1000));
  await ledger.deposit(const Money(500));
  await ledger.withdraw(const Money(120));

  // Keyed retry: submitting the same idempotency key twice applies once.
  const key = Option.of(CommandId('topup-42'));
  await ledger.deposit(const Money(80), idempotencyKey: key);
  await ledger.deposit(const Money(80), idempotencyKey: key);

  // Vector-3 projection over the persisted log.
  final env = container.read(ledgerEnvProvider);
  final events =
      (await env.repo.load(id).run()).getOrElse((_) => <LedgerEvent>[].lock);
  final statement = container.read(statementProjectionProvider).project(events);
  print(
    'statement: deposits=${statement.totalDeposits.minorUnits} '
    'withdrawals=${statement.totalWithdrawals.minorUnits} '
    'entries=${statement.entries}',
  );

  await subscription.cancel();
  await ledger.dispose();
  container.dispose();
}

import 'package:fpdart/fpdart.dart';
import 'package:abc_accounting/abc_accounting.dart';

/// Extension **Vector 2 — Compose**: *new* signatures built entirely from the
/// existing public API ([Ledger]). Nothing in the library changes.

/// Move [amount] from one ledger to another.
///
/// A brand-new operation composed from two existing ones ([Ledger.withdraw] then
/// [Ledger.deposit]) sequenced in the `TaskEither` monad. The deposit is thunked
/// so it only runs if the withdrawal succeeds — short-circuiting comes free from
/// `Either`. Returns the resulting `(source, destination)` states.
Future<Either<LedgerError, (AccountState source, AccountState destination)>>
    transfer(
  Ledger from,
  Ledger to,
  Money amount, {
  Option<CommandId> idempotencyKey = const None(),
}) {
  TaskEither<LedgerError, AccountState> step(LedgerResult Function() run) =>
      TaskEither(run);

  return step(() => from.withdraw(amount, idempotencyKey: idempotencyKey))
      .flatMap(
        (source) =>
            step(() => to.deposit(amount, idempotencyKey: idempotencyKey))
                .map((destination) => (source, destination)),
      )
      .run();
}

/// A [Ledger] decorator that logs every operation, delegating to an [inner]
/// ledger. Demonstrates extending behavior by *composing* the interface — a new
/// implementation wrapping an existing one — rather than editing the SUT.
final class LoggingLedger implements Ledger {
  LoggingLedger(this.inner, this.log);

  final Ledger inner;
  final void Function(String line) log;

  Future<Either<LedgerError, AccountState>> _audited(
    String op,
    LedgerResult Function() run,
  ) async {
    log('[$id] $op begin');
    final result = await run();
    log('[$id] $op ${result.match((_) => 'rejected', (_) => 'ok')}');
    return result;
  }

  @override
  AccountId get id => inner.id;

  @override
  AccountState get state => inner.state;

  @override
  Stream<AccountState> get changes => inner.changes;

  @override
  LedgerResult deposit(Money amount,
          {Option<CommandId> idempotencyKey = const None()}) =>
      _audited('deposit',
          () => inner.deposit(amount, idempotencyKey: idempotencyKey));

  @override
  LedgerResult withdraw(Money amount,
          {Option<CommandId> idempotencyKey = const None()}) =>
      _audited('withdraw',
          () => inner.withdraw(amount, idempotencyKey: idempotencyKey));

  @override
  LedgerResult setDailyLimit(Money limit) =>
      _audited('setDailyLimit', () => inner.setDailyLimit(limit));

  @override
  LedgerResult freeze() => _audited('freeze', inner.freeze);

  @override
  LedgerResult closeAccount() => _audited('closeAccount', inner.closeAccount);

  @override
  Future<void> dispose() => inner.dispose();
}

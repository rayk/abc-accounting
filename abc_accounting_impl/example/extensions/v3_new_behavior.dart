import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:abc_accounting_impl/abc_accounting_impl_internals.dart';
import 'package:riverpod/riverpod.dart';

/// Extension **Vector 3 — Add**: an entirely new contract for new behavior,
/// plugged into the existing seams (the event log, the DI graph) without
/// modifying anything in the library.

/// A derived read-model computed from an account's event log.
///
/// A brand-new `abstract interface class` — the open extension point. Users add
/// new projections by implementing it; the sealed *events* are reused, never
/// extended.
abstract interface class LedgerProjection<R> {
  R project(IList<LedgerEvent> events);
}

/// A summary statement derived from the log. A record — new structural type.
typedef Statement = ({
  Money totalDeposits,
  Money totalWithdrawals,
  int entries
});

/// Folds the event log into a [Statement]. New behavior, additive only.
final class StatementProjection implements LedgerProjection<Statement> {
  const StatementProjection();

  @override
  Statement project(IList<LedgerEvent> events) {
    var deposits = Money.zero;
    var withdrawals = Money.zero;
    for (final event in events) {
      switch (event) {
        case Deposited(:final amount):
          deposits = deposits + amount;
        case Withdrawn(:final amount):
          withdrawals = withdrawals + amount;
        case LimitSet() || Frozen() || Closed():
          break;
      }
    }
    return (
      totalDeposits: deposits,
      totalWithdrawals: withdrawals,
      entries: events.length,
    );
  }
}

/// A new Riverpod provider for the new capability — additive wiring that lives
/// alongside (not inside) the library's providers.
final statementProjectionProvider =
    Provider<LedgerProjection<Statement>>((ref) => const StatementProjection());

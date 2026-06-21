import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fpdart/fpdart.dart';
import 'package:abc_accounting/abc_accounting.dart';

/// Extension **Vector 1 — Substitute**: same signature, different *process*.
///
/// [JournaledLedgerRepository] implements the exact [LedgerRepository] contract
/// but uses a different internal strategy: a single global append-only journal
/// of `(id, event)` entries, reconstructing each account's log by filtering on
/// load. Observably identical to the default per-id-map implementation — so it
/// passes the *same* contract test — yet the algorithm is swapped underneath.
///
/// A user drops this in via `ledgerRepositoryProvider.overrideWithValue(...)`
/// without touching the library.
final class JournaledLedgerRepository implements LedgerRepository {
  IList<(AccountId, LedgerEvent)> _journal = IList();

  @override
  TaskEither<LedgerError, IList<LedgerEvent>> load(AccountId id) =>
      TaskEither.of(
        _journal
            .where((entry) => entry.$1.value == id.value)
            .map((entry) => entry.$2)
            .toIList(),
      );

  @override
  TaskEither<LedgerError, Unit> append(
    AccountId id,
    IList<LedgerEvent> events,
  ) =>
      TaskEither.tryCatch(
        () async {
          _journal = _journal.addAll(events.map((e) => (id, e)));
          return unit;
        },
        (error, _) => StorageFailure('$error'),
      );
}

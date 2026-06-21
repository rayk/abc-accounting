import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fpdart/fpdart.dart';

import '../contract/contract.dart';

/// The persistence boundary for the event log.
///
/// Demonstrated Dart feature: an **`abstract interface class`** whose methods
/// return **`TaskEither`** — async, fallible effects as *values*. Nothing here
/// throws across the boundary; failures arrive as a typed [LedgerError]. This is
/// the seam users override (Vector 1) and decorate (Vector 2), and the one the
/// shared contract test pins down.
abstract interface class LedgerRepository {
  /// Load all events for [id] in append order. Unknown ids yield an empty log.
  TaskEither<LedgerError, IList<LedgerEvent>> load(AccountId id);

  /// Append [events] to [id]'s log, atomically with respect to other appends.
  TaskEither<LedgerError, Unit> append(AccountId id, IList<LedgerEvent> events);
}

/// A simple in-memory implementation — the default, and the fake used in tests.
///
/// Stateless from the caller's perspective (it exposes no mutable surface); the
/// internal map is an implementation detail behind the [TaskEither] effects.
final class InMemoryLedgerRepository implements LedgerRepository {
  final Map<String, IList<LedgerEvent>> _log = {};

  IList<LedgerEvent> _at(AccountId id) =>
      Option.fromNullable(_log[id.value]).getOrElse(() => IList<LedgerEvent>());

  @override
  TaskEither<LedgerError, IList<LedgerEvent>> load(AccountId id) =>
      TaskEither.of(_at(id));

  @override
  TaskEither<LedgerError, Unit> append(
    AccountId id,
    IList<LedgerEvent> events,
  ) =>
      TaskEither.tryCatch(
        () async {
          _log[id.value] = _at(id).addAll(events);
          return unit;
        },
        (error, _) => StorageFailure('$error'),
      );
}

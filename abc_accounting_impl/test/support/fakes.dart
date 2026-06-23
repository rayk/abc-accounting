import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fpdart/fpdart.dart';
import 'package:abc_accounting_impl/abc_accounting_impl_internals.dart';

/// Hand-written test doubles. The seams are narrow enough that fakes are a few
/// lines each — no mocking framework, and assertions are on resulting *state*.

/// A clock pinned to a fixed instant, advanceable by the test.
final class FixedClock implements Clock {
  FixedClock([DateTime? at]) : _now = at ?? DateTime.utc(2026);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Move time forward (events stamped after this see the new instant).
  void advance(Duration delta) => _now = _now.add(delta);
}

/// A deterministic, monotonically increasing id source: `id-0`, `id-1`, …
final class SeqIdGenerator implements IdGenerator {
  int _seq = 0;

  @override
  CommandId next() => CommandId('id-${_seq++}');
}

/// A repository that always fails — exercises the typed error channel.
final class FailingLedgerRepository implements LedgerRepository {
  const FailingLedgerRepository();

  @override
  TaskEither<LedgerError, IList<LedgerEvent>> load(AccountId id) =>
      TaskEither.left(const StorageFailure('load failed'));

  @override
  TaskEither<LedgerError, Unit> append(
          AccountId id, IList<LedgerEvent> events) =>
      TaskEither.left(const StorageFailure('append failed'));
}

/// Build a [LedgerEnv] for tests, defaulting every seam to a deterministic fake.
LedgerEnv testEnv({
  LedgerRepository? repo,
  Clock? clock,
  IdGenerator? ids,
}) =>
    (
      repo: repo ?? InMemoryLedgerRepository(),
      clock: clock ?? FixedClock(),
      ids: ids ?? SeqIdGenerator(),
    );

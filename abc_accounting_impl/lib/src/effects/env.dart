import 'package:fpdart/fpdart.dart';

import 'package:abc_accounting/abc_accounting.dart';
import 'clock.dart';
import 'id_generator.dart';
import 'repository.dart';

/// The dependencies the use-cases read from.
///
/// Demonstrated Dart feature: a **record** as the dependency environment — no
/// container class, no service locator, just a value passed in. "Dependencies
/// are data."
typedef LedgerEnv = ({LedgerRepository repo, Clock clock, IdGenerator ids});

/// The core effect type: an async, fallible computation that also reads its
/// dependencies from a [LedgerEnv].
///
/// `ReaderTaskEither` = Reader (inject env) + Task (async) + Either (typed
/// failure). A [LedgerEffect] is a *description*; nothing runs until `.run(env)`
/// is called — at `main`, or in a test against a fake env.
typedef LedgerEffect<A> = ReaderTaskEither<LedgerEnv, LedgerError, A>;

/// Constructs the default production [LedgerEnv] with an [InMemoryLedgerRepository],
/// [SystemClock], and [MonotonicIdGenerator].
LedgerEnv defaultEnv() {
  final clock = const SystemClock();
  return (
    repo: InMemoryLedgerRepository(),
    clock: clock,
    ids: MonotonicIdGenerator(clock),
  );
}

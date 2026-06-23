import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fpdart/fpdart.dart';

import 'package:abc_accounting/abc_accounting.dart';

/// Function-type aliases for the two canonical roles of an event-sourced core.
///
/// Demonstrated Dart feature: **`typedef`** over function types — naming the
/// shapes "evolve" and "decide" so signatures elsewhere read as intent, and so
/// alternative strategies can be passed as plain values (see `LedgerReducer` and
/// `deciderAt`).

/// Evolve: fold one event into the state. Total and synchronous.
typedef Reducer<S, E> = S Function(S state, E event);

/// Decide: validate a command against the current state, yielding either a
/// typed error or the events to append. Pure; fail-fast.
typedef Decider<S, C, E> = Either<LedgerError, IList<E>> Function(
  S state,
  C command,
);

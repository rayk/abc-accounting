import 'package:fpdart/fpdart.dart';

import 'package:abc_accounting/abc_accounting.dart';
import 'typedefs.dart';

/// Evolve the state by one event. **Pure, total, synchronous** — the heart of
/// the read-model, and the most heavily tested function in the codebase.
///
/// The `switch` is exhaustive over the sealed [LedgerEvent]: adding a new event
/// variant turns this into a compile error until it is handled. There is no
/// `default` clause, on purpose.
AccountState applyEvent(AccountState state, LedgerEvent event) =>
    switch (event) {
      Deposited(:final amount) => state.copyWith(
          balance: state.balance + amount,
          version: state.version.next,
        ),
      Withdrawn(:final amount) => state.copyWith(
          balance: state.balance - amount,
          withdrawnToday: state.withdrawnToday + amount,
          version: state.version.next,
        ),
      LimitSet(:final dailyLimit) => state.copyWith(
          dailyLimit: Option.of(dailyLimit),
          version: state.version.next,
        ),
      Frozen() => state.copyWith(
          status: AccountStatus.frozen,
          version: state.version.next,
        ),
      Closed() => state.copyWith(
          status: AccountStatus.closed,
          version: state.version.next,
        ),
    };

/// Rebuild state from an [initial] seed and a sequence of events — a left fold
/// using [applyEvent]. `replay(initial, events) == events.fold(initial, applyEvent)`.
AccountState replay(AccountState initial, Iterable<LedgerEvent> events) =>
    events.fold(initial, applyEvent);

/// Project the balance out of the state. A trivial pure read.
Money balanceOf(AccountState state) => state.balance;

/// The evolver as a **callable object** — a value that is also a function.
///
/// Demonstrated Dart feature: a class with a `call` method, which tears off to
/// satisfy the [Reducer] function type ([ledgerReducer] below). Useful when a
/// strategy needs both identity (it can be compared, stored, swapped) and
/// call-site ergonomics.
final class LedgerReducer {
  const LedgerReducer();

  AccountState call(AccountState state, LedgerEvent event) =>
      applyEvent(state, event);
}

/// The [LedgerReducer] tear-off, typed as a [Reducer]. Demonstrates a callable
/// object standing in for a function-typed value.
final Reducer<AccountState, LedgerEvent> ledgerReducer =
    const LedgerReducer().call;

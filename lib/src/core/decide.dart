import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fpdart/fpdart.dart';

import '../domain/commands.dart';
import '../contract/contract.dart';
import 'typedefs.dart';

/// Decide which events (if any) a command produces. **Pure, total, synchronous.**
///
/// Returns `Left` with a typed [LedgerError] when the command is rejected, or
/// `Right` with the events to append. A `Right` of the *empty* list is how
/// idempotent no-ops are expressed: a command that would not change the
/// observable state emits nothing, so re-applying it leaves state (and
/// [Version]) identical. Money movements always emit, so they advance the
/// version on every call — that is the idempotent/non-idempotent distinction,
/// decided here.
///
/// [now] and [cause] are supplied by the caller (from the injected `Clock` and
/// the command's idempotency key), keeping this function free of ambient effects.
Either<LedgerError, IList<LedgerEvent>> decide(
  AccountState state,
  LedgerCommand command,
  DateTime now,
  Option<CommandId> cause,
) {
  IList<LedgerEvent> emit(LedgerEvent event) => IList([event]);
  final noChange = <LedgerEvent>[].lock;

  switch (command) {
    case Deposit(:final amount):
      if (!state.status.canTransact) {
        return Either.left(AccountNotActive(state.status));
      }
      if (!amount.isPositive) {
        return Either.left(AmountMustBePositive(amount));
      }
      return Either.of(emit(Deposited(amount: amount, at: now, cause: cause)));

    case Withdraw(:final amount):
      if (!state.status.canTransact) {
        return Either.left(AccountNotActive(state.status));
      }
      if (!amount.isPositive) {
        return Either.left(AmountMustBePositive(amount));
      }
      if (amount > state.balance) {
        return Either.left(
          InsufficientFunds(balance: state.balance, requested: amount),
        );
      }
      final overLimit = state.dailyLimit.match(
        () => false,
        (limit) => (state.withdrawnToday + amount) > limit,
      );
      if (overLimit) {
        final limit = state.dailyLimit.getOrElse(() => Money.zero);
        return Either.left(
          DailyLimitExceeded(
            limit: limit,
            attempted: state.withdrawnToday + amount,
          ),
        );
      }
      return Either.of(emit(Withdrawn(amount: amount, at: now, cause: cause)));

    case SetDailyLimit(:final limit):
      if (state.status == AccountStatus.closed) {
        return Either.left(AccountNotActive(state.status));
      }
      // Idempotent: setting the limit it already has changes nothing.
      final unchanged = state.dailyLimit == Option.of(limit);
      if (unchanged) return Either.of(noChange);
      return Either.of(
          emit(LimitSet(dailyLimit: limit, at: now, cause: cause)));

    case Freeze():
      // Idempotent: freezing a frozen (or terminal closed) account is a no-op.
      if (state.status != AccountStatus.open) return Either.of(noChange);
      return Either.of(emit(Frozen(at: now, cause: cause)));

    case Close():
      // Idempotent: closing a closed account is a no-op.
      if (state.status == AccountStatus.closed) return Either.of(noChange);
      return Either.of(emit(Closed(at: now, cause: cause)));
  }
}

/// Adapt [decide] to the [Decider] typedef by fixing [now] and [cause].
///
/// Demonstrated technique: **currying** a multi-argument pure function down to
/// the canonical two-argument strategy shape, so it can be passed as a value.
Decider<AccountState, LedgerCommand, LedgerEvent> deciderAt(
  DateTime now,
  Option<CommandId> cause,
) =>
    (state, command) => decide(state, command, now, cause);

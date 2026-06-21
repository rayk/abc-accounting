import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fpdart/fpdart.dart';

import '../core/decide.dart';
import '../core/evolve.dart';
import '../domain/commands.dart';
import '../contract/contract.dart';
import 'env.dart';

/// Load and rebuild the current state for [id]. **Idempotent, async.**
LedgerEffect<AccountState> currentState(AccountId id) =>
    ReaderTaskEither.ask<LedgerEnv, LedgerError>()
        .flatMapTaskEither((env) => env.repo.load(id))
        .map((events) => replay(AccountState.empty(id), events));

/// Apply a command end-to-end: load → check idempotency → decide → persist →
/// evolve. The single async use-case every public operation funnels through.
///
/// Idempotency is enforced here: if the command carries a key that already
/// appears as an event `cause` in the log, this is a replay — return the current
/// state and append nothing. Otherwise the command's effects are decided
/// (fail-fast `Either`), persisted, and folded into the new state.
///
/// Composed entirely from existing pieces (`load`, `decide`, `append`, `replay`)
/// — the building block extension Vector 2 reuses to compose new use-cases.
LedgerEffect<AccountState> handle(AccountId id, LedgerCommand command) =>
    ReaderTaskEither.ask<LedgerEnv, LedgerError>().flatMap(
      (env) => ReaderTaskEither<LedgerEnv, LedgerError,
              IList<LedgerEvent>>.fromTaskEither(env.repo.load(id))
          .flatMap((events) {
        final state = replay(AccountState.empty(id), events);

        final alreadyApplied = command.idempotencyKey.match(
          () => false,
          (key) => events.any((e) => e.cause == Option.of(key)),
        );
        if (alreadyApplied) {
          return ReaderTaskEither<LedgerEnv, LedgerError, AccountState>.of(
              state);
        }

        final now = env.clock.now();
        final cause = Option.of(
          command.idempotencyKey.getOrElse(() => env.ids.next()),
        );

        return ReaderTaskEither<LedgerEnv, LedgerError,
                    IList<LedgerEvent>>.fromEither(
                decide(state, command, now, cause))
            .flatMap(
          (newEvents) => newEvents.isEmpty
              ? ReaderTaskEither<LedgerEnv, LedgerError, AccountState>.of(state)
              : ReaderTaskEither<LedgerEnv, LedgerError, Unit>.fromTaskEither(
                  env.repo.append(id, newEvents),
                ).map((_) => replay(state, newEvents)),
        );
      }),
    );

// ── Convenience wrappers ─────────────────────────────────────────────────────
// Thin, named use-cases. Each is `handle` applied to a specific command — a
// first taste of composition (a new signature delivered by reusing `handle`).

/// Add money. Non-idempotent unless [key] is supplied.
LedgerEffect<AccountState> deposit(
  AccountId id,
  Money amount, {
  Option<CommandId> key = const None(),
}) =>
    handle(id, Deposit(amount, idempotencyKey: key));

/// Remove money. Non-idempotent unless [key] is supplied.
LedgerEffect<AccountState> withdraw(
  AccountId id,
  Money amount, {
  Option<CommandId> key = const None(),
}) =>
    handle(id, Withdraw(amount, idempotencyKey: key));

/// Set the daily limit. Idempotent.
LedgerEffect<AccountState> setDailyLimit(
  AccountId id,
  Money limit, {
  Option<CommandId> key = const None(),
}) =>
    handle(id, SetDailyLimit(limit, idempotencyKey: key));

/// Freeze the account. Idempotent.
LedgerEffect<AccountState> freeze(
  AccountId id, {
  Option<CommandId> key = const None(),
}) =>
    handle(id, Freeze(idempotencyKey: key));

/// Close the account. Idempotent.
LedgerEffect<AccountState> close(
  AccountId id, {
  Option<CommandId> key = const None(),
}) =>
    handle(id, Close(idempotencyKey: key));

import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:abc_accounting/abc_accounting.dart';

/// A minimal, in-memory **reference implementation** of [Ledger].
///
/// Simple and obviously correct — its job is to make the conformance suite go
/// **green during contracting** (proving the spec is executable and
/// self-consistent) and to serve as the behavioral yardstick any real
/// implementation must match. It carries none of the event-sourcing / fpdart /
/// Riverpod machinery a production implementation might use; it just holds the
/// current [AccountState] and replaces it.
final class ReferenceLedger extends Ledger {
  ReferenceLedger._(this._state) : super(token: Ledger.token);

  /// A [LedgerFactory] over the reference implementation.
  static Future<Ledger> open(AccountId id) async =>
      ReferenceLedger._(AccountState.empty(id));

  AccountState _state;
  final StreamController<AccountState> _changes =
      StreamController<AccountState>.broadcast();
  final Set<String> _seenKeys = {};

  @override
  AccountId get id => _state.id;

  @override
  AccountState get state => _state;

  @override
  Stream<AccountState> get changes => _changes.stream;

  /// Apply one step: dedupe by key, run the pure decision, and on success commit
  /// the new state (emitting only when it actually changed).
  LedgerResult _apply(
    Option<CommandId> key,
    Either<LedgerError, AccountState> Function(AccountState) step,
  ) async {
    final isReplay = key.match(() => false, (k) => _seenKeys.contains(k.value));
    if (isReplay) return Either.of(_state); // idempotent: no-op replay

    return step(_state).map((next) {
      if (next != _state) {
        _state = next;
        _changes.add(next);
      }
      key.match(() {}, (k) => _seenKeys.add(k.value));
      return next;
    });
  }

  @override
  LedgerResult deposit(Money amount,
          {Option<CommandId> idempotencyKey = const None()}) =>
      _apply(idempotencyKey, (s) {
        if (!s.status.canTransact)
          return Either.left(AccountNotActive(s.status));
        if (!amount.isPositive)
          return Either.left(AmountMustBePositive(amount));
        return Either.of(
          s.copyWith(balance: s.balance + amount, version: s.version.next),
        );
      });

  @override
  LedgerResult withdraw(Money amount,
          {Option<CommandId> idempotencyKey = const None()}) =>
      _apply(idempotencyKey, (s) {
        if (!s.status.canTransact)
          return Either.left(AccountNotActive(s.status));
        if (!amount.isPositive)
          return Either.left(AmountMustBePositive(amount));
        if (amount > s.balance) {
          return Either.left(
            InsufficientFunds(balance: s.balance, requested: amount),
          );
        }
        final projected = s.withdrawnToday + amount;
        final overLimit =
            s.dailyLimit.match(() => false, (limit) => projected > limit);
        if (overLimit) {
          return Either.left(
            DailyLimitExceeded(
              limit: s.dailyLimit.getOrElse(() => Money.zero),
              attempted: projected,
            ),
          );
        }
        return Either.of(s.copyWith(
          balance: s.balance - amount,
          withdrawnToday: projected,
          version: s.version.next,
        ));
      });

  @override
  LedgerResult setDailyLimit(Money limit) => _apply(const None(), (s) {
        if (s.status == AccountStatus.closed) {
          return Either.left(AccountNotActive(s.status));
        }
        if (s.dailyLimit == Option.of(limit)) return Either.of(s); // no-op
        return Either.of(
          s.copyWith(dailyLimit: Option.of(limit), version: s.version.next),
        );
      });

  @override
  LedgerResult freeze() => _apply(const None(), (s) {
        if (s.status != AccountStatus.open) return Either.of(s); // no-op
        return Either.of(
          s.copyWith(status: AccountStatus.frozen, version: s.version.next),
        );
      });

  @override
  LedgerResult closeAccount() => _apply(const None(), (s) {
        if (s.status == AccountStatus.closed) return Either.of(s); // no-op
        return Either.of(
          s.copyWith(status: AccountStatus.closed, version: s.version.next),
        );
      });

  @override
  Future<void> dispose() => _changes.close();
}

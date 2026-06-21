import 'package:fpdart/fpdart.dart';

import 'ids.dart';
import 'status.dart';
import 'value.dart';

/// The current, immutable read-model of an account — a left fold over its events.
///
/// Demonstrated Dart feature: a **`final class`** value object (immutable,
/// closed to subclassing) with a `copyWith` for non-destructive updates and an
/// [Option] field instead of a nullable. Never mutated; evolving the state
/// produces a new instance (see `core/evolve.dart`).
final class AccountState with Value {
  const AccountState({
    required this.id,
    required this.status,
    required this.balance,
    required this.dailyLimit,
    required this.withdrawnToday,
    required this.version,
  });

  /// The empty state an account starts from, before any event.
  factory AccountState.empty(AccountId id) => AccountState(
        id: id,
        status: AccountStatus.open,
        balance: Money.zero,
        dailyLimit: const None(),
        withdrawnToday: Money.zero,
        version: const Version(0),
      );

  final AccountId id;
  final AccountStatus status;
  final Money balance;

  /// The optional daily withdrawal limit — [None] means unlimited.
  final Option<Money> dailyLimit;

  /// How much has been withdrawn in the current day window.
  final Money withdrawnToday;

  /// Advances by one on every applied event; the optimistic-concurrency token.
  final Version version;

  AccountState copyWith({
    AccountStatus? status,
    Money? balance,
    Option<Money>? dailyLimit,
    Money? withdrawnToday,
    Version? version,
  }) =>
      AccountState(
        id: id,
        status: status ?? this.status,
        balance: balance ?? this.balance,
        dailyLimit: dailyLimit ?? this.dailyLimit,
        withdrawnToday: withdrawnToday ?? this.withdrawnToday,
        version: version ?? this.version,
      );

  @override
  List<Object?> get props => [
        id.value,
        status,
        balance.minorUnits,
        dailyLimit,
        withdrawnToday.minorUnits,
        version.value,
      ];
}

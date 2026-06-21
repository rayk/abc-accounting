import 'package:fpdart/fpdart.dart';

import 'ids.dart';
import 'value.dart';

/// Facts that have happened to an account — the source of truth.
///
/// Demonstrated Dart feature: a **`sealed` hierarchy of `final` classes**. The
/// base is closed (so folding over events is total and exhaustive); each leaf is
/// `final` (closed to further subclassing) and immutable.
///
/// Every event records when it happened ([at]) and, optionally, the [cause] —
/// the [CommandId] that produced it. The cause is what makes idempotency
/// first-class: replaying a command whose id already appears in the log is a
/// no-op (see `effects/use_cases.dart`).
sealed class LedgerEvent with Value {
  const LedgerEvent({required this.at, this.cause = const None()});

  /// When the event occurred (supplied by an injected `Clock`, never `now()`).
  final DateTime at;

  /// The command that caused this event, if it carried an idempotency key.
  final Option<CommandId> cause;

  /// Common identity fields shared by every event.
  List<Object?> get baseProps => [at, cause];
}

/// Money was added to the account.
final class Deposited extends LedgerEvent {
  const Deposited({required this.amount, required super.at, super.cause});
  final Money amount;

  @override
  List<Object?> get props => [amount.minorUnits, ...baseProps];
}

/// Money was removed from the account.
final class Withdrawn extends LedgerEvent {
  const Withdrawn({required this.amount, required super.at, super.cause});
  final Money amount;

  @override
  List<Object?> get props => [amount.minorUnits, ...baseProps];
}

/// The daily withdrawal limit was set to a new value.
final class LimitSet extends LedgerEvent {
  const LimitSet({required this.dailyLimit, required super.at, super.cause});
  final Money dailyLimit;

  @override
  List<Object?> get props => [dailyLimit.minorUnits, ...baseProps];
}

/// The account was frozen.
final class Frozen extends LedgerEvent {
  const Frozen({required super.at, super.cause});

  @override
  List<Object?> get props => baseProps;
}

/// The account was permanently closed.
final class Closed extends LedgerEvent {
  const Closed({required super.at, super.cause});

  @override
  List<Object?> get props => baseProps;
}

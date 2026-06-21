import 'package:fpdart/fpdart.dart';

import '../contract/contract.dart';

/// Requests to change an account — which may be accepted or rejected.
///
/// Demonstrated Dart feature: another **`sealed`** ADT, mirroring the events.
/// Every command may carry an optional [idempotencyKey]; when present, applying
/// the same command twice is a no-op (idempotent). When absent, each application
/// advances the account (non-idempotent) — the two behavioral axes in one type.
sealed class LedgerCommand with Value {
  const LedgerCommand({this.idempotencyKey = const None()});

  /// When present, makes this command idempotent: a re-submission with the same
  /// key after it has been applied does nothing.
  final Option<CommandId> idempotencyKey;

  List<Object?> get baseProps => [idempotencyKey];
}

/// Add [amount] to the account. **Non-idempotent** unless keyed.
final class Deposit extends LedgerCommand {
  const Deposit(this.amount, {super.idempotencyKey});
  final Money amount;

  @override
  List<Object?> get props => [amount.minorUnits, ...baseProps];
}

/// Remove [amount] from the account. **Non-idempotent** unless keyed.
final class Withdraw extends LedgerCommand {
  const Withdraw(this.amount, {super.idempotencyKey});
  final Money amount;

  @override
  List<Object?> get props => [amount.minorUnits, ...baseProps];
}

/// Set the daily withdrawal limit to [limit]. **Idempotent**: setting the same
/// limit again emits no event.
final class SetDailyLimit extends LedgerCommand {
  const SetDailyLimit(this.limit, {super.idempotencyKey});
  final Money limit;

  @override
  List<Object?> get props => [limit.minorUnits, ...baseProps];
}

/// Freeze the account. **Idempotent**: freezing a frozen account is a no-op.
final class Freeze extends LedgerCommand {
  const Freeze({super.idempotencyKey});

  @override
  List<Object?> get props => baseProps;
}

/// Close the account. **Idempotent**: closing a closed account is a no-op.
final class Close extends LedgerCommand {
  const Close({super.idempotencyKey});

  @override
  List<Object?> get props => baseProps;
}

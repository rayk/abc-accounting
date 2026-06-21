import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'ids.dart';
import 'status.dart';
import 'value.dart';

/// Every way an operation can fail, as data rather than exceptions.
///
/// Demonstrated Dart feature: a **`sealed class`** — a closed ADT. Because the
/// set of variants is fixed, a `switch` over a [LedgerError] is exhaustive and
/// adding a case later is a *compile error* until every handler is updated.
/// Errors are values carried by `Either`/`TaskEither`; nothing here is thrown.
sealed class LedgerError with Value {
  const LedgerError();

  /// A human-readable description (for logs and the example runner).
  String get message;

  @override
  List<Object?> get props => [message];
}

/// Tried to move more money than the account holds.
final class InsufficientFunds extends LedgerError {
  const InsufficientFunds({required this.balance, required this.requested});
  final Money balance;
  final Money requested;

  @override
  String get message => 'insufficient funds: balance ${balance.minorUnits}, '
      'requested ${requested.minorUnits}';

  @override
  List<Object?> get props => [balance.minorUnits, requested.minorUnits];
}

/// A command supplied a non-positive amount where a positive one is required.
final class AmountMustBePositive extends LedgerError {
  const AmountMustBePositive(this.amount);
  final Money amount;

  @override
  String get message => 'amount must be positive, was ${amount.minorUnits}';

  @override
  List<Object?> get props => [amount.minorUnits];
}

/// A withdrawal would breach the configured daily limit.
final class DailyLimitExceeded extends LedgerError {
  const DailyLimitExceeded({required this.limit, required this.attempted});
  final Money limit;
  final Money attempted;

  @override
  String get message => 'daily limit ${limit.minorUnits} exceeded by attempt '
      '${attempted.minorUnits}';

  @override
  List<Object?> get props => [limit.minorUnits, attempted.minorUnits];
}

/// Money movement was attempted while the account could not transact.
final class AccountNotActive extends LedgerError {
  const AccountNotActive(this.status);
  final AccountStatus status;

  @override
  String get message => 'account is not active (status: ${status.name})';

  @override
  List<Object?> get props => [status];
}

/// A failure originating from the persistence boundary.
///
/// The only error that maps a *thrown* `Object` (inside a repository
/// implementation) into the typed error channel.
final class StorageFailure extends LedgerError {
  const StorageFailure(this.detail);
  final String detail;

  @override
  String get message => 'storage failure: $detail';

  @override
  List<Object?> get props => [detail];
}

/// A required input field was empty (used by the accumulating validator).
final class EmptyField extends LedgerError {
  const EmptyField(this.field);
  final String field;

  @override
  String get message => 'field "$field" must not be empty';

  @override
  List<Object?> get props => [field];
}

/// A monetary input was negative where it must not be.
final class NegativeAmount extends LedgerError {
  const NegativeAmount({required this.field, required this.amount});
  final String field;
  final Money amount;

  @override
  String get message =>
      '"$field" must not be negative, was ${amount.minorUnits}';

  @override
  List<Object?> get props => [field, amount.minorUnits];
}

/// A limit input was not strictly positive.
final class NonPositiveLimit extends LedgerError {
  const NonPositiveLimit(this.amount);
  final Money amount;

  @override
  String get message => 'limit must be positive, was ${amount.minorUnits}';

  @override
  List<Object?> get props => [amount.minorUnits];
}

/// A non-empty list of errors that accumulates via [+].
///
/// fpdart 1.x ships no `Validation` type, so error *accumulation* (gather every
/// problem, don't fail fast) is expressed here as a [Semigroup]-carrying chain.
/// See `core/validation.dart` for the applicative validator that uses it, and
/// `core/algebra.dart` for the `Semigroup` instance.
final class NonEmptyChain<E> with Value {
  /// A chain of exactly one element.
  NonEmptyChain(this.head) : tail = IList<E>();

  /// A chain of a [head] followed by zero or more [tail] elements.
  NonEmptyChain.withTail(this.head, this.tail);

  final E head;
  final IList<E> tail;

  /// Every element, head first.
  IList<E> get all => IList([head, ...tail]);

  /// Concatenation — the [Semigroup] operation. Never empty by construction.
  NonEmptyChain<E> operator +(NonEmptyChain<E> other) =>
      NonEmptyChain.withTail(head, tail.addAll(other.all));

  @override
  List<Object?> get props => [head, ...tail];
}

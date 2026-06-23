import 'package:fpdart/fpdart.dart';

// ── Value mixin ──────────────────────────────────────────────────────────────

/// Structural value-equality, expressed once.
///
/// Mixed into every immutable domain type so that two values are equal iff
/// their [props] are equal — no hand-written `==`/`hashCode` per class, no code
/// generation, no dependency. This is the elegant, DRY alternative to repeating
/// equality boilerplate (or pulling in `equatable`) across a dozen value types.
///
/// Demonstrated Dart feature: a **mixin** used as a reusable capability.
mixin Value {
  /// The fields that define this value's identity, in a stable order.
  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Value &&
          runtimeType == other.runtimeType &&
          _propsEqual(props, other.props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(props));

  @override
  String toString() => '$runtimeType${props}';
}

bool _propsEqual(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ── Extension types (zero-cost newtypes) ────────────────────────────────────

/// Zero-cost newtypes for the domain's primitive values.
///
/// Demonstrated Dart feature: **`extension type`** — a compile-time wrapper that
/// erases to its representation at runtime (an [AccountId] *is* a `String`, a
/// [Money] *is* an `int`), giving type safety with no allocation. Equality and
/// hashing come from the representation, so these are value types for free.
///
/// This is the "parse, don't validate" toolkit: once you hold a [Money] you can
/// no longer accidentally add it to an unrelated `int`.

/// Identifies an account. Wraps a `String` at zero runtime cost.
extension type const AccountId(String value) {}

/// Correlates a command for idempotency/audit. Wraps a `String`.
extension type const CommandId(String value) {}

/// A monotonically increasing aggregate version. Wraps an `int`.
///
/// Carries its own successor, so callers never do raw arithmetic on versions.
extension type const Version(int value) {
  /// The next version after this one.
  Version get next => Version(value + 1);

  bool operator <(Version other) => value < other.value;
  bool operator >(Version other) => value > other.value;
}

/// Money as an integer number of minor units (e.g. cents).
///
/// Integer minor units avoid floating-point rounding entirely. [Money] forms a
/// commutative monoid under addition with [zero] as identity (see
/// `core/algebra.dart`), which is what lets balances be `fold`ed.
extension type const Money(int minorUnits) {
  /// The additive identity — an empty sum of money.
  static const Money zero = Money(0);

  Money operator +(Money other) => Money(minorUnits + other.minorUnits);
  Money operator -(Money other) => Money(minorUnits - other.minorUnits);

  bool operator <(Money other) => minorUnits < other.minorUnits;
  bool operator <=(Money other) => minorUnits <= other.minorUnits;
  bool operator >(Money other) => minorUnits > other.minorUnits;
  bool operator >=(Money other) => minorUnits >= other.minorUnits;

  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;
  bool get isZero => minorUnits == 0;
}

// ── AccountStatus enum ───────────────────────────────────────────────────────

/// The lifecycle state of an account.
///
/// Demonstrated Dart feature: an **enhanced `enum`** — a closed set of constants
/// that also carries data ([canTransact]) and a `const` constructor. Exhaustive
/// `switch` over it is checked by the compiler.
enum AccountStatus {
  /// Accepts deposits and withdrawals.
  open(canTransact: true),

  /// Temporarily blocked; rejects money movement but can be reopened.
  frozen(canTransact: false),

  /// Permanently closed; a terminal state.
  closed(canTransact: false);

  const AccountStatus({required this.canTransact});

  /// Whether money may move while in this status.
  final bool canTransact;
}

// ── LedgerError sealed hierarchy ─────────────────────────────────────────────

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

// ── LedgerEvent sealed hierarchy ─────────────────────────────────────────────

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

// ── AccountState ─────────────────────────────────────────────────────────────

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

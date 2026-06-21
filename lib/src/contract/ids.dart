/// Zero-cost newtypes for the domain's primitive values.
///
/// Demonstrated Dart feature: **`extension type`** — a compile-time wrapper that
/// erases to its representation at runtime (an [AccountId] *is* a `String`, a
/// [Money] *is* an `int`), giving type safety with no allocation. Equality and
/// hashing come from the representation, so these are value types for free.
///
/// This is the "parse, don't validate" toolkit: once you hold a [Money] you can
/// no longer accidentally add it to an unrelated `int`.
library;

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

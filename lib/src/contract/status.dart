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

import 'dart:async';

import 'package:fpdart/fpdart.dart';

import 'errors.dart';
import 'ids.dart';
import 'state.dart';

/// The outcome of an operation: asynchronous, and either the new [AccountState]
/// or a typed [LedgerError]. Never throws for an expected failure.
typedef LedgerResult = Future<Either<LedgerError, AccountState>>;

/// The seam for obtaining a [Ledger] — the system under test. Conformance specs
/// depend on this, never on a concrete implementation.
typedef LedgerFactory = Future<Ledger> Function(AccountId id);

/// The account operation contract — a **token-guarded base class** in the style
/// of Flutter's `PlatformInterface` (federated plugins).
///
/// Implementations must **`extend Ledger`** and pass [Ledger.token] to the
/// constructor; a class that merely `implements Ledger` cannot obtain the token
/// and fails [verify]. The pay-off: every member has a default body that throws
/// `UnimplementedError`, so a method added here later does **not** break existing
/// implementations — they inherit the new default until they override it. It also
/// means the "stub" is intrinsic: a subclass that overrides nothing *is* the
/// unimplemented ledger.
abstract class Ledger {
  Ledger({required Object token}) {
    _tokens[this] = token;
  }

  static final Expando<Object> _tokens = Expando<Object>('Ledger.token');
  static final Object _token = Object();

  /// The shared token a concrete [Ledger] must pass to its `super` constructor.
  static Object get token => _token;

  /// Throws unless [instance] was constructed by `extend`ing [Ledger] with the
  /// shared [token]. A class that only `implements Ledger` never ran the
  /// constructor, so it recorded no token and fails here. The conformance harness
  /// calls this for every system under test.
  static void verify(Ledger instance) {
    if (!identical(_tokens[instance], _token)) {
      throw AssertionError(
        'A Ledger must `extend Ledger` and pass `Ledger.token`; '
        '${instance.runtimeType} did not — implementing the interface directly '
        'is unsupported, so members added later get a default body instead of '
        'breaking implementations.',
      );
    }
  }

  /// The account this ledger operates on.
  AccountId get id => throw UnimplementedError();

  /// A synchronous snapshot of the current state.
  AccountState get state => throw UnimplementedError();

  /// A change-feed: the new state after each successful, state-changing operation.
  Stream<AccountState> get changes => throw UnimplementedError();

  /// Add money. Non-idempotent unless an [idempotencyKey] is given.
  LedgerResult deposit(Money amount,
          {Option<CommandId> idempotencyKey = const None()}) =>
      throw UnimplementedError();

  /// Remove money. Non-idempotent unless an [idempotencyKey] is given.
  LedgerResult withdraw(Money amount,
          {Option<CommandId> idempotencyKey = const None()}) =>
      throw UnimplementedError();

  /// Set the daily withdrawal limit. Idempotent.
  LedgerResult setDailyLimit(Money limit) => throw UnimplementedError();

  /// Freeze the account, blocking money movement. Idempotent.
  LedgerResult freeze() => throw UnimplementedError();

  /// Permanently close the account. Idempotent; terminal.
  LedgerResult closeAccount() => throw UnimplementedError();

  /// Release resources.
  Future<void> dispose() => throw UnimplementedError();
}

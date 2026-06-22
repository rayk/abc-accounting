/// `package:checks` matchers for the [Ledger] boundary — the per-boundary
/// matcher layer the EAC authoring pattern prescribes.
///
/// `package:bnd_eac/matchers.dart` deliberately ships only the reusable
/// [unwrapLeft] / [unwrapRight] atoms, **not** a generic
/// `Subject<Either<L, R>>` extension: a multi-parameter generic extension
/// silently degrades to `Subject<dynamic>` when a call site doesn't pin its
/// type arguments, which makes checks pass falsely — the deadliest bug in a
/// steering framework. So the atoms are bound here at the concrete
/// [LedgerResult] payload type ([Either]<[LedgerError], [AccountState]>).
library;

import 'package:abc_accounting/abc_accounting_contract.dart';
import 'package:bnd_eac/matchers.dart';
import 'package:checks/checks.dart';
import 'package:checks/context.dart';
import 'package:fpdart/fpdart.dart';

/// Either-branch accessors on a settled [LedgerResult] value.
///
/// Reads as `check(await ledger.deposit(...)).success.balance.equals(...)`
/// or `check(result).failure.isA<InsufficientFunds>()`.
extension LedgerResultChecks on Subject<Either<LedgerError, AccountState>> {
  /// Narrows to the success branch, rejecting a [LedgerError] (`Left`).
  Subject<AccountState> get success => context.nest<AccountState>(
        () => ['completes with an AccountState (Right)'],
        unwrapRight,
      );

  /// Narrows to the failure branch, rejecting an [AccountState] (`Right`).
  Subject<LedgerError> get failure => context.nest<LedgerError>(
        () => ['completes with a LedgerError (Left)'],
        unwrapLeft,
      );
}

/// Field accessors on an [AccountState] subject, so a contract check reads
/// as `check(result).success.balance.equals(Money(500))`.
extension AccountStateChecks on Subject<AccountState> {
  /// The current balance.
  Subject<Money> get balance => has((s) => s.balance, 'balance');

  /// The optimistic-concurrency [Version].
  Subject<Version> get version => has((s) => s.version, 'version');

  /// The lifecycle [AccountStatus].
  Subject<AccountStatus> get status => has((s) => s.status, 'status');
}

/// Account-opening and deposit signature contract for the bnd_eac engine.
///
/// **Phase 1 → Phase 2 upgrade.** The original shadow-scaffold used a
/// top-level function tear-off (`openAccount`) to work around `dart:mirrors`
/// not being able to reflect instance methods directly. This revision uses the
/// richer `Contract.abstractMethod<T>(Symbol, …)` API, which reflects
/// `Ledger.deposit` directly from the abstract class declaration — no
/// top-level scaffold required for instance methods.
///
/// The top-level `openAccount` scaffold is retained for the factory shape
/// (`LedgerFactory`) because that operation still requires a concrete
/// function tear-off (a typedef, not an instance method, cannot use
/// `abstractMethod`).
///
/// See the friction report in the accompanying test for details.
library;

import 'package:abc_accounting/abc_accounting.dart' as abc;
import 'package:bnd_eac/contract.dart';
import 'package:checks/checks.dart';

import 'ledger_types.dart';

/// Top-level scaffold mirroring `LedgerFactory`.
///
/// `dart:mirrors` reflects this function's name and parameter list so the
/// engine can render `openAccount(AccountId id) → Future<Ledger>` in the
/// contract brief. The function body is unreachable; it exists solely as a
/// mirror token.
///
/// **Why not use `LedgerFactory` directly?**
/// `LedgerFactory` is a `typedef` — a type alias, not a named function.
/// There is no tear-off syntax for a typedef; you can only tear off
/// *values* (instances or top-level/static functions). The engine has no
/// API to register a typedef shape without a concrete function to reflect.
Future<abc.Ledger> openAccount(abc.AccountId id) =>
    throw UnimplementedError('boundary scaffold — reflected, never called');

/// Intrinsic invariant: a settled successful deposit leaves balance ≥ zero.
///
/// This is input-independent — true of ANY valid result regardless of the
/// deposit amount. It does NOT assert `balance == old + amount`; that is an
/// input-relative postcondition reserved for Phase 3 `ensures(old())`.
final balanceNonNeg = Rule<abc.AccountState>(
  id: 'balance-nonneg',
  text: 'A settled deposit leaves balance ≥ zero',
  condition: (s) => s
      .has(
        (state) => state.balance.minorUnits,
        'balance.minorUnits',
      )
      .isGreaterOrEqual(0),
);

/// Failure mode: deposit amount not positive → `AmountMustBePositive`.
const depositAmountMustBePositive = FailureMode<abc.AmountMustBePositive>(
  when: 'the deposit amount is not positive (zero or negative)',
  steer: 'return Left(AmountMustBePositive(amount)); leave state unchanged',
);

/// Contract declaring the account-opening factory and deposit method for the
/// abc_accounting Ledger boundary.
///
/// Depends on [ledgerTypeContract] for the shared vocabulary types.
/// Contains:
/// - [openAccount] signature: the factory shape via top-level scaffold.
/// - `Ledger.deposit` signature: via `abstractMethod<Ledger>(#deposit)`,
///   carrying [balanceNonNeg] as an intrinsic invariant and
///   [depositAmountMustBePositive] as a declared failure mode.
final accountOpeningContract =
    Contract(
        name: 'account_opening',
        version: const ContractVersion(0, 1, 0),
        purpose:
            'Account creation and deposit: obtain a new Ledger via '
            'LedgerFactory, then deposit money returning '
            'Either<LedgerError, AccountState>.',
        tags: {'ledger', 'factory', 'deposit'},
        dependsOn: {ledgerTypeContract},
      )
      ..signature(
        openAccount,
        purpose:
            'Opens a new ledger account identified by AccountId. '
            'Mirrors LedgerFactory = Future<Ledger> Function(AccountId id).',
      )
      ..abstractMethod<abc.Ledger>(
        #deposit,
        purpose:
            'Adds money to the account. Returns Right(AccountState) on '
            'success; returns Left(LedgerError) on a domain violation — '
            'never throws for expected failures.',
        invariants: [balanceNonNeg],
        failures: [depositAmountMustBePositive],
        parameterOverrides: {
          'amount': 'Money',
          'idempotencyKey': 'Option<CommandId>',
        },
        importable: 'package:abc_accounting/src/contract/ledger.dart',
      );

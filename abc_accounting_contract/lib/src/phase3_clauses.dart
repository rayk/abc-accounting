/// Phase-3 contract declarations for Ledger.deposit:
/// [Precondition], [Postcondition], and [Effect] clauses.
///
/// Exports [phase3DepositContract] — a [Contract] that attaches the three
/// Phase-3 clause types to the deposit boundary so that the accompanying
/// test can prove:
/// 1. They are stored at [SignatureDecl.requires], [SignatureDecl.ensures],
///    and [SignatureDecl.effects].
/// 2. The runner evaluates Postconditions and returns PostconditionFailed
///    when a broken SUT violates them.
/// 3. The runner returns GuardMissing when a broken SUT ignores a
///    Precondition guard and accepts out-of-domain input.
///
/// The postconditions here are contract-level invariants (general form).
/// Per-case postconditions that close over a specific deposit amount live in
/// the test file rather than here.
library;

import 'package:abc_accounting/abc_accounting.dart' as abc;
import 'package:bnd_eac/contract.dart';

import 'ledger_types.dart';

// ── Private clause declarations ──────────────────────────────────────────────
// No dartdoc required — private symbols.

/// [Precondition] requiring the deposit amount to be positive.
///
/// The runner surfaces a GuardMissing outcome when the act returns a settled
/// Right on an amount that fails this predicate.
final _amountPositivePrecondition = Precondition(
  id: 'amount-positive',
  text: 'amount must be positive',
  holds: (args) => (args as abc.Money).isPositive,
);

/// [Postcondition] asserting the balance is strictly higher after a deposit.
///
/// This is the contract-level invariant form: "balance increases". Per-case
/// exact-delta assertions (`after.balance == before.balance + amount`) live
/// in the test cases that close over the specific amount.
final _balanceIncreasesPostcondition = Postcondition(
  id: 'balance-increased-by-amount',
  text:
      'balance after a successful deposit is strictly greater than before '
      '(exact delta asserted per-case via case-level postconditions)',
  holds: (old, result) {
    final before = old! as abc.AccountState;
    final after = result! as abc.AccountState;
    return after.balance.minorUnits > before.balance.minorUnits;
  },
);

/// [Postcondition] asserting the version increments by exactly 1.
final _versionIncrementedPostcondition = Postcondition(
  id: 'version-incremented',
  text: 'version increments by exactly 1 after a successful deposit',
  holds: (old, result) {
    final before = old! as abc.AccountState;
    final after = result! as abc.AccountState;
    return after.version == abc.Version(before.version.value + 1);
  },
);

// ── Public contract ──────────────────────────────────────────────────────────

/// Contract proving Phase-3 clause types on [abc.Ledger].
///
/// Attaches [Precondition], [Postcondition], and [Effect] to the deposit
/// signature declaration to prove they are stored and tagged correctly,
/// and that the runner evaluates them at execution time.
///
/// Depends on [ledgerTypeContract] for the shared vocabulary.
///
/// Paired with the test at
/// `test/phase3_clauses_eac_test.dart`.
final phase3DepositContract =
    Contract(
      name: 'phase3_deposit_clauses',
      version: const ContractVersion(0, 3, 0),
      purpose: 'Phase 3 proof: requires / ensures / effects on Ledger.deposit.',
      tags: {'ledger', 'deposit', 'phase3'},
      dependsOn: {ledgerTypeContract},
    )..abstractMethod<abc.Ledger>(
      #deposit,
      purpose:
          'Adds money; guards amount > 0; increments version on success; '
          'persists and emits AccountState.',
      parameterOverrides: {
        'amount': 'Money',
        'idempotencyKey': 'Option<CommandId>',
      },
      importable: 'package:abc_accounting/src/contract/ledger.dart',
      requires: [_amountPositivePrecondition],
      ensures: [
        _balanceIncreasesPostcondition,
        _versionIncrementedPostcondition,
      ],
      effects: [persist('AccountState'), emit('AccountState')],
    );

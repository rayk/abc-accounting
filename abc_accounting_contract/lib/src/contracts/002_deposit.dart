/// Deposit contract (`002`) and its executable cases.
///
/// The richest behaviour in the kit. Declares `Ledger.deposit` via
/// `abstractMethod<Ledger>(#deposit)` carrying the full clause family:
/// - an intrinsic invariant ([balanceNonNeg]);
/// - a declared failure mode ([depositAmountMustBePositive]);
/// - a `requires` precondition (amount > 0);
/// - two `ensures` postconditions (balance increases, version increments);
/// - declared `effects` (persist + emit AccountState);
/// - the temporal clause family (timing / lifecycle / concurrency /
///   compensation) — inert metadata describing the async semantics.
///
/// Cases cover the happy path plus the `AmountMustBePositive` and
/// `AccountNotActive` (frozen) rejections.
// ignore_for_file: avoid_catching_errors
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '000_types.dart';
import 'conformance_support.dart';

/// Intrinsic invariant: a settled successful deposit leaves balance ≥ zero.
///
/// Input-independent — true of ANY valid result regardless of the deposit
/// amount. It does NOT assert `balance == old + amount`; that input-relative
/// fact is an `ensures` postcondition (below).
final balanceNonNeg = Rule<AccountState>(
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
const depositAmountMustBePositive = FailureMode<AmountMustBePositive>(
  when: 'the deposit amount is not positive (zero or negative)',
  steer: 'return Left(AmountMustBePositive(amount)); leave state unchanged',
);

/// Precondition requiring the deposit amount to be positive.
///
/// The runner surfaces a GuardMissing outcome when an act returns a settled
/// Right on an amount that fails this predicate.
final _amountPositivePrecondition = Precondition(
  id: 'amount-positive',
  text: 'amount must be positive',
  holds: (args) => (args as Money).isPositive,
);

/// Postcondition: balance is strictly higher after a successful deposit.
///
/// The contract-level (general) form. Per-case exact-delta assertions
/// (`after.balance == before.balance + amount`) live in the test cases that
/// close over the specific amount.
final _balanceIncreasesPostcondition = Postcondition(
  id: 'balance-increased-by-amount',
  text:
      'balance after a successful deposit is strictly greater than before '
      '(exact delta asserted per-case via case-level postconditions)',
  holds: (old, result) {
    final before = old! as AccountState;
    final after = result! as AccountState;
    return after.balance.minorUnits > before.balance.minorUnits;
  },
);

/// Postcondition: version increments by exactly 1 after a successful deposit.
final _versionIncrementedPostcondition = Postcondition(
  id: 'version-incremented',
  text: 'version increments by exactly 1 after a successful deposit',
  holds: (old, result) {
    final before = old! as AccountState;
    final after = result! as AccountState;
    return after.version == Version(before.version.value + 1);
  },
);

/// Contract declaring `Ledger.deposit` with its full clause family.
///
/// Depends on [ledgerTypeContract] for the shared vocabulary types.
final depositContract =
    Contract(
      name: 'deposit',
      version: const ContractVersion(0, 1, 0),
      purpose:
          'Adds money to the account. Returns Right(AccountState) on success; '
          'returns Left(LedgerError) on a domain violation — never throws for '
          'expected failures. Guards amount > 0; increments version on '
          'success; persists and emits AccountState.',
      tags: {'ledger', 'deposit'},
      dependsOn: {ledgerTypeContract},
    )..abstractMethod<Ledger>(
      #deposit,
      purpose:
          'Adds money; guards amount > 0; increments version on success; '
          'persists and emits AccountState.',
      invariants: [balanceNonNeg],
      failures: [depositAmountMustBePositive],
      requires: [_amountPositivePrecondition],
      ensures: [
        _balanceIncreasesPostcondition,
        _versionIncrementedPostcondition,
      ],
      effects: [persist('AccountState'), emit('AccountState')],
      parameterOverrides: {
        'amount': 'Money',
        'idempotencyKey': 'Option<CommandId>',
      },
      importable: 'package:abc_accounting/src/contract/ledger.dart',
      timing: const Timing(
        within: Duration(seconds: 5),
        elseFailure: 'TimeoutFailure',
        settles: Duration(seconds: 10),
        retry: RetryPolicy(max: 3, on: 'StorageFailure'),
      ),
      lifecycle: const Lifecycle(
        states: ['pending', 'settled', 'failed'],
        pending: 'no mutation while in-flight',
        onFailure: 'state unchanged',
      ),
      concurrency: const Concurrency(
        idempotentBy: 'idempotencyKey',
        atomic: true,
        atMostOnce: 'AccountState',
      ),
      compensation: revert('AccountState'),
    );

/// Registers the `deposit` conformance cases against [factory].
void depositCases(LedgerFactory factory) {
  group('deposit', () {
    test(
      'happy: deposit Money(100) on fresh account returns Right',
      tags: {'contract-ledger', 'sig-deposit', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-dep-h'));
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'deposit Money(100) on fresh account',
            given: 'a fresh ledger; deposit amount = Money(100)',
            when: () => sut.deposit(const Money(100)),
            then: succeeds<LedgerEither, AccountState>([
              Rule<AccountState>(
                id: 'balance-100',
                text: 'balance equals the deposit amount',
                condition: (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(100),
              ),
              Rule<AccountState>(
                id: 'version-advanced',
                text: 'version advances from 0 to 1 after the deposit',
                condition: (s) =>
                    s.has((a) => a.version.value, 'version.value').equals(1),
              ),
            ]),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: zero amount returns Left(AmountMustBePositive)',
      tags: {'contract-ledger', 'sig-deposit', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-dep-z'));
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'deposit Money(0) rejected',
            given: 'a fresh ledger; deposit amount = Money(0)',
            when: () => sut.deposit(Money.zero),
            then: rejects<LedgerEither, AmountMustBePositive>(
              const FailureMode<AmountMustBePositive>(
                when: 'amount is zero — not positive',
                steer:
                    'return Left(AmountMustBePositive(amount)); '
                    'leave state unchanged',
              ),
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: negative amount returns Left(AmountMustBePositive)',
      tags: {'contract-ledger', 'sig-deposit', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-dep-n'));
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'deposit Money(-5) rejected',
            given: 'a fresh ledger; deposit amount = Money(-5)',
            when: () => sut.deposit(const Money(-5)),
            then: rejects<LedgerEither, AmountMustBePositive>(
              const FailureMode<AmountMustBePositive>(
                when: 'amount is negative — not positive',
                steer: 'return Left(AmountMustBePositive(amount))',
              ),
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: frozen account returns Left(AccountNotActive)',
      tags: {'contract-ledger', 'sig-deposit', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-dep-fr'));
        // Setup: freeze the account first. If the seam is not yet implemented,
        // freeze() throws; swallowed so evaluateCase below surfaces the
        // SeamThrew for the deposit call.
        try {
          await sut.freeze();
        } on UnimplementedError {
          // Stub: freeze not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'deposit on frozen account',
            given: 'a frozen ledger; deposit amount = Money(50)',
            when: () => sut.deposit(const Money(50)),
            then: rejects<LedgerEither, AccountNotActive>(
              const FailureMode<AccountNotActive>(
                when: 'account status is frozen — canTransact is false',
                steer:
                    'return Left(AccountNotActive(status)); '
                    'leave state unchanged',
              ),
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

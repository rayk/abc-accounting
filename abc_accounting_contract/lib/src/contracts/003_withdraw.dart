/// Withdraw contract (`003`) and its executable cases.
///
/// Declares `Ledger.withdraw` and proves the happy path plus the
/// `InsufficientFunds` and `AmountMustBePositive` rejections. The daily-limit
/// rejection lives with the limit contract (`004_set_daily_limit.dart`).
// ignore_for_file: avoid_catching_errors
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '000_types.dart';
import 'conformance_support.dart';

/// Failure mode: withdrawal exceeds the current balance → `InsufficientFunds`.
const withdrawInsufficientFunds = FailureMode<InsufficientFunds>(
  when: 'the withdrawal amount exceeds the current balance',
  steer: 'return Left(InsufficientFunds(balance, requested)); '
      'leave state unchanged',
);

/// Failure mode: withdrawal amount not positive → `AmountMustBePositive`.
const withdrawAmountMustBePositive = FailureMode<AmountMustBePositive>(
  when: 'the withdrawal amount is not positive (zero or negative)',
  steer: 'return Left(AmountMustBePositive(amount)); leave state unchanged',
);

/// Contract declaring `Ledger.withdraw`.
///
/// Depends on [ledgerTypeContract] for the shared vocabulary types.
final withdrawContract =
    Contract(
      name: 'withdraw',
      version: const ContractVersion(0, 1, 0),
      purpose:
          'Removes money from the account. Returns Right(AccountState) on '
          'success; rejects with InsufficientFunds when the balance is too '
          'low and AmountMustBePositive when the amount is non-positive.',
      tags: {'ledger', 'withdraw'},
      dependsOn: {ledgerTypeContract},
    )..abstractMethod<Ledger>(
      #withdraw,
      purpose:
          'Removes money; guards amount > 0 and balance sufficiency; '
          'increments version on success.',
      failures: [withdrawInsufficientFunds, withdrawAmountMustBePositive],
      parameterOverrides: {
        'amount': 'Money',
        'idempotencyKey': 'Option<CommandId>',
      },
      importable: 'package:abc_accounting/src/contract/ledger.dart',
    );

/// Registers the `withdraw` conformance cases against [factory].
void withdrawCases(LedgerFactory factory) {
  group('withdraw', () {
    test(
      'happy: withdraw within balance returns Right',
      tags: {'contract-ledger', 'sig-withdraw', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-wdh'));
        // Setup: fund the account.
        try {
          await sut.deposit(const Money(1000));
        } on UnimplementedError {
          // Stub: deposit not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'withdraw Money(200) from funded account',
            given: 'ledger with balance 1000; withdraw = Money(200)',
            when: () => sut.withdraw(const Money(200)),
            then: succeeds<LedgerEither, AccountState>([
              Rule<AccountState>(
                id: 'balance-800',
                text: 'balance equals 1000 - 200 = 800',
                condition: (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(800),
              ),
            ]),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: overdraw returns Left(InsufficientFunds)',
      tags: {'contract-ledger', 'sig-withdraw', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-wdi'));
        // Setup: fund with 100.
        try {
          await sut.deposit(const Money(100));
        } on UnimplementedError {
          // Stub: deposit not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'withdraw Money(500) with balance 100',
            given: 'ledger with balance 100; withdraw = Money(500)',
            when: () => sut.withdraw(const Money(500)),
            then: rejects<LedgerEither, InsufficientFunds>(
              withdrawInsufficientFunds,
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: zero amount returns Left(AmountMustBePositive)',
      tags: {'contract-ledger', 'sig-withdraw', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-wdz'));
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'withdraw Money(0) rejected',
            given: 'a fresh ledger; withdraw amount = Money(0)',
            when: () => sut.withdraw(Money.zero),
            then: rejects<LedgerEither, AmountMustBePositive>(
              withdrawAmountMustBePositive,
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: negative amount returns Left(AmountMustBePositive)',
      tags: {'contract-ledger', 'sig-withdraw', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-wdn'));
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'withdraw Money(-5) rejected',
            given: 'a fresh ledger; withdraw amount = Money(-5)',
            when: () => sut.withdraw(const Money(-5)),
            then: rejects<LedgerEither, AmountMustBePositive>(
              withdrawAmountMustBePositive,
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

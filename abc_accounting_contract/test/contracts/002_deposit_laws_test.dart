/// Property law + negative-case table for the deposit boundary.
///
/// **Law.** A restricted generator yields strictly-positive `Money`; the law
/// asserts that depositing any such amount into a fresh ledger settles
/// `balance == amount`. Holds across the explored domain (no counterexample).
///
/// **Negative-case table.** `parameterizedTest` enumerates the non-positive
/// deposit amounts; each row expects an `AmountMustBePositive` rejection
/// (a `CasePassed` from `rejects(...)`).
@TestOn('vm')
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:fpdart/fpdart.dart';
import 'package:parameterized_test/parameterized_test.dart';
import 'package:test/test.dart';

typedef _R = Either<LedgerError, AccountState>;

void main() {
  group('law', () {
    testLaw<Money, _R>(
      Law<Money, _R>(
        description: 'depositing any positive Money settles balance == amount',
        // Restricted generator: always strictly positive (no assume()).
        generator: (r, size) => Money(r.nextInt(size) + 1),
        caseFor: (amount) => Case<_R>(
          description: 'deposit ${amount.minorUnits}',
          given: 'a fresh ReferenceLedger; amount = ${amount.minorUnits} (> 0)',
          when: () async {
            final ledger = await ReferenceLedger.open(const AccountId('law'));
            final result = await ledger.deposit(amount);
            await ledger.dispose();
            return result;
          },
          then: succeeds<_R, AccountState>([
            Rule<AccountState>(
              id: 'balance-eq-amount',
              text: 'balance == amount',
              condition: (s) => s
                  .has((a) => a.balance.minorUnits, 'balance.minorUnits')
                  .equals(amount.minorUnits),
            ),
          ]),
        ),
        shrinker: (m) => [
          if (m.minorUnits > 1) Money(m.minorUnits ~/ 2),
          if (m.minorUnits > 1) Money(m.minorUnits - 1),
        ],
      ),
      numRuns: 50,
    );
  });

  parameterizedTest(
    'deposit rejects non-positive amounts (AmountMustBePositive)',
    [
      [0],
      [-5],
      [-100],
    ],
    (int minorUnits) async {
      final ledger = await ReferenceLedger.open(const AccountId('neg-table'));
      final outcome = await evaluateCase(
        Case<_R>(
          description: 'deposit $minorUnits',
          given: 'amount = $minorUnits (not positive)',
          when: () => ledger.deposit(Money(minorUnits)),
          then: rejects<_R, AmountMustBePositive>(
            const FailureMode<AmountMustBePositive>(
              when: 'the amount is not positive',
              steer: 'return Left(AmountMustBePositive(amount))',
            ),
          ),
        ),
      );
      await ledger.dispose();
      // The declared rejection IS the expected behaviour → CasePassed.
      check(outcome).isA<CasePassed>();
    },
  );
}

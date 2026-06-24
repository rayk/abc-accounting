/// Set-daily-limit contract (`004`) and its executable cases.
///
/// Declares `Ledger.setDailyLimit` and proves: the limit is stored; a
/// withdrawal within the limit succeeds; and a withdrawal that would breach
/// the limit is rejected with `DailyLimitExceeded`.
// ignore_for_file: avoid_catching_errors
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '000_types.dart';
import 'conformance_support.dart';

/// Failure mode: a withdrawal would breach the configured daily limit.
const dailyLimitExceeded = FailureMode<DailyLimitExceeded>(
  when: 'the withdrawal would exceed the configured daily limit',
  steer: 'return Left(DailyLimitExceeded(limit, attempted)); '
      'leave state unchanged',
);

/// Contract declaring `Ledger.setDailyLimit`.
///
/// Depends on [ledgerTypeContract] for the shared vocabulary types.
final setDailyLimitContract =
    Contract(
      name: 'set_daily_limit',
      version: const ContractVersion(0, 1, 0),
      purpose:
          'Sets the daily withdrawal limit. Idempotent: setting the same '
          'limit twice emits nothing. A later withdrawal exceeding the limit '
          'is rejected with DailyLimitExceeded.',
      tags: {'ledger', 'set_daily_limit'},
      dependsOn: {ledgerTypeContract},
    )..abstractMethod<Ledger>(
      #setDailyLimit,
      purpose: 'Stores the daily withdrawal limit; increments version when '
          'the value changes.',
      failures: [dailyLimitExceeded],
      parameterOverrides: {'limit': 'Money'},
      importable: 'package:abc_accounting/src/contract/ledger.dart',
    );

/// Registers the `setDailyLimit` conformance cases against [factory].
void setDailyLimitCases(LedgerFactory factory) {
  group('setDailyLimit', () {
    test(
      'happy: setDailyLimit returns Right',
      tags: {'contract-ledger', 'sig-setDailyLimit', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-sdl-h'));
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'setDailyLimit Money(500) on fresh account',
            given: 'a fresh ledger; limit = Money(500)',
            when: () => sut.setDailyLimit(const Money(500)),
            then: succeeds<LedgerEither, AccountState>([
              Rule<AccountState>(
                id: 'daily-limit-stored',
                text: 'the daily limit is stored as Money(500)',
                condition: (s) => s
                    .has(
                      (a) => a.dailyLimit.toNullable()?.minorUnits ?? -1,
                      'dailyLimit.minorUnits',
                    )
                    .equals(500),
              ),
            ]),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'happy: withdrawal within the daily limit succeeds',
      tags: {'contract-ledger', 'sig-setDailyLimit', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-dl-within'));
        // Setup: fund 1000, set a daily limit of 100.
        try {
          await sut.deposit(const Money(1000));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        try {
          await sut.setDailyLimit(const Money(100));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'withdraw Money(80) within daily limit Money(100)',
            given: 'balance 1000, daily limit 100; withdraw = Money(80)',
            when: () => sut.withdraw(const Money(80)),
            then: succeeds<LedgerEither, AccountState>([
              Rule<AccountState>(
                id: 'within-limit-balance',
                text: 'balance is 1000 - 80 = 920 after the withdrawal',
                condition: (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(920),
              ),
            ]),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: withdraw over daily limit returns Left(DailyLimitExceeded)',
      tags: {'contract-ledger', 'sig-setDailyLimit', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-dle'));
        // Setup: fund and set a daily limit of Money(100).
        try {
          await sut.deposit(const Money(1000));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        try {
          await sut.setDailyLimit(const Money(100));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'withdraw Money(500) exceeds daily limit Money(100)',
            given: 'balance 1000, daily limit 100; withdraw = Money(500)',
            when: () => sut.withdraw(const Money(500)),
            then: rejects<LedgerEither, DailyLimitExceeded>(dailyLimitExceeded),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

/// Close-account contract (`006`) and its executable cases.
///
/// Declares `Ledger.closeAccount` and proves it is terminal (status becomes
/// closed) and that a closed account blocks both deposit and withdraw with
/// `AccountNotActive`.
// ignore_for_file: avoid_catching_errors
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '000_types.dart';
import 'conformance_support.dart';

/// Failure mode: money movement attempted while the account is closed.
const closedBlocksTransacting = FailureMode<AccountNotActive>(
  when: 'the account is closed — canTransact is false',
  steer: 'return Left(AccountNotActive(status)); leave state unchanged',
);

/// Contract declaring `Ledger.closeAccount`.
///
/// Depends on [ledgerTypeContract] for the shared vocabulary types.
final closeContract =
    Contract(
      name: 'close',
      version: const ContractVersion(0, 1, 0),
      purpose:
          'Permanently closes the account. Idempotent and terminal: once '
          'closed, deposit and withdraw are rejected with AccountNotActive.',
      tags: {'ledger', 'close'},
      dependsOn: {ledgerTypeContract},
    )..abstractMethod<Ledger>(
      #closeAccount,
      purpose: 'Transitions the account to closed; terminal and idempotent.',
      failures: [closedBlocksTransacting],
      importable: 'package:abc_accounting/src/contract/ledger.dart',
    );

/// Registers the `closeAccount` conformance cases against [factory].
void closeCases(LedgerFactory factory) {
  group('closeAccount', () {
    test(
      'terminal: closeAccount sets status to closed',
      tags: {'contract-ledger', 'sig-closeAccount', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-ca-t'));
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'closeAccount on open account returns Right(closed)',
            given: 'a fresh open ledger',
            when: sut.closeAccount,
            then: succeeds<LedgerEither, AccountState>([
              Rule<AccountState>(
                id: 'status-closed',
                text: 'status is closed after closeAccount',
                condition: (s) => s
                    .has((a) => a.status, 'status')
                    .equals(AccountStatus.closed),
              ),
            ]),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: closed account blocks deposit with AccountNotActive',
      tags: {'contract-ledger', 'sig-closeAccount', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-ca-bd'));
        // Setup: close the account.
        try {
          await sut.closeAccount();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'deposit on closed account is rejected',
            given: 'a closed ledger; deposit amount = Money(10)',
            when: () => sut.deposit(const Money(10)),
            then: rejects<LedgerEither, AccountNotActive>(
              closedBlocksTransacting,
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: closed account blocks withdraw with AccountNotActive',
      tags: {'contract-ledger', 'sig-closeAccount', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-ca-bw'));
        // Setup: close the account.
        try {
          await sut.closeAccount();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'withdraw on closed account is rejected',
            given: 'a closed ledger; withdraw amount = Money(10)',
            when: () => sut.withdraw(const Money(10)),
            then: rejects<LedgerEither, AccountNotActive>(
              closedBlocksTransacting,
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

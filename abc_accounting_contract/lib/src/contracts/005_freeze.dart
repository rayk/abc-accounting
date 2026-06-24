/// Freeze contract (`005`) and its executable cases.
///
/// Declares `Ledger.freeze` and proves it is idempotent (a second freeze
/// leaves the account frozen) and that a frozen account blocks both deposit
/// and withdraw with `AccountNotActive`.
// ignore_for_file: avoid_catching_errors
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '000_types.dart';
import 'conformance_support.dart';

/// Failure mode: money movement attempted while the account is frozen.
const frozenBlocksTransacting = FailureMode<AccountNotActive>(
  when: 'the account is frozen — canTransact is false',
  steer: 'return Left(AccountNotActive(status)); leave state unchanged',
);

/// Contract declaring `Ledger.freeze`.
///
/// Depends on [ledgerTypeContract] for the shared vocabulary types.
final freezeContract =
    Contract(
      name: 'freeze',
      version: const ContractVersion(0, 1, 0),
      purpose:
          'Freezes the account, blocking money movement. Idempotent: '
          'freezing a frozen account is a no-op. While frozen, deposit and '
          'withdraw are rejected with AccountNotActive.',
      tags: {'ledger', 'freeze'},
      dependsOn: {ledgerTypeContract},
    )..abstractMethod<Ledger>(
      #freeze,
      purpose: 'Transitions an open account to frozen; idempotent thereafter.',
      failures: [frozenBlocksTransacting],
      importable: 'package:abc_accounting/src/contract/ledger.dart',
    );

/// Registers the `freeze` conformance cases against [factory].
void freezeCases(LedgerFactory factory) {
  group('freeze', () {
    test(
      'idempotent: calling freeze twice leaves account frozen',
      tags: {'contract-ledger', 'sig-freeze', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-fr-id'));
        // First freeze (setup).
        try {
          await sut.freeze();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        // Second freeze: evaluateCase asserts it still returns Right.
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'second freeze on frozen account is idempotent',
            given: 'an already-frozen ledger',
            when: sut.freeze,
            then: succeeds<LedgerEither, AccountState>([
              Rule<AccountState>(
                id: 'still-frozen',
                text: 'status remains frozen after second freeze',
                condition: (s) => s
                    .has((a) => a.status, 'status')
                    .equals(AccountStatus.frozen),
              ),
            ]),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: frozen account blocks deposit with AccountNotActive',
      tags: {'contract-ledger', 'sig-freeze', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-fr-bl'));
        // Setup: freeze the account.
        try {
          await sut.freeze();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'deposit on frozen account is rejected',
            given: 'a frozen ledger; deposit amount = Money(50)',
            when: () => sut.deposit(const Money(50)),
            then: rejects<LedgerEither, AccountNotActive>(
              frozenBlocksTransacting,
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: frozen account blocks withdraw with AccountNotActive',
      tags: {'contract-ledger', 'sig-freeze', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-fr-wd'));
        // Setup: fund, then freeze.
        try {
          await sut.deposit(const Money(100));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        try {
          await sut.freeze();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'withdraw on frozen account is rejected',
            given: 'a frozen ledger with balance 100; withdraw = Money(50)',
            when: () => sut.withdraw(const Money(50)),
            then: rejects<LedgerEither, AccountNotActive>(
              frozenBlocksTransacting,
            ),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

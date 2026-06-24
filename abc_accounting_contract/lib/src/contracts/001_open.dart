/// Account-opening contract (`001`) and its executable cases.
///
/// Declares the factory shape (`openAccount`) and proves that a freshly opened
/// ledger starts at [AccountState.empty]: status open, balance zero, version 0.
///
/// The top-level [openAccount] scaffold exists solely as a mirror token:
/// `LedgerFactory` is a `typedef`, and a typedef has no tear-off, so the engine
/// needs a concrete function to reflect the openAccount factory shape. Its body
/// is never called.
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

import '000_types.dart';
import 'conformance_support.dart';

/// Mirror scaffold for `LedgerFactory = Future<Ledger> Function(AccountId id)`.
///
/// `dart:mirrors` reflects this function's name and parameter list so the
/// engine can render `openAccount(AccountId id) → Future<Ledger>`. The body is
/// unreachable; it exists only as a reflectable token.
Future<Ledger> openAccount(AccountId id) =>
    throw UnimplementedError('boundary scaffold — reflected, never called');

/// Contract declaring the account-opening factory for the Ledger boundary.
///
/// Depends on [ledgerTypeContract] for the shared vocabulary types.
final openContract =
    Contract(
        name: 'open',
        version: const ContractVersion(0, 1, 0),
        purpose:
            'Open a new Ledger account: obtain a fresh Ledger via '
            'LedgerFactory whose initial state is AccountState.empty(id).',
        tags: {'ledger', 'factory', 'open'},
        dependsOn: {ledgerTypeContract},
      )
      ..signature(
        openAccount,
        purpose:
            'Opens a new ledger account identified by AccountId. '
            'Mirrors LedgerFactory = Future<Ledger> Function(AccountId id).',
      );

/// Registers the `open` conformance cases against [factory].
void openCases(LedgerFactory factory) {
  group('open', () {
    test(
      'initial state matches AccountState.empty',
      tags: {'contract-ledger', 'sig-open', 'kind-positive'},
      () async {
        const id = AccountId('eac-open');
        final sut = await factory(id);
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'open: fresh ledger has empty initial state',
            given: 'factory(AccountId("eac-open")) creates a fresh ledger',
            when: () async => Either<LedgerError, AccountState>.of(sut.state),
            then: succeeds<LedgerEither, AccountState>([
              Rule<AccountState>(
                id: 'open-status',
                text: 'status is open',
                condition: (s) =>
                    s.has((a) => a.status, 'status').equals(AccountStatus.open),
              ),
              Rule<AccountState>(
                id: 'open-balance',
                text: 'balance is zero',
                condition: (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(0),
              ),
              Rule<AccountState>(
                id: 'open-version',
                text: 'version is 0',
                condition: (s) =>
                    s.has((a) => a.version.value, 'version.value').equals(0),
              ),
            ]),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

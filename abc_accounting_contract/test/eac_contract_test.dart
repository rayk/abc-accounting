/// Smoke-tests for the eac-style contracts in lib/src/eac/.
///
/// Verifies that:
/// 1. [checkContractDrift] passes for the real contracts.
/// 2. A bogus typeOverrides key throws [StateError] at the [Contract.type]
///    cascade — validate-on-add means the throw happens at construction,
///    not deferred to a separate checkContractDrift() call.
/// 3. Mirror reflection delivers expected importable URIs and
///    rendered signature strings (observability probe for the report).
///
/// Requires the Dart VM (dart:mirrors).
@TestOn('vm')
library;

import 'package:abc_accounting/abc_accounting.dart' as abc;
import 'package:abc_accounting_contract/src/eac/account_opening.dart';
import 'package:abc_accounting_contract/src/eac/ledger_types.dart';
import 'package:bnd_eac/contract.dart';
import 'package:test/test.dart';

void main() {
  // ── Drift guard — real contracts ───────────────────────────────────────────

  group('ledgerTypeContract', () {
    test('checkContractDrift passes for the real contract', () {
      expect(() => checkContractDrift(ledgerTypeContract), returnsNormally);
    });

    // DRIFT GUARD PROBE — proves the guard is live on a real fixture type.
    // AccountState is a final class; mirrors CAN reflect it, so a stale key
    // MUST cause a StateError at the ..type<>() cascade (validate-on-add).
    // (Extension types like Money are skipped because reflectedFieldNames
    // returns null for them.)
    test(
      'stale typeOverrides key throws StateError at ..type() cascade',
      () {
        expect(
          () =>
              Contract(
                name: 'bogus_drift_probe',
                version: const ContractVersion(0, 0, 1),
                purpose: 'Drift guard probe — not a real contract.',
              )..type<abc.AccountState>(
                describe: 'Probe',
                typeOverrides: {'nonExistentBogusField': 'String'},
              ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('accountOpeningContract', () {
    test('checkContractDrift passes for the real contract', () {
      expect(
        () => checkContractDrift(accountOpeningContract),
        returnsNormally,
      );
    });
  });

  // ── Mirror observability — importable URI and signature rendering ──────────

  group('eac mirror observability', () {
    test(
      'AccountStatus importable resolves to a package: URI',
      () {
        final decl = ledgerTypeContract.types.firstWhere(
          (t) => t.type == abc.AccountStatus,
        );
        // AccountStatus is a plain enum; mirrors resolve it correctly.
        printOnFailure('AccountStatus importable: ${decl.importable}');
        expect(decl.importable, startsWith('package:'));
      },
    );

    test(
      'Money importable is the unresolved sentinel (extension-type erasure)',
      () {
        final decl = ledgerTypeContract.types.firstWhere(
          (t) => t.type == abc.Money,
        );
        // Money erases to int at runtime; deriveLibraryUriForType returns
        // the sentinel for dart: core types.
        printOnFailure('Money importable: ${decl.importable}');
        expect(
          decl.importable,
          equals(unresolvedImportable),
        );
      },
    );

    test(
      'AccountState importable resolves to a package: URI',
      () {
        final decl = ledgerTypeContract.types.firstWhere(
          (t) => t.type == abc.AccountState,
        );
        // AccountState is a final class; mirrors resolve it correctly.
        printOnFailure('AccountState importable: ${decl.importable}');
        expect(decl.importable, startsWith('package:'));
      },
    );

    test(
      'openAccount scaffold produces a named, reflected SignatureDecl',
      () {
        final sigs = accountOpeningContract.signatures;
        // Phase 2: accountOpeningContract now carries two signatures:
        //   [0] openAccount (factory scaffold)
        //   [1] deposit (abstractMethod<Ledger>(#deposit))
        expect(sigs, hasLength(2));
        final sig = sigs.first;
        printOnFailure('SignatureDecl.name:     ${sig.name}');
        printOnFailure('SignatureDecl.function: ${sig.function}');
        printOnFailure('SignatureDecl.importable: ${sig.importable}');
        expect(sig.name, equals('openAccount'));
        // Mirrors render the AccountId parameter; extension-type erasure
        // will erase it to String in the rendered signature string.
        expect(sig.function, contains('openAccount'));
        expect(sig.importable, startsWith('package:'));
      },
    );

    test(
      'Money TypeDecl.isResolved is false (extension type)',
      () {
        final decl = ledgerTypeContract.types.firstWhere(
          (t) => t.type == abc.Money,
        );
        expect(decl.isResolved, isFalse);
      },
    );

    test(
      'AccountStatus TypeDecl.isResolved is true (plain enum)',
      () {
        final decl = ledgerTypeContract.types.firstWhere(
          (t) => t.type == abc.AccountStatus,
        );
        expect(decl.isResolved, isTrue);
      },
    );
  });
}

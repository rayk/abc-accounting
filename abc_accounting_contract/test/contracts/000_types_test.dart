/// Type-vocabulary drift guard + mirror observability for `ledgerTypeContract`.
///
/// Verifies that [checkContractDrift] passes for the real type contract, that a
/// bogus `typeOverrides` key throws [StateError] at the `..type()` cascade
/// (validate-on-add), and that mirror reflection delivers the expected
/// importable URIs and `isResolved` flags (extension types erase; plain enums
/// and final classes resolve).
///
/// Requires the Dart VM (`dart:mirrors`).
@TestOn('vm')
library;

import 'package:abc_accounting/abc_accounting.dart' as abc;
import 'package:abc_accounting_contract/src/contracts/000_types.dart';
import 'package:bnd_eac/contract.dart';
import 'package:test/test.dart';

void main() {
  group('ledgerTypeContract drift', () {
    test('checkContractDrift passes for the real contract', () {
      expect(() => checkContractDrift(ledgerTypeContract), returnsNormally);
    });

    // DRIFT GUARD PROBE — proves the guard is live on a real fixture type.
    // AccountState is a final class; mirrors CAN reflect it, so a stale key
    // MUST cause a StateError at the ..type<>() cascade (validate-on-add).
    test('stale typeOverrides key throws StateError at ..type() cascade', () {
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
    });
  });

  group('mirror observability', () {
    test('AccountStatus importable resolves to a package: URI', () {
      final decl = ledgerTypeContract.types.firstWhere(
        (t) => t.type == abc.AccountStatus,
      );
      printOnFailure('AccountStatus importable: ${decl.importable}');
      expect(decl.importable, startsWith('package:'));
    });

    test('Money importable is the unresolved sentinel (extension-type erasure)',
        () {
      final decl = ledgerTypeContract.types.firstWhere(
        (t) => t.type == abc.Money,
      );
      printOnFailure('Money importable: ${decl.importable}');
      expect(decl.importable, equals(unresolvedImportable));
    });

    test('AccountState importable resolves to a package: URI', () {
      final decl = ledgerTypeContract.types.firstWhere(
        (t) => t.type == abc.AccountState,
      );
      printOnFailure('AccountState importable: ${decl.importable}');
      expect(decl.importable, startsWith('package:'));
    });

    test('Money TypeDecl.isResolved is false (extension type)', () {
      final decl = ledgerTypeContract.types.firstWhere(
        (t) => t.type == abc.Money,
      );
      expect(decl.isResolved, isFalse);
    });

    test('AccountStatus TypeDecl.isResolved is true (plain enum)', () {
      final decl = ledgerTypeContract.types.firstWhere(
        (t) => t.type == abc.AccountStatus,
      );
      expect(decl.isResolved, isTrue);
    });
  });
}

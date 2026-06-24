/// Drift guard + mirror observability for the `open` contract.
///
/// Proves [checkContractDrift] passes for `openContract` and that the
/// `openAccount` factory scaffold reflects into a named [SignatureDecl] with a
/// `package:` importable. (Extension-type erasure means the `AccountId`
/// parameter renders as `String` in the signature string — expected.)
@TestOn('vm')
library;

import 'package:abc_accounting_contract/src/contracts/001_open.dart';
import 'package:bnd_eac/contract.dart';
import 'package:test/test.dart';

void main() {
  group('openContract', () {
    test('checkContractDrift passes for the real contract', () {
      expect(() => checkContractDrift(openContract), returnsNormally);
    });

    test('declares a single signature: openAccount', () {
      expect(openContract.signatures, hasLength(1));
    });

    test('openAccount scaffold produces a named, reflected SignatureDecl', () {
      final sig = openContract.signatures.single;
      printOnFailure('SignatureDecl.name:       ${sig.name}');
      printOnFailure('SignatureDecl.function:   ${sig.function}');
      printOnFailure('SignatureDecl.importable: ${sig.importable}');
      expect(sig.name, equals('openAccount'));
      expect(sig.function, contains('openAccount'));
      expect(sig.importable, startsWith('package:'));
    });
  });
}

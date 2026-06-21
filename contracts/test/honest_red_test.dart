import 'package:test/test.dart';

// The kit's barrel re-exports abc_accounting, so this single import brings in
// both the Ledger contract surface and UnimplementedLedger.
import 'package:contracts_for_abc_accounting/contracts_for_abc_accounting.dart';

/// The "honest red" invariant.
///
/// The pre-implementation conformance run is only meaningful if the stub is
/// *genuinely* unimplemented — every contract member must throw
/// `UnimplementedError`. If someone accidentally gave a member a real body (or
/// the token-guard defaults stopped throwing), the `pending` spec could go green
/// for the wrong reason and the red phase would be a lie. This meta-test pins it:
/// a bare [UnimplementedLedger] (which overrides nothing) throws for *every*
/// member of the [Ledger] surface.
void main() {
  group('UnimplementedLedger is honestly red', () {
    late UnimplementedLedger ledger;
    setUp(() => ledger = UnimplementedLedger());

    test('it still passes the token guard (it does `extend Ledger`)', () {
      expect(() => Ledger.verify(ledger), returnsNormally);
    });

    test('every accessor throws UnimplementedError', () {
      expect(() => ledger.id, throwsUnimplementedError);
      expect(() => ledger.state, throwsUnimplementedError);
      expect(() => ledger.changes, throwsUnimplementedError);
    });

    test('every command throws UnimplementedError', () {
      expect(() => ledger.deposit(const Money(1)), throwsUnimplementedError);
      expect(() => ledger.withdraw(const Money(1)), throwsUnimplementedError);
      expect(
          () => ledger.setDailyLimit(const Money(1)), throwsUnimplementedError);
      expect(() => ledger.freeze(), throwsUnimplementedError);
      expect(() => ledger.closeAccount(), throwsUnimplementedError);
      expect(() => ledger.dispose(), throwsUnimplementedError);
    });
  });
}

import 'package:abc_accounting/abc_accounting_internals.dart';
import 'package:test/test.dart';

/// The accumulating validator must gather *every* problem, unlike fail-fast
/// `Either`.
void main() {
  List<LedgerError> errorsOf(Validated<Object?> v) =>
      v.match((chain) => chain.all.toList(), (_) => <LedgerError>[]);

  group('validateOpening', () {
    test('all valid → Right with parsed params', () {
      final result = validateOpening(
        id: 'acc-1',
        openingBalanceMinorUnits: 100,
        dailyLimitMinorUnits: 50,
      );
      result.match(
        (_) => fail('expected Right'),
        (params) {
          expect(params.id, const AccountId('acc-1'));
          expect(params.openingBalance, const Money(100));
          expect(params.dailyLimit, const Money(50));
        },
      );
    });

    test('all invalid → Left accumulating all three errors', () {
      final result = validateOpening(
        id: '   ',
        openingBalanceMinorUnits: -5,
        dailyLimitMinorUnits: 0,
      );
      final errors = errorsOf(result);
      expect(errors, hasLength(3));
      expect(errors.map((e) => e.runtimeType), [
        EmptyField,
        NegativeAmount,
        NonPositiveLimit,
      ]);
    });

    test('one invalid → Left with just that error', () {
      final result = validateOpening(
        id: 'ok',
        openingBalanceMinorUnits: -1,
        dailyLimitMinorUnits: 10,
      );
      final errors = errorsOf(result);
      expect(errors, hasLength(1));
      expect(errors.single, isA<NegativeAmount>());
    });

    test(
        'a negative daily limit is rejected (a limit must be > 0, not just ≠ 0)',
        () {
      final result = validateOpening(
        id: 'ok',
        openingBalanceMinorUnits: 0,
        dailyLimitMinorUnits: -5,
      );
      final errors = errorsOf(result);
      expect(errors, hasLength(1));
      expect(errors.single, isA<NonPositiveLimit>());
    });
  });
}

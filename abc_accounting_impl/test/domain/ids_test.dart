import 'package:abc_accounting/abc_accounting.dart';
import 'package:test/test.dart';

/// Direct coverage for the [Money] and [Version] newtype operators. These are
/// public API, so each operator and boundary is pinned here rather than only
/// exercised indirectly — which also kills the arithmetic/comparison mutants.
void main() {
  group('Money arithmetic', () {
    test('addition', () {
      expect(const Money(100) + const Money(50), const Money(150));
    });
    test('subtraction', () {
      expect(const Money(100) - const Money(30), const Money(70));
    });
  });

  group('Money comparisons (boundaries distinguish < from <=, > from >=)', () {
    test('less-than', () {
      expect(const Money(10) < const Money(20), isTrue);
      expect(const Money(10) < const Money(10), isFalse);
    });
    test('less-or-equal', () {
      expect(const Money(10) <= const Money(10), isTrue);
      expect(const Money(11) <= const Money(10), isFalse);
    });
    test('greater-than', () {
      expect(const Money(20) > const Money(10), isTrue);
      expect(const Money(10) > const Money(10), isFalse);
    });
    test('greater-or-equal', () {
      expect(const Money(10) >= const Money(10), isTrue);
      expect(const Money(9) >= const Money(10), isFalse);
    });
  });

  group('Money sign predicates (boundary at zero)', () {
    test('isPositive', () {
      expect(const Money(1).isPositive, isTrue);
      expect(Money.zero.isPositive, isFalse);
    });
    test('isNegative', () {
      expect(const Money(-1).isNegative, isTrue);
      expect(Money.zero.isNegative, isFalse);
    });
    test('isZero', () {
      expect(Money.zero.isZero, isTrue);
      expect(const Money(1).isZero, isFalse);
    });
  });

  group('Version', () {
    test('next increments by exactly one', () {
      expect(const Version(0).next, const Version(1));
      expect(const Version(41).next, const Version(42));
    });
    test('comparisons', () {
      expect(const Version(1) < const Version(2), isTrue);
      expect(const Version(2) < const Version(1), isFalse);
      expect(const Version(2) > const Version(1), isTrue);
      expect(const Version(1) > const Version(2), isFalse);
    });
  });
}

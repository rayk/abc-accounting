import 'package:glados/glados.dart';
import 'package:abc_accounting_impl/abc_accounting_impl_internals.dart';

import '../support/generators.dart';

/// Property-based tests for the algebraic laws the core relies on. If these
/// hold, `replay` (a fold using `moneyMonoid`-shaped arithmetic) is sound.
void main() {
  group('Money monoid', () {
    Glados(any.money).test('left identity: zero + m == m', (m) {
      expect(moneyMonoid.combine(Money.zero, m), m);
    });

    Glados(any.money).test('right identity: m + zero == m', (m) {
      expect(moneyMonoid.combine(m, Money.zero), m);
    });

    Glados3(any.money, any.money, any.money).test(
      'associativity: (a + b) + c == a + (b + c)',
      (a, b, c) {
        expect(
          moneyMonoid.combine(moneyMonoid.combine(a, b), c),
          moneyMonoid.combine(a, moneyMonoid.combine(b, c)),
        );
      },
    );

    Glados2(any.money, any.money).test('commutativity: a + b == b + a', (a, b) {
      expect(moneyMonoid.combine(a, b), moneyMonoid.combine(b, a));
    });
  });

  group('Money order', () {
    Glados2(any.money, any.money).test('order is consistent with int compare',
        (a, b) {
      expect(
        moneyOrder.compare(a, b),
        a.minorUnits.compareTo(b.minorUnits),
      );
    });

    Glados(any.money).test('reflexive equality', (m) {
      expect(moneyEq.eqv(m, m), isTrue);
    });
  });
}

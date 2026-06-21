import 'package:fpdart/fpdart.dart';

import '../contract/contract.dart';

/// fpdart typeclass instances — the algebra the pure core relies on.
///
/// Keeping these as named values (rather than scattering inline lambdas) makes
/// the laws they must satisfy nameable and testable (see `money_laws_test.dart`).

/// [Money] under addition is a commutative monoid with [Money.zero] as identity.
/// This is exactly what lets a balance be a `fold` over deposit/withdrawal deltas.
final Monoid<Money> moneyMonoid = Monoid.instance(Money.zero, (a, b) => a + b);

/// Total order on [Money] by minor units.
final Order<Money> moneyOrder =
    Order.from((a, b) => a.minorUnits.compareTo(b.minorUnits));

/// Value equality on [Money].
final Eq<Money> moneyEq = Eq.instance((a, b) => a.minorUnits == b.minorUnits);

/// Total order on [Version].
final Order<Version> versionOrder =
    Order.from((a, b) => a.value.compareTo(b.value));

/// Accumulating errors form a [Semigroup] via chain concatenation — the engine
/// behind applicative validation in `validation.dart`.
Semigroup<NonEmptyChain<E>> errorChainSemigroup<E>() =>
    Semigroup.instance((a, b) => a + b);

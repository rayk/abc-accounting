import 'package:fpdart/fpdart.dart';

import 'package:abc_accounting/abc_accounting.dart';
import 'chain.dart';

/// Applicative, error-*accumulating* validation.
///
/// `Either` (used by `decide`) is fail-fast: it stops at the first error.
/// Some inputs — like the parameters to open an account — are better reported
/// all at once. A [Validated] gathers *every* failure into a [NonEmptyChain]
/// before giving up, by combining results with [map2]/[map3]. This is the
/// applicative style fpdart 1.x doesn't ship out of the box, built from its
/// `Either` plus the chain's `Semigroup`.

/// An accumulating validation result.
typedef Validated<A> = Either<NonEmptyChain<LedgerError>, A>;

/// The validated parameters needed to open an account.
///
/// Demonstrated Dart feature: a **record** as a lightweight, structural,
/// immutable product type — no class needed for a transient bundle of values.
typedef OpeningParams = ({
  AccountId id,
  Money openingBalance,
  Money dailyLimit
});

Validated<A> _ok<A>(A value) => Either.of(value);
Validated<A> _fail<A>(LedgerError error) => Either.left(NonEmptyChain(error));

/// Combine two validations, **accumulating** errors from both sides.
Validated<C> map2<A, B, C>(
  Validated<A> va,
  Validated<B> vb,
  C Function(A a, B b) combine,
) =>
    va.match(
      (e1) => vb.match(
        (e2) => Either.left(e1 + e2), // both failed → gather both
        (_) => Either.left(e1),
      ),
      (a) => vb.match(
        (e2) => Either.left(e2),
        (b) => Either.of(combine(a, b)),
      ),
    );

/// Combine three validations, accumulating every error.
Validated<D> map3<A, B, C, D>(
  Validated<A> va,
  Validated<B> vb,
  Validated<C> vc,
  D Function(A a, B b, C c) combine,
) =>
    map2(
      map2(va, vb, (a, b) => (a, b)),
      vc,
      (ab, c) => combine(ab.$1, ab.$2, c),
    );

/// A non-blank account id.
Validated<AccountId> validateId(String raw) => raw.trim().isEmpty
    ? _fail(const EmptyField('id'))
    : _ok(AccountId(raw.trim()));

/// A non-negative opening balance.
Validated<Money> validateOpeningBalance(int minorUnits) => minorUnits < 0
    ? _fail(NegativeAmount(field: 'openingBalance', amount: Money(minorUnits)))
    : _ok(Money(minorUnits));

/// A strictly positive daily limit.
Validated<Money> validateDailyLimit(int minorUnits) => minorUnits <= 0
    ? _fail(NonPositiveLimit(Money(minorUnits)))
    : _ok(Money(minorUnits));

/// Validate all opening parameters at once, reporting every problem found.
Validated<OpeningParams> validateOpening({
  required String id,
  required int openingBalanceMinorUnits,
  required int dailyLimitMinorUnits,
}) =>
    map3(
      validateId(id),
      validateOpeningBalance(openingBalanceMinorUnits),
      validateDailyLimit(dailyLimitMinorUnits),
      (i, b, l) => (id: i, openingBalance: b, dailyLimit: l),
    );

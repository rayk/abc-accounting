import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:abc_accounting/abc_accounting.dart' show Value;

/// A non-empty list of errors that accumulates via [+].
///
/// fpdart 1.x ships no `Validation` type, so error *accumulation* (gather every
/// problem, don't fail fast) is expressed here as a [Semigroup]-carrying chain.
/// See `core/validation.dart` for the applicative validator that uses it, and
/// `core/algebra.dart` for the `Semigroup` instance.
final class NonEmptyChain<E> with Value {
  /// A chain of exactly one element.
  NonEmptyChain(this.head) : tail = IList<E>();

  /// A chain of a [head] followed by zero or more [tail] elements.
  NonEmptyChain.withTail(this.head, this.tail);

  final E head;
  final IList<E> tail;

  /// Every element, head first.
  IList<E> get all => IList([head, ...tail]);

  /// Concatenation — the [Semigroup] operation. Never empty by construction.
  NonEmptyChain<E> operator +(NonEmptyChain<E> other) =>
      NonEmptyChain.withTail(head, tail.addAll(other.all));

  @override
  List<Object?> get props => [head, ...tail];
}

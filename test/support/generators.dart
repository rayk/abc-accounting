import 'package:glados/glados.dart';
import 'package:abc_accounting/abc_accounting.dart';

/// glados generators for domain types, used by the property-based law tests.
extension DomainAny on Any {
  /// Money within a bounded range, so sums in the associativity/identity laws
  /// never overflow.
  Generator<Money> get money =>
      intInRange(-1000000000, 1000000000).map((i) => Money(i));
}

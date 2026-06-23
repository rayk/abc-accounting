// Impl-internal Arbitrary<T> generators — independent of any contract-level generators.
import 'package:abc_accounting/abc_accounting.dart';
import 'package:glados/glados.dart';

extension DomainAny on Any {
  // Glados 1.1.7 uses Generator<T>, not Arbitrary<T>.
  Generator<Money> get money =>
      intInRange(-1000000000, 1000000000).map(Money.new);
  Generator<Money> get validMoney => positiveInt.map(Money.new);
  // nonEmptyLetters is the correct name in glados 1.1.7 (not nonEmptyString).
  Generator<AccountId> get accountId => nonEmptyLetters.map(AccountId.new);
}

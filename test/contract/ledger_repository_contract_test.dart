import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:abc_accounting/abc_accounting.dart';
import 'package:test/test.dart';

/// A reusable **contract test**: the behavior every [LedgerRepository]
/// implementation must exhibit. The default in-memory implementation runs it
/// here; the extensibility test runs the *same* suite against a user-supplied
/// substitute (extension Vector 1), so the interface's behavior — not just its
/// shape — is the spec, and a ready-made oracle for anyone writing an override.
void ledgerRepositoryContract(String name, LedgerRepository Function() make) {
  group('LedgerRepository contract: $name', () {
    const id = AccountId('acc');
    final at = DateTime.utc(2026);

    Future<IList<LedgerEvent>> load(
            LedgerRepository repo, AccountId who) async =>
        (await repo.load(who).run()).getOrElse((_) => fail('load failed'));

    test('load of an unknown id is empty', () async {
      expect((await load(make(), id)).isEmpty, isTrue);
    });

    test('append then load round-trips, preserving order', () async {
      final repo = make();
      final e1 = Deposited(amount: const Money(10), at: at);
      final e2 = Withdrawn(amount: const Money(4), at: at);

      await repo.append(id, IList([e1])).run();
      await repo.append(id, IList([e2])).run();

      expect((await load(repo, id)).toList(), [e1, e2]);
    });

    test('logs are isolated per id', () async {
      final repo = make();
      await repo
          .append(id, IList([Deposited(amount: const Money(1), at: at)]))
          .run();

      expect((await load(repo, const AccountId('other'))).isEmpty, isTrue);
    });
  });
}

void main() {
  ledgerRepositoryContract(
      'InMemoryLedgerRepository', InMemoryLedgerRepository.new);
}

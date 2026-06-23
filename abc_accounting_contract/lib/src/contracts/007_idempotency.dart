@Tags(['idempotency'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract for idempotency keys (cross-cutting concern for keyed commands).
/// Authored: 2026-06-22. Never modified after initial authoring.
void idempotencyContract(LedgerFactory factory) {
  late Ledger sut;
  setUp(() async => sut = await factory(const AccountId('idempotency')));
  tearDown(() => sut.dispose());

  group('deposit — idempotency', () {
    setUpAll(() => ledgerBrief
      ..setRule(
        'A keyed deposit is applied exactly once across retries: '
        'the same key yields the same result without re-applying.',
      )
      ..filterTypes({AccountState, Money}));

    test('keyed deposit applied exactly once', () async {
      const key = Option.of(CommandId('retry-1'));
      final first =
          await sut.deposit(const Money(100), idempotencyKey: key);
      final second =
          await sut.deposit(const Money(100), idempotencyKey: key);
      check(first).success.balance.equals(const Money(100));
      check(second).equals(first);
    }, tags: 'idempotency_keyed_deposit_once');
  }, tags: 'idempotency_keyed_deposit');
}

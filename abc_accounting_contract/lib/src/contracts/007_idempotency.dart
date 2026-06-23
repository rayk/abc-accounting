@Tags(['idempotency'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:checks/checks.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

import '../brief/ledger_brief.dart';
import '../ledger_checks.dart';

/// Contract: a keyed command is applied exactly once across retries.
void idempotencyContract(LedgerFactory factory) {
  group('idempotency', () {
    late Ledger ledger;

    setUp(() async {
      ledgerBrief
        ..setRule(
          'A keyed deposit is applied exactly once across retries '
          '(same key ⇒ same result).',
        )
        ..filterTypes({AccountState});
      ledger = await factory(const AccountId('sut-idempotency'));
      Ledger.verify(ledger);
    });

    tearDown(() => ledger.dispose());

    test('a keyed deposit is idempotent across retries', () async {
      const key = Option.of(CommandId('retry-1'));
      final first =
          await ledger.deposit(const Money(100), idempotencyKey: key);
      final second =
          await ledger.deposit(const Money(100), idempotencyKey: key);
      check(first).success.balance.equals(const Money(100));
      check(second).equals(first); // applied exactly once
    });
  });
}

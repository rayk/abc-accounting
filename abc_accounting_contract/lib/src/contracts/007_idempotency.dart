/// Idempotency cases (`007`).
///
/// Idempotency is a cross-cutting property of the mutating operations rather
/// than a distinct signature, so this file carries cases only — it exercises
/// the `idempotentBy: idempotencyKey` concurrency clause declared on the
/// deposit contract (`002_deposit.dart`): replaying a keyed deposit must apply
/// exactly once.
// ignore_for_file: avoid_catching_errors
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

import 'conformance_support.dart';

/// Registers the `idempotency` conformance cases against [factory].
void idempotencyCases(LedgerFactory factory) {
  group('idempotency', () {
    test(
      'keyed deposit applied exactly once across retries',
      tags: {'contract-ledger', 'sig-deposit', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-idem'));
        const key = Option.of(CommandId('idem-key-1'));
        // First deposit with the idempotency key (setup).
        try {
          await sut.deposit(const Money(100), idempotencyKey: key);
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        // Replay with the same key: state must not be mutated again.
        final outcome = await evaluateCase(
          Case<LedgerEither>(
            description: 'replay of keyed deposit returns cached state',
            given: 'balance == 100 after first keyed deposit; same key',
            when: () => sut.deposit(const Money(100), idempotencyKey: key),
            then: succeeds<LedgerEither, AccountState>([
              Rule<AccountState>(
                id: 'balance-still-100',
                text: 'balance is 100 after replay (not 200)',
                condition: (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(100),
              ),
            ]),
          ),
        );
        await disposeQuietly(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

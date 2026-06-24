/// Change-feed cases (`008`).
///
/// The change feed is the `Ledger.changes` broadcast stream rather than a
/// mutating signature, so this file carries cases only. It proves ordered
/// emissions via the stream harness: two deposits emit `AccountState`s with
/// balance 100 then 150, in order → `StreamMatched`.
///
/// Authoring idiom (load-bearing): `evaluateStreamCase` subscribes a paused
/// `StreamQueue` and pulls *after* the act, so the act must produce the
/// emissions AND close the stream (via `dispose()`). The ops emit
/// synchronously inside their bodies, so the case drives them with
/// `unawaited(...)` and closes via `unawaited(sut.dispose())`.
// ignore_for_file: avoid_catching_errors
library;

import 'dart:async';

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

/// Registers the `changeFeed` conformance cases against [factory].
void changeFeedCases(LedgerFactory factory) {
  group('changeFeed', () {
    test(
      'deposit 100 then 50 emits balances 100, 150 in order',
      tags: {'contract-ledger', 'sig-changes', 'kind-stream'},
      timeout: const Timeout(Duration(seconds: 15)),
      () async {
        final sut = await factory(const AccountId('eac-cf'));
        final outcome = await evaluateStreamCase(
          StreamCase<AccountState>(
            description: 'deposit 100 then 50 emits 100 then 150',
            given: 'a fresh ledger; two deposits: Money(100), Money(50)',
            // Safe stream factory: if the seam is not yet implemented,
            // sut.changes throws UnimplementedError synchronously. Returning
            // an empty stream lets the act run and surface the seam-throw.
            stream: () {
              try {
                return sut.changes;
              } on UnimplementedError {
                return const Stream<AccountState>.empty();
              }
            },
            // Synchronous unawaited emission idiom: subscribe before the act
            // so the StreamQueue buffer captures every broadcast emission.
            act: () async {
              unawaited(sut.deposit(const Money(100)));
              unawaited(sut.deposit(const Money(50)));
              // dispose() closes the changes stream so the queue terminates.
              unawaited(sut.dispose());
            },
            expected: [
              emitsWhere<AccountState>(
                (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(100),
              ),
              emitsWhere<AccountState>(
                (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(150),
              ),
            ],
          ),
        );
        // The SUT is disposed inside the act via unawaited(sut.dispose()).
        check(outcome).isA<StreamMatched>();
      },
    );
  });
}

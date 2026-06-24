/// Change-feed stream harness proofs, against the real `Ledger.changes`
/// broadcast stream.
///
/// **Part 1 — ordered emissions (GREEN).** A [ReferenceLedger] deposit of 100
/// then 50 emits an `AccountState` with balance 100, then 150, in order →
/// [StreamMatched].
///
/// **Part 2 — anti-trap.** Expecting emissions on a stream that will never emit
/// (a disposed ledger whose `changes` is closed) surfaces as [StreamVacuous] —
/// a loud failure — never a silent green.
///
/// **Part 3 — no-op emits nothing.** Two `freeze()` calls emit exactly once;
/// the second freeze is a no-op. Expecting *two* frozen emissions yields a
/// [StreamMismatch] because the stream ends after one.
@TestOn('vm')
library;

import 'dart:async';

import 'package:abc_accounting/abc_accounting.dart';
import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

const _t = Timeout(Duration(seconds: 15));

void main() {
  group('ordered emissions on Ledger.changes', () {
    test(
      'deposit 100 then 50 emits balance 100 then 150 → StreamMatched',
      tags: 'kind-stream',
      timeout: _t,
      () async {
        final ledger = await ReferenceLedger.open(
          const AccountId('cf-ordered'),
        );
        final outcome = await evaluateStreamCase(
          StreamCase<AccountState>(
            description: 'ordered deposit emissions',
            given: 'a freshly opened ReferenceLedger',
            stream: () => ledger.changes,
            act: () async {
              unawaited(ledger.deposit(const Money(100)));
              unawaited(ledger.deposit(const Money(50)));
              unawaited(ledger.dispose());
            },
            expected: [
              emitsWhere<AccountState>(
                (s) => s
                    .has((a) => a.balance.minorUnits, 'balance.minorUnits')
                    .equals(100),
              ),
              emitsWhere<AccountState>(
                (s) => s
                    .has((a) => a.balance.minorUnits, 'balance.minorUnits')
                    .equals(150),
              ),
            ],
          ),
        );
        check(outcome).isA<StreamMatched>();
      },
    );
  });

  group('anti-trap (eventsDispatched == 0 is never a green)', () {
    test(
      'expecting emissions on a closed stream → StreamVacuous, not a pass',
      tags: 'kind-stream',
      timeout: _t,
      () async {
        final ledger = await ReferenceLedger.open(const AccountId('cf-trap'));
        // Dispose closes the broadcast `changes` controller with no emissions.
        await ledger.dispose();
        final outcome = await evaluateStreamCase(
          StreamCase<AccountState>(
            description: 'stream closed before any emission',
            given: 'a disposed ledger whose changes stream is already closed',
            stream: () => ledger.changes,
            act: () async {}, // no-op: nothing will ever be emitted
            expected: [
              emitsWhere<AccountState>(
                (s) => s
                    .has((a) => a.balance.minorUnits, 'balance.minorUnits')
                    .equals(100),
              ),
            ],
          ),
        );
        check(outcome).isA<StreamVacuous>();
        final vacuous = outcome as StreamVacuous;
        check(vacuous.expected).equals(1);
        check(vacuous.observed).equals(0);
      },
    );
  });

  group('a no-op operation emits nothing', () {
    test(
      'freeze then freeze emits once (frozen) → StreamMatched',
      tags: 'kind-stream',
      timeout: _t,
      () async {
        final ledger = await ReferenceLedger.open(const AccountId('cf-noop'));
        final outcome = await evaluateStreamCase(
          StreamCase<AccountState>(
            description: 'freeze then freeze',
            given: 'an open ledger; the second freeze is a no-op',
            stream: () => ledger.changes,
            act: () async {
              unawaited(ledger.freeze());
              unawaited(ledger.freeze()); // no-op: already frozen
              unawaited(ledger.dispose());
            },
            expected: [
              emitsWhere<AccountState>(
                (s) => s
                    .has((a) => a.status, 'status')
                    .equals(AccountStatus.frozen),
              ),
            ],
          ),
        );
        check(outcome).isA<StreamMatched>();
      },
    );

    test(
      'expecting TWO frozen emissions from two freezes → StreamMismatch',
      tags: 'kind-stream',
      timeout: _t,
      () async {
        final ledger = await ReferenceLedger.open(const AccountId('cf-noop2'));
        final outcome = await evaluateStreamCase(
          StreamCase<AccountState>(
            description: 'freeze then freeze, wrongly expecting two emissions',
            given: 'the second freeze is a no-op, so only one state is emitted',
            stream: () => ledger.changes,
            act: () async {
              unawaited(ledger.freeze());
              unawaited(ledger.freeze());
              unawaited(ledger.dispose());
            },
            expected: [
              emitsWhere<AccountState>(
                (s) => s
                    .has((a) => a.status, 'status')
                    .equals(AccountStatus.frozen),
              ),
              emitsWhere<AccountState>(
                (s) => s
                    .has((a) => a.status, 'status')
                    .equals(AccountStatus.frozen),
              ),
            ],
          ),
        );
        check(outcome).isA<StreamMismatch>();
        check((outcome as StreamMismatch).details).contains('stream ended');
      },
    );
  });
}

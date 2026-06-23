/// Phase-4 EAC proof: the temporal stream harness + declarative temporal
/// clauses, exercised against the real `Ledger.changes` broadcast stream.
///
/// **Part 1 — ordered emissions (GREEN).** A [ReferenceLedger] deposit of 100
/// then 50 emits an `AccountState` with balance 100, then 150, in order →
/// [StreamMatched].
///
/// **Part 2 — anti-trap (the spec's named hazard).** Expecting emissions on a
/// stream that will never emit (a disposed ledger whose `changes` is closed)
/// surfaces as [StreamVacuous] — a loud failure — never a silent green.
///
/// **Part 3 — no-op emits nothing.** Two `freeze()` calls emit exactly once:
/// the second freeze is a no-op. Proven both ways — one frozen emission
/// matches, and expecting *two* frozen emissions yields a [StreamMismatch]
/// because the stream ends after one.
///
/// **Part 4 — declarative temporal clauses.** `Timing` / `Lifecycle` /
/// `Concurrency` / `Compensation` / `RetryPolicy` attach to a `SignatureDecl`
/// and carry the expected tags. They are inert metadata — never executed.
///
/// ## Authoring idiom (load-bearing)
///
/// `evaluateStreamCase` subscribes a paused `StreamQueue` to the broadcast
/// `changes` stream, pulls *after* the act, and has no bounded internal wait.
/// The reliable idiom is therefore: produce the emissions within the act AND
/// let the stream CLOSE within the act. `Ledger` ops emit synchronously inside
/// the op body and `dispose()` closes `changes`, so the cases below drive the
/// ops with `unawaited(...)` and close via `unawaited(ledger.dispose())`. If an
/// act under-emits and leaves the stream open, the read-loop blocks — always a
/// loud failure (per-test `timeout` guards below; `package:test` also backstops
/// at 30 s), never a false-green. KNOWN FOLLOW-UP: the harness should bound its
/// waits / pre-issue outstanding pulls so an under-emitting case fails loudly
/// and fast rather than relying on a timeout.
@TestOn('vm')
library;

import 'dart:async';

import 'package:abc_accounting/abc_accounting.dart';
import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

const _t = Timeout(Duration(seconds: 15));

void main() {
  // ── Part 1 — ordered emissions ───────────────────────────────────────────

  group('Phase 4 — ordered emissions on Ledger.changes', () {
    test(
      'deposit 100 then 50 emits balance 100 then 150 → StreamMatched',
      tags: 'kind-stream',
      timeout: _t,
      () async {
        final ledger = await ReferenceLedger.open(
          const AccountId('p4-ordered'),
        );

        final outcome = await evaluateStreamCase(
          StreamCase<AccountState>(
            description: 'ordered deposit emissions',
            given: 'a freshly opened ReferenceLedger',
            stream: () => ledger.changes,
            act: () async {
              // Synchronous emission within the act (see the idiom note above).
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

  // ── Part 2 — anti-trap ───────────────────────────────────────────────────

  group('Phase 4 — anti-trap (eventsDispatched == 0 is never a green)', () {
    test(
      'expecting emissions on a closed stream → StreamVacuous, not a pass',
      tags: 'kind-stream',
      timeout: _t,
      () async {
        final ledger = await ReferenceLedger.open(const AccountId('p4-trap'));
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

  // ── Part 3 — no-op emits nothing ─────────────────────────────────────────

  group('Phase 4 — a no-op operation emits nothing', () {
    test(
      'freeze then freeze emits once (frozen) → StreamMatched',
      tags: 'kind-stream',
      timeout: _t,
      () async {
        final ledger = await ReferenceLedger.open(const AccountId('p4-noop'));

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
      'expecting TWO frozen emissions from two freezes → StreamMismatch '
      '(the no-op never emitted)',
      tags: 'kind-stream',
      timeout: _t,
      () async {
        final ledger = await ReferenceLedger.open(const AccountId('p4-noop2'));

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

  // ── Part 4 — declarative temporal clauses ────────────────────────────────

  group('Phase 4 — declarative temporal clauses on a signature', () {
    test('Timing/Lifecycle/Concurrency/Compensation stored + tagged', () {
      final contract =
          Contract(
            name: 'deposit_temporal',
            version: const ContractVersion(0, 1, 0),
            purpose: 'Declares the temporal semantics of the deposit boundary.',
          )..abstractMethod<Ledger>(
            #deposit,
            purpose:
                'Adds money; settles within a deadline; idempotent by key.',
            timing: const Timing(
              within: Duration(seconds: 5),
              elseFailure: 'TimeoutFailure',
              settles: Duration(seconds: 10),
              retry: RetryPolicy(max: 3, on: 'StorageFailure'),
            ),
            lifecycle: const Lifecycle(
              states: ['pending', 'settled', 'failed'],
              pending: 'no mutation while in-flight',
              onFailure: 'state unchanged',
            ),
            concurrency: const Concurrency(
              idempotentBy: 'idempotencyKey',
              atomic: true,
              atMostOnce: 'AccountState',
            ),
            compensation: revert('AccountState'),
          );

      final sig = contract.signatures.single;

      check(sig.timing).isNotNull();
      check(sig.timing!.within).equals(const Duration(seconds: 5));
      check(sig.timing!.elseFailure).equals('TimeoutFailure');
      check(sig.timing!.retry!.tag).equals('retry-StorageFailure');
      check(sig.timing!.tag).equals('timing');

      check(sig.lifecycle!.states).deepEquals(['pending', 'settled', 'failed']);
      check(sig.lifecycle!.tag).equals('lifecycle');

      check(sig.concurrency!.idempotentBy).equals('idempotencyKey');
      check(sig.concurrency!.atomic).isTrue();
      check(sig.concurrency!.tag).equals('concurrency');

      check(sig.compensation!.onFailureRevert).equals('AccountState');
      check(sig.compensation!.tag).equals('compensation');
    });
  });
}

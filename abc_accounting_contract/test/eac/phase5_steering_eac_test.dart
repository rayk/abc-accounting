/// Phase-5 EAC proof: the steering surface against the real account_opening
/// contract and Ledger outcomes.
///
/// **Part 1 — steering render (POLICY).** A real `CaseRejected` (deposit
/// succeeds but the case wrongly expects a rejection) renders a Steer-first
/// panel tagged `[POLICY]`, with the observed `Right` in `Got` and the verbatim
/// DO-NOT guardrail.
///
/// **Part 2 — steering render (MISSING_SYMBOL).** The unimplemented stub throws
/// → `SeamThrew` → `[MISSING_SYMBOL]`.
///
/// **Part 3 — orientation inventory.** The deposit signature renders the spec
/// inventory shape (function, purpose, invariants, failures, hyphen tags).
///
/// **Part 4 — sidecar + stable IDs.** Records key by `contract/signature/unit:id`;
/// every tag is hyphen-only; the JSON is byte-identical across two builds with
/// the same seeds.
///
/// **Part 5 — --tags selection.** Hyphen-tagged tests are selected by
/// `dart test --tags` (the runner accepts hyphenated identifiers; the engine
/// never emits a `:` or `.` in a tag). The selection is exercised from the
/// command line (see the build log's `--tags` run).
@TestOn('vm')
@Tags(['contract-account_opening'])
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:abc_accounting_contract/src/eac/account_opening.dart';
import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:bnd_eac/execution.dart';
import 'package:bnd_eac/steering.dart';
import 'package:checks/checks.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

typedef _R = Either<LedgerError, AccountState>;

const _wrongReject = FailureMode<AmountMustBePositive>(
  when: 'the amount is not positive',
  steer: 'return Left(AmountMustBePositive(amount)); create no AccountState',
);

void main() {
  // ── Part 1 — steering render (POLICY) ────────────────────────────────────

  group('Phase 5 — steering render for a real CaseRejected (POLICY)', () {
    test('renders Steer-first with [POLICY] and the verbatim DO-NOT', () async {
      final ledger = await ReferenceLedger.open(const AccountId('p5-policy'));
      // deposit(100) settles Right, but this case wrongly expects a rejection.
      final outcome = await evaluateCase(
        Case<_R>(
          description: 'deposit 100 wrongly expected to reject',
          given: 'an open ledger',
          when: () => ledger.deposit(const Money(100)),
          then: rejects<_R, AmountMustBePositive>(_wrongReject),
        ),
      );
      await ledger.dispose();

      check(outcome).isA<CaseRejected>();
      check(classifyOutcome(outcome)).equals(FailureClass.policy);

      final block = steeringForCase(
        stableId: stableId(
          contract: 'account_opening',
          signature: 'deposit',
          unit: 'case',
          id: 'wrong-reject',
        ),
        outcome: outcome,
        given: 'an open ledger, deposit Money(100)',
        when: 'deposit',
        then: 'rejects AmountMustBePositive',
        failure: _wrongReject,
      );
      final text = renderSteering(block);

      check(
        text,
      ).contains('account_opening/deposit/case:wrong-reject  [POLICY]');
      // Steer-first ordering.
      check(text.indexOf('Steer')).isLessThan(text.indexOf('Got'));
      check(text.indexOf('Got')).isLessThan(text.indexOf('Given'));
      // The domain steer text is surfaced.
      check(text).contains('return Left(AmountMustBePositive(amount))');
      // The observed Right is in Got.
      check(text).contains('is Right, expected Left');
      // The verbatim DO-NOT guardrail.
      check(text).contains('DO NOT edit, weaken, or skip this test.');
      check(text).contains(
        'If this check appears wrong, escalate SPEC_SUSPECT to the human '
        'author — do not self-edit.',
      );
    });
  });

  // ── Part 2 — steering render (MISSING_SYMBOL) ────────────────────────────

  group('Phase 5 — steering render for a seam-throw (MISSING_SYMBOL)', () {
    test('the unimplemented stub renders [MISSING_SYMBOL]', () async {
      final outcome = await evaluateCase(
        Case<_R>(
          description: 'deposit against the unimplemented stub',
          given: 'an UnimplementedLedger',
          when: () => UnimplementedLedger().deposit(const Money(10)),
          then: succeeds<_R, AccountState>(const []),
        ),
      );

      check(outcome).isA<SeamThrew>();
      check(classifyOutcome(outcome)).equals(FailureClass.missingSymbol);

      final text = renderSteering(
        steeringForCase(
          stableId: stableId(
            contract: 'account_opening',
            signature: 'deposit',
            unit: 'case',
            id: 'stub',
          ),
          outcome: outcome,
          given: 'an UnimplementedLedger',
          when: 'deposit',
          then: 'succeeds with a settled Right',
        ),
      );
      check(text).contains('[MISSING_SYMBOL]');
      check(text).contains('Implement the body');
    });
  });

  // ── Part 3 — orientation inventory ───────────────────────────────────────

  group('Phase 5 — orientation inventory for account_opening', () {
    test('renders the spec inventory shape for the deposit signature', () {
      final deposit = accountOpeningContract.signatures.firstWhere(
        (s) => s.name == 'deposit',
      );
      final inv = orientationInventory(
        accountOpeningContract,
        deposit,
        grounding: 'AccountState.empty(id)',
      );

      check(inv['kind']).equals('inventory');
      check(inv['contract']).equals('account_opening');
      check(inv['grounding']).equals('AccountState.empty(id)');
      check(inv['function']).isA<String>();
      // The declared invariant + failure mode are surfaced.
      check(inv['invariants']! as List).isNotEmpty();
      final failures = inv['failures']! as List;
      check(
        failures.map((f) => (f as Map)['type']).toList(),
      ).contains('AmountMustBePositive');
      // Tags are hyphen-form.
      check(inv['tags']! as List).contains('contract-account_opening');
    });
  });

  // ── Part 4 — sidecar + stable IDs + tag hygiene ──────────────────────────

  group('Phase 5 — sidecar keyed by stable IDs', () {
    Map<String, Object?> rec(String id, {int seed = 7}) => sidecarRecord(
      id: id,
      kind: 'negative',
      given: 'an open ledger',
      when: 'deposit',
      then: 'rejects AmountMustBePositive',
      outcome: 'CaseRejected',
      tags: [
        contractTag('account_opening'),
        sigTag('deposit'),
        failureTag('AmountMustBePositive'),
        Kind.negative.tag,
      ],
      gladosSeed: seed,
      orderingSeed: 42,
    );

    test('keys use contract/signature/unit:id and tags are hyphen-only', () {
      final id = stableId(
        contract: 'account_opening',
        signature: 'deposit',
        unit: 'case',
        id: 'overdrawn',
      );
      check(id).equals('account_opening/deposit/case:overdrawn');

      final record = rec(id);
      for (final tag in record['tags']! as List) {
        check(tag as String).not((s) => s.contains(':'));
        check(tag).not((s) => s.contains('.'));
      }
    });

    test('JSON is byte-identical across two builds with the same seeds', () {
      List<Map<String, Object?>> build() => [
        rec('account_opening/deposit/case:a'),
        rec('account_opening/deposit/case:b'),
      ];
      check(sidecarJson(build())).equals(sidecarJson(build()));
    });
  });

  // ── Part 5 — --tags selection witnesses ──────────────────────────────────

  group('Phase 5 — hyphen-tagged tests for --tags selection', () {
    test(
      'a negative-tagged witness',
      tags: {
        'contract-account_opening',
        'failure-AmountMustBePositive',
        'kind-negative',
      },
      () {
        check(
          failureTag('AmountMustBePositive'),
        ).equals('failure-AmountMustBePositive');
      },
    );

    test(
      'a positive-tagged witness',
      tags: {'contract-account_opening', 'kind-positive'},
      () => check(Kind.positive.tag).equals('kind-positive'),
    );
  });
}

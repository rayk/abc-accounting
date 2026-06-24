/// Phase-3 EAC proof: [Precondition] / [Postcondition] / [Effect] clauses.
///
/// Three groups, each proving one clause type:
///
/// **Part 1 — ensures(old()) with deposit**
/// - GREEN: [ReferenceLedger] satisfies per-case postconditions that close
///   over the specific deposit amount → [CasePassed].
/// - RED: A broken [_BalanceFrozenLedger] returns Right with the unchanged
///   state → PostconditionFailed with oldRender showing the pre-state.
///
/// **Part 2 — requires guard on deposit**
/// - GREEN: [ReferenceLedger] guards amount > 0 → [CasePassed].
/// - RED: A [_NoGuardLedger] accepts amount=0 and returns Right
///   → [GuardMissing].
///
/// **Part 3 — effects metadata**
/// - Proves that [PersistEffect] and [EmitEffect] are stored on the
///   [SignatureDecl] and carry the expected [Effect.tag] values.
///   Effects are inert metadata; the runner does not evaluate them.
@TestOn('vm')
library;

import 'dart:async';

import 'package:abc_accounting/abc_accounting.dart';
import 'package:abc_accounting_contract/src/phase3_clauses.dart';
import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

// ── Type alias ───────────────────────────────────────────────────────────────

typedef _R = Either<LedgerError, AccountState>;

// ── Local fakes ──────────────────────────────────────────────────────────────

/// A broken [Ledger] that accepts any deposit but silently ignores the amount
/// and returns the *unchanged* state as a Right.
///
/// Intentional bug: balance is never incremented, so any [Postcondition]
/// asserting `after.balance > before.balance` fires [PostconditionFailed].
final class _BalanceFrozenLedger extends Ledger {
  _BalanceFrozenLedger(AccountId id)
    : _state = AccountState.empty(id),
      super(token: Ledger.token);

  // Intentionally `final` — deposit deliberately does not mutate state.
  final AccountState _state;

  @override
  AccountId get id => _state.id;

  @override
  AccountState get state => _state;

  @override
  Stream<AccountState> get changes => const Stream<AccountState>.empty();

  @override
  LedgerResult deposit(
    Money amount, {
    Option<CommandId> idempotencyKey = const None(),
  }) async =>
      // BUG: ignores amount, returns unchanged state.
      Either.of(_state);

  @override
  Future<void> dispose() async {}
}

/// A broken [Ledger] that never rejects — deposit always returns Right even
/// when the amount is zero.
///
/// Intentional bug: the domain guard (`amount > 0`) is absent, so the runner
/// surfaces [GuardMissing] instead of [CasePassed] when the [Case] declares
/// a [Precondition] guard and the act returns Right.
final class _NoGuardLedger extends Ledger {
  _NoGuardLedger(AccountId id)
    : _state = AccountState.empty(id),
      super(token: Ledger.token);

  AccountState _state;

  @override
  AccountId get id => _state.id;

  @override
  AccountState get state => _state;

  @override
  Stream<AccountState> get changes => const Stream<AccountState>.empty();

  @override
  LedgerResult deposit(
    Money amount, {
    Option<CommandId> idempotencyKey = const None(),
  }) async {
    // BUG: no guard — succeeds even for amount = Money(0).
    _state = _state.copyWith(
      balance: _state.balance + amount,
      version: _state.version.next,
    );
    return Either.of(_state);
  }

  @override
  Future<void> dispose() async {}
}

// ── Case-level postconditions ────────────────────────────────────────────────
// These close over the specific `amount` used in a test case, which the
// contract-level postconditions in phase3_clauses.dart cannot do.

Postcondition _balanceIncreasedBy(Money amount) => Postcondition(
  id: 'balance-increased-by-amount',
  text: 'balance after deposit equals old.balance + deposit amount',
  holds: (old, result) {
    final before = old! as AccountState;
    final after = result! as AccountState;
    return after.balance == before.balance + amount;
  },
);

final _versionIncrementedPC = Postcondition(
  id: 'version-incremented',
  text: 'version increments by 1 after a successful deposit',
  holds: (old, result) {
    final before = old! as AccountState;
    final after = result! as AccountState;
    return after.version == Version(before.version.value + 1);
  },
);

// ── Precondition (reused across Part 2 tests) ────────────────────────────────
// Declared once at file scope so both Green and Red tests share the same
// Precondition instance, proving the runner uses the declared metadata.

final _amountPositivePrecondition = Precondition(
  id: 'amount-positive',
  text: 'amount must be positive',
  holds: (args) => (args as Money).isPositive,
);

// ── Test suite ───────────────────────────────────────────────────────────────

void main() {
  // ── PART 1: ensures(old()) — deposit postconditions ─────────────────────

  group('ensures(old()) — deposit postconditions', () {
    const depositAmount = Money(100);

    test(
      'GREEN — ReferenceLedger satisfies balance and version postconditions',
      () async {
        final ledger = await ReferenceLedger.open(
          const AccountId('phase3-ensures-ref'),
        );

        final outcome = await evaluateCase<_R>(
          Case<_R>(
            description: 'deposit(Money(100)) satisfies postconditions',
            given: 'fresh account; deposit amount = Money(100)',
            when: () => ledger.deposit(depositAmount),
            then: succeeds<_R, AccountState>(
              const [],
              ensures: [
                _balanceIncreasedBy(depositAmount),
                _versionIncrementedPC,
              ],
            ),
            capture: () => ledger.state,
          ),
        );

        printOnFailure('Part1/green outcome: ${outcome.runtimeType}');
        if (outcome is PostconditionFailed) {
          for (final f in outcome.failures) {
            printOnFailure(
              '  PostconditionFailed id=${f.id} '
              'oldRender=${f.oldRender} '
              'resultRender=${f.resultRender}',
            );
          }
        }

        // GREEN: ReferenceLedger deposits correctly — both postconditions hold.
        expect(
          outcome,
          isA<CasePassed>(),
          reason:
              'ReferenceLedger.deposit(Money(100)) must return '
              'Right(AccountState) satisfying both postconditions: '
              'balance == old.balance + 100 and version == old.version + 1.',
        );
      },
    );

    test(
      'RED — BalanceFrozenLedger ignores amount '
      '→ PostconditionFailed with oldRender showing pre-state',
      () async {
        const brokenAmount = Money(50);
        final broken = _BalanceFrozenLedger(
          const AccountId('phase3-ensures-broken'),
        );

        final outcome = await evaluateCase<_R>(
          Case<_R>(
            description: 'broken fake deposit ignores amount',
            given: 'BalanceFrozenLedger; deposit amount = Money(50)',
            when: () => broken.deposit(brokenAmount),
            then: succeeds<_R, AccountState>(
              const [],
              ensures: [_balanceIncreasedBy(brokenAmount)],
            ),
            capture: () => broken.state,
          ),
        );

        printOnFailure('Part1/red outcome: ${outcome.runtimeType}');

        // ASSERT: PostconditionFailed — the act returned Right with unchanged
        // balance but the postcondition holds(old, result) returned false.
        expect(
          outcome,
          isA<PostconditionFailed>(),
          reason:
              'BalanceFrozenLedger silently ignores amount; '
              'balance postcondition must fire PostconditionFailed.',
        );

        final pf = outcome as PostconditionFailed;
        expect(pf.failures, hasLength(1));
        expect(pf.failures.first.id, equals('balance-increased-by-amount'));

        // oldRender is the string representation of the captured pre-act state
        // (AccountState) — proves the runner round-trips the pre-state
        // snapshot.
        expect(
          pf.failures.first.oldRender,
          contains('AccountState'),
          reason:
              'oldRender must embed the AccountState pre-act snapshot '
              'so the brief can show the concrete pre-deposit balance.',
        );

        printOnFailure(
          'PostconditionFailed.oldRender: ${pf.failures.first.oldRender}',
        );
        printOnFailure(
          'PostconditionFailed.resultRender: '
          '${pf.failures.first.resultRender}',
        );
      },
    );
  });

  // ── PART 2: requires guard — deposit(Money(0)) ───────────────────────────

  group('requires guard — deposit(Money(0))', () {
    const zeroAmount = Money(0);

    // Rejects case template: both SUT variants share this declaration.
    final rejectsThen = rejects<_R, AmountMustBePositive>(
      const FailureMode<AmountMustBePositive>(
        when: 'the deposit amount is not positive',
        steer: 'return Left(AmountMustBePositive(amount)); do not mutate',
      ),
      guards: [_amountPositivePrecondition],
    );

    test(
      'GREEN — ReferenceLedger guards amount > 0 → CasePassed',
      () async {
        final ledger = await ReferenceLedger.open(
          const AccountId('phase3-guard-ref'),
        );

        final outcome = await evaluateCase<_R>(
          Case<_R>(
            description: 'deposit(Money(0)) rejected: AmountMustBePositive',
            given: 'fresh account; deposit amount = Money(0)',
            when: () => ledger.deposit(zeroAmount),
            then: rejectsThen,
          ),
        );

        printOnFailure('Part2/green outcome: ${outcome.runtimeType}');

        // ReferenceLedger calls `if (!amount.isPositive)` before mutating,
        // returns Left(AmountMustBePositive). Rejects branch passes
        // → CasePassed.
        expect(
          outcome,
          isA<CasePassed>(),
          reason:
              'ReferenceLedger returns Left(AmountMustBePositive) for '
              'Money(0); the Rejects branch must pass.',
        );
      },
    );

    test(
      'RED — NoGuardLedger returns Right for amount=0 '
      '→ GuardMissing (MISSING_GUARD)',
      () async {
        final broken = _NoGuardLedger(
          const AccountId('phase3-guard-broken'),
        );

        final outcome = await evaluateCase<_R>(
          Case<_R>(
            description: 'deposit(Money(0)) rejected: AmountMustBePositive',
            given: 'fresh account; deposit amount = Money(0)',
            when: () => broken.deposit(zeroAmount),
            then: rejectsThen,
          ),
        );

        printOnFailure('Part2/red outcome: ${outcome.runtimeType}');

        // ASSERT: GuardMissing — the act returned Right (wrong branch) while
        // the Rejects case declared guards. The runner infers the guard is
        // absent (MISSING_GUARD).
        expect(
          outcome,
          isA<GuardMissing>(),
          reason:
              'NoGuardLedger accepts Money(0) without rejecting; '
              'runner must surface GuardMissing (MISSING_GUARD).',
        );

        final gm = outcome as GuardMissing;
        expect(gm.preconditionId, equals('amount-positive'));
        expect(gm.preconditionText, equals('amount must be positive'));
        expect(
          gm.actualRight,
          contains('AccountState'),
          reason:
              'actualRight is the toString() of the wrongly-returned '
              'Right value — must embed the AccountState representation.',
        );

        printOnFailure(
          'GuardMissing.preconditionId: ${gm.preconditionId}',
        );
        printOnFailure('GuardMissing.actualRight: ${gm.actualRight}');
      },
    );
  });

  // ── PART 3: effects — inert metadata on SignatureDecl ────────────────────

  group('effects — inert metadata on SignatureDecl', () {
    final depositSig = phase3DepositContract.signatures.firstWhere(
      (s) => s.name == 'deposit',
    );

    test(
      'deposit signature carries two effects: '
      'persist(AccountState) + emit(AccountState)',
      () {
        printOnFailure(
          'effects: ${depositSig.effects.map((e) => e.tag).toList()}',
        );

        expect(
          depositSig.effects,
          hasLength(2),
          reason:
              'Expected exactly two effects on deposit: '
              'persist(AccountState) and emit(AccountState).',
        );

        expect(
          depositSig.effects.map((e) => e.tag),
          containsAll([
            'effect-persist-AccountState',
            'effect-emit-AccountState',
          ]),
          reason: 'Effect tags must follow the effect-<kind>-<type> pattern.',
        );

        final persistEffect = depositSig.effects
            .whereType<PersistEffect>()
            .first;
        expect(persistEffect.type, equals('AccountState'));

        final emitEffect = depositSig.effects.whereType<EmitEffect>().first;
        expect(emitEffect.type, equals('AccountState'));
      },
    );

    test(
      'deposit signature carries one requires precondition: amount-positive',
      () {
        printOnFailure(
          'requires: '
          '${depositSig.requires.map((r) => r.tag).toList()}',
        );

        expect(
          depositSig.requires,
          hasLength(1),
          reason: 'Expected exactly one requires precondition.',
        );
        expect(depositSig.requires.first.id, equals('amount-positive'));
        expect(
          depositSig.requires.first.tag,
          equals('requires-amount-positive'),
        );
      },
    );

    test(
      'deposit signature carries two ensures postconditions: '
      'balance-increased-by-amount + version-incremented',
      () {
        printOnFailure(
          'ensures: '
          '${depositSig.ensures.map((e) => e.tag).toList()}',
        );

        expect(
          depositSig.ensures,
          hasLength(2),
          reason: 'Expected exactly two ensures postconditions.',
        );
        expect(
          depositSig.ensures.map((e) => e.id),
          containsAll([
            'balance-increased-by-amount',
            'version-incremented',
          ]),
        );
        expect(
          depositSig.ensures.map((e) => e.tag),
          containsAll([
            'ensures-balance-increased-by-amount',
            'ensures-version-incremented',
          ]),
        );
      },
    );
  });
}

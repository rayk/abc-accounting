/// Clause proofs for the deposit contract: `requires` / `ensures(old())` /
/// `effects`, plus the inert temporal clause family.
///
/// **Part 1 — ensures(old()).** GREEN: [ReferenceLedger] satisfies per-case
/// postconditions that close over the deposit amount → [CasePassed]. RED: a
/// broken [_BalanceFrozenLedger] returns Right with unchanged state →
/// [PostconditionFailed] with `oldRender` showing the pre-state.
///
/// **Part 2 — requires guard.** GREEN: [ReferenceLedger] guards amount > 0 →
/// [CasePassed]. RED: a [_NoGuardLedger] accepts amount=0 and returns Right →
/// [GuardMissing] (MISSING_GUARD).
///
/// **Part 3 — effects / requires / ensures metadata** stored on the deposit
/// [SignatureDecl] with the expected tags.
///
/// **Part 4 — temporal clauses** (timing / lifecycle / concurrency /
/// compensation) stored as inert metadata on the deposit signature.
@TestOn('vm')
library;

import 'dart:async';

import 'package:abc_accounting/abc_accounting.dart';
import 'package:abc_accounting_contract/src/contracts/002_deposit.dart';
import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

typedef _R = Either<LedgerError, AccountState>;

/// A broken [Ledger] that accepts any deposit but ignores the amount and
/// returns the *unchanged* state — any "balance increased" postcondition fires.
final class _BalanceFrozenLedger extends Ledger {
  _BalanceFrozenLedger(AccountId id)
    : _state = AccountState.empty(id),
      super(token: Ledger.token);

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
/// for a zero amount, so the runner surfaces [GuardMissing].
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

/// Case-level postcondition closing over the specific deposit [amount].
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

final _amountPositivePrecondition = Precondition(
  id: 'amount-positive',
  text: 'amount must be positive',
  holds: (args) => (args as Money).isPositive,
);

void main() {
  // ── Part 1: ensures(old()) — deposit postconditions ──────────────────────

  group('ensures(old()) — deposit postconditions', () {
    const depositAmount = Money(100);

    test('GREEN — ReferenceLedger satisfies balance and version postconditions',
        () async {
      final ledger = await ReferenceLedger.open(
        const AccountId('deposit-ensures-ref'),
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
      expect(
        outcome,
        isA<CasePassed>(),
        reason:
            'ReferenceLedger.deposit(Money(100)) must satisfy both '
            'postconditions: balance == old.balance + 100 and version + 1.',
      );
    });

    test(
      'RED — BalanceFrozenLedger ignores amount → PostconditionFailed with '
      'oldRender showing pre-state',
      () async {
        const brokenAmount = Money(50);
        final broken = _BalanceFrozenLedger(
          const AccountId('deposit-ensures-broken'),
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
        expect(outcome, isA<PostconditionFailed>());
        final pf = outcome as PostconditionFailed;
        expect(pf.failures, hasLength(1));
        expect(pf.failures.first.id, equals('balance-increased-by-amount'));
        expect(
          pf.failures.first.oldRender,
          contains('AccountState'),
          reason:
              'oldRender must embed the AccountState pre-act snapshot so the '
              'brief can show the concrete pre-deposit balance.',
        );
      },
    );
  });

  // ── Part 2: requires guard — deposit(Money(0)) ───────────────────────────

  group('requires guard — deposit(Money(0))', () {
    const zeroAmount = Money(0);

    final rejectsThen = rejects<_R, AmountMustBePositive>(
      const FailureMode<AmountMustBePositive>(
        when: 'the deposit amount is not positive',
        steer: 'return Left(AmountMustBePositive(amount)); do not mutate',
      ),
      guards: [_amountPositivePrecondition],
    );

    test('GREEN — ReferenceLedger guards amount > 0 → CasePassed', () async {
      final ledger = await ReferenceLedger.open(
        const AccountId('deposit-guard-ref'),
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
      expect(
        outcome,
        isA<CasePassed>(),
        reason:
            'ReferenceLedger returns Left(AmountMustBePositive) for Money(0); '
            'the Rejects branch must pass.',
      );
    });

    test('RED — NoGuardLedger returns Right for amount=0 → GuardMissing',
        () async {
      final broken = _NoGuardLedger(const AccountId('deposit-guard-broken'));
      final outcome = await evaluateCase<_R>(
        Case<_R>(
          description: 'deposit(Money(0)) rejected: AmountMustBePositive',
          given: 'fresh account; deposit amount = Money(0)',
          when: () => broken.deposit(zeroAmount),
          then: rejectsThen,
        ),
      );
      printOnFailure('Part2/red outcome: ${outcome.runtimeType}');
      expect(outcome, isA<GuardMissing>());
      final gm = outcome as GuardMissing;
      expect(gm.preconditionId, equals('amount-positive'));
      expect(gm.preconditionText, equals('amount must be positive'));
      expect(gm.actualRight, contains('AccountState'));
    });
  });

  // ── Part 3: effects / requires / ensures metadata ────────────────────────

  group('clause metadata on the deposit SignatureDecl', () {
    final depositSig = depositContract.signatures.single;

    test('two effects: persist(AccountState) + emit(AccountState)', () {
      expect(depositSig.effects, hasLength(2));
      expect(
        depositSig.effects.map((e) => e.tag),
        containsAll([
          'effect-persist-AccountState',
          'effect-emit-AccountState',
        ]),
      );
      expect(
        depositSig.effects.whereType<PersistEffect>().first.type,
        equals('AccountState'),
      );
      expect(
        depositSig.effects.whereType<EmitEffect>().first.type,
        equals('AccountState'),
      );
    });

    test('one requires precondition: amount-positive', () {
      expect(depositSig.requires, hasLength(1));
      expect(depositSig.requires.first.id, equals('amount-positive'));
      expect(depositSig.requires.first.tag, equals('requires-amount-positive'));
    });

    test('two ensures postconditions: balance + version', () {
      expect(depositSig.ensures, hasLength(2));
      expect(
        depositSig.ensures.map((e) => e.id),
        containsAll(['balance-increased-by-amount', 'version-incremented']),
      );
      expect(
        depositSig.ensures.map((e) => e.tag),
        containsAll([
          'ensures-balance-increased-by-amount',
          'ensures-version-incremented',
        ]),
      );
    });
  });

  // ── Part 4: temporal clauses (inert metadata) ────────────────────────────

  group('temporal clauses on the deposit SignatureDecl', () {
    final sig = depositContract.signatures.single;

    test('Timing/Lifecycle/Concurrency/Compensation stored + tagged', () {
      expect(sig.timing, isNotNull);
      expect(sig.timing!.within, equals(const Duration(seconds: 5)));
      expect(sig.timing!.elseFailure, equals('TimeoutFailure'));
      expect(sig.timing!.retry!.tag, equals('retry-StorageFailure'));
      expect(sig.timing!.tag, equals('timing'));

      expect(sig.lifecycle!.states, equals(['pending', 'settled', 'failed']));
      expect(sig.lifecycle!.tag, equals('lifecycle'));

      expect(sig.concurrency!.idempotentBy, equals('idempotencyKey'));
      expect(sig.concurrency!.atomic, isTrue);
      expect(sig.concurrency!.tag, equals('concurrency'));

      expect(sig.compensation!.onFailureRevert, equals('AccountState'));
      expect(sig.compensation!.tag, equals('compensation'));
    });
  });
}

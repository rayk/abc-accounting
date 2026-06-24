/// EAC proof for the `Ledger.deposit` boundary — the core spec loop.
///
///   RED  (seam-throw) — stub SUT → act throws UnimplementedError →
///                        evaluateCase returns SeamThrew.
///   GREEN              — reference SUT → act returns Either →
///                        evaluateCase returns CasePassed for both the
///                        positive and negative deposit cases.
///
/// The `bind(...)` suite at the bottom wires the REFERENCE implementation so
/// the runner sees GREEN test() calls. The stub/red demonstration lives only in
/// the evaluateCase assertions above it — a bind suite wired to the stub would
/// commit a red test, which is forbidden.
@TestOn('vm')
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:abc_accounting_contract/src/contracts/002_deposit.dart';
import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:abc_accounting_contract/src/switch.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

/// Result type for the deposit boundary.
typedef _R = Either<LedgerError, AccountState>;

/// POSITIVE case: deposit(Money(100)) on a fresh account → Right with
/// balance ≥ 0. The `when` closure is supplied per-evaluation so both the stub
/// and reference evaluations share one case shell with different act bodies.
Case<_R> _positiveCase({required Future<_R> Function() act}) => Case<_R>(
  description:
      'deposit(Money(100)) on fresh account succeeds with balance ≥ 0',
  given:
      'a fresh ledger opened with AccountId("eac-test"); '
      'deposit amount = Money(100)',
  when: act,
  then: succeeds<_R, AccountState>([balanceNonNeg]),
  tags: {'deposit', 'positive'},
);

/// NEGATIVE case: deposit(Money(0)) → Left(AmountMustBePositive).
Case<_R> _negativeCase({required Future<_R> Function() act}) => Case<_R>(
  description: 'deposit(Money(0)) is rejected with AmountMustBePositive',
  given:
      'a fresh ledger opened with AccountId("eac-test-neg"); '
      'deposit amount = Money(0)',
  when: act,
  then: rejects<_R, AmountMustBePositive>(depositAmountMustBePositive),
  tags: {'deposit', 'negative'},
);

/// Opens a ledger via the given [factory] and deposits [amount].
Future<_R> _depositVia(
  LedgerFactory factory,
  AccountId id,
  Money amount,
) async {
  final ledger = await factory(id);
  return ledger.deposit(amount);
}

void main() {
  group('depositContract drift', () {
    test('checkContractDrift passes', () {
      expect(() => checkContractDrift(depositContract), returnsNormally);
    });

    test('declares a single signature: deposit', () {
      expect(depositContract.signatures, hasLength(1));
    });

    test('deposit signature is rendered faithfully by abstractMethod', () {
      final depositSig = depositContract.signatures.single;
      printOnFailure('deposit SignatureDecl.function: ${depositSig.function}');
      printOnFailure(
        'deposit SignatureDecl.importable: ${depositSig.importable}',
      );
      expect(depositSig.function, contains('deposit'));
      expect(depositSig.importable, startsWith('package:'));
      // The intrinsic invariant and declared failure mode are wired.
      expect(depositSig.invariants, hasLength(1));
      expect(depositSig.failures, hasLength(1));
    });
  });

  group('stub SUT (UnimplementedLedger) — red-for-the-right-reason', () {
    test('positive case → SeamThrew (MISSING_SYMBOL)', () async {
      LedgerUnderTest.useStub();
      final stub = LedgerUnderTest.factory;
      final outcome = await evaluateCase<_R>(
        _positiveCase(
          act: () => _depositVia(
            stub,
            const AccountId('eac-stub-pos'),
            const Money(100),
          ),
        ),
      );
      printOnFailure('stub positive outcome: ${outcome.runtimeType}');
      expect(
        outcome,
        isA<SeamThrew>(),
        reason:
            'MISSING_SYMBOL: UnimplementedLedger.deposit throws '
            'UnimplementedError; evaluateCase must classify this as SeamThrew '
            '(red-for-the-right-reason), not as a test failure.',
      );
    });

    test('negative case → SeamThrew (MISSING_SYMBOL)', () async {
      LedgerUnderTest.useStub();
      final stub = LedgerUnderTest.factory;
      final outcome = await evaluateCase<_R>(
        _negativeCase(
          act: () => _depositVia(
            stub,
            const AccountId('eac-stub-neg'),
            const Money(0),
          ),
        ),
      );
      printOnFailure('stub negative outcome: ${outcome.runtimeType}');
      expect(
        outcome,
        isA<SeamThrew>(),
        reason:
            'MISSING_SYMBOL: UnimplementedLedger.deposit throws '
            'UnimplementedError; evaluateCase must classify this as SeamThrew.',
      );
    });
  });

  group('reference SUT (ReferenceLedger) — green', () {
    test('positive case → CasePassed', () async {
      final outcome = await evaluateCase<_R>(
        _positiveCase(
          act: () => _depositVia(
            ReferenceLedger.open,
            const AccountId('eac-ref-pos'),
            const Money(100),
          ),
        ),
      );
      printOnFailure('reference positive outcome: ${outcome.runtimeType}');
      expect(
        outcome,
        isA<CasePassed>(),
        reason:
            'ReferenceLedger.deposit(Money(100)) should return '
            'Right(AccountState) with balance ≥ 0, satisfying balanceNonNeg.',
      );
    });

    test('negative case → CasePassed (Left(AmountMustBePositive) matched)',
        () async {
      final outcome = await evaluateCase<_R>(
        _negativeCase(
          act: () => _depositVia(
            ReferenceLedger.open,
            const AccountId('eac-ref-neg'),
            const Money(0),
          ),
        ),
      );
      printOnFailure('reference negative outcome: ${outcome.runtimeType}');
      expect(
        outcome,
        isA<CasePassed>(),
        reason:
            'ReferenceLedger.deposit(Money(0)) should return '
            'Left(AmountMustBePositive), matching the declared '
            'depositAmountMustBePositive FailureMode.',
      );
    });
  });

  // bind() suite — real test-runner integration (GREEN, reference only).
  bind<_R>(
    depositContract,
    () {
      testCase(
        Case<_R>(
          description: 'deposit(Money(100)) on fresh account succeeds',
          given: 'fresh ledger AccountId("eac-bind-pos"), amount=Money(100)',
          when: () => _depositVia(
            ReferenceLedger.open,
            const AccountId('eac-bind-pos'),
            const Money(100),
          ),
          then: succeeds<_R, AccountState>([balanceNonNeg]),
          tags: {'deposit', 'positive', 'bind'},
        ),
      );

      testCase(
        Case<_R>(
          description:
              'deposit(Money(0)) is rejected with AmountMustBePositive',
          given: 'fresh ledger AccountId("eac-bind-neg"), amount=Money(0)',
          when: () => _depositVia(
            ReferenceLedger.open,
            const AccountId('eac-bind-neg'),
            Money.zero,
          ),
          then: rejects<_R, AmountMustBePositive>(depositAmountMustBePositive),
          tags: {'deposit', 'negative', 'bind'},
        ),
      );
    },
  );
}

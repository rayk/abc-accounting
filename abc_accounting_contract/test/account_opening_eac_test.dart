/// EAC (Executable Agent Contract) test for the Ledger.deposit boundary.
///
/// Proves the core spec loop:
///   RED  (seam-throw) — stub SUT → act throws UnimplementedError →
///                        evaluateCase returns SeamThrew.
///   GREEN              — reference SUT → act returns Either →
///                        evaluateCase returns CasePassed for both
///                        positive and negative deposit cases.
///
/// The bind(...) suite at the bottom wires the REFERENCE implementation
/// so the test runner sees GREEN test() calls. The stub/red demonstration
/// lives exclusively in the evaluateCase assertions above it — a bind suite
/// wired to the stub would commit a red test, which is forbidden.
@TestOn('vm')
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:abc_accounting_contract/src/account_opening.dart';
import 'package:abc_accounting_contract/src/reference_abc_accounting.dart';
import 'package:abc_accounting_contract/src/switch.dart';
import 'package:bnd_eac/contract.dart';
import 'package:bnd_eac/execution.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

// ── Shared result type alias ─────────────────────────────────────────────────

/// Result type for the deposit boundary.
typedef _R = Either<LedgerError, AccountState>;

// ── Case definitions ─────────────────────────────────────────────────────────

/// POSITIVE case: deposit(Money(100)) on a fresh account → Right(AccountState)
/// with balance ≥ 0.
///
/// The `when` closure is left null here; it is supplied per-evaluation so
/// both the stub and reference evaluations can share the same case shell but
/// swap in different act bodies.
Case<_R> _positiveCase({required Future<_R> Function() act}) => Case<_R>(
  description:
      'deposit(Money(100)) on fresh account succeeds with '
      'balance ≥ 0',
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

// ── Factory helpers ──────────────────────────────────────────────────────────

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
  // ── Drift guard ────────────────────────────────────────────────────────────

  group('accountOpeningContract drift', () {
    test('checkContractDrift passes', () {
      expect(() => checkContractDrift(accountOpeningContract), returnsNormally);
    });

    test('contract has two signatures (openAccount + deposit)', () {
      expect(accountOpeningContract.signatures, hasLength(2));
    });

    test('deposit signature is rendered faithfully by abstractMethod', () {
      final depositSig = accountOpeningContract.signatures.firstWhere(
        (s) => s.name == 'deposit',
      );
      // Print for the friction report.
      printOnFailure(
        'deposit SignatureDecl.function: ${depositSig.function}',
      );
      printOnFailure(
        'deposit SignatureDecl.importable: ${depositSig.importable}',
      );
      // abstractMethod<Ledger>(#deposit) must render the method name.
      expect(depositSig.function, contains('deposit'));
      // importable is forced via the `importable:` override to the ledger src.
      expect(depositSig.importable, startsWith('package:'));
      // Confirm invariants and failures are wired.
      expect(depositSig.invariants, hasLength(1));
      expect(depositSig.failures, hasLength(1));
    });
  });

  // ── RED-FOR-THE-RIGHT-REASON: stub → SeamThrew ────────────────────────────

  group('stub SUT (UnimplementedLedger) — red-for-the-right-reason', () {
    test(
      'positive case → SeamThrew (MISSING_SYMBOL: deposit not implemented)',
      () async {
        // Stub factory is the default; every method throws UnimplementedError.
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

        // ASSERT: the seam threw — this is red-for-the-right-reason.
        // The outcome MUST be SeamThrew, not CaseRejected or UnexpectedThrew.
        // SeamThrew signals MISSING_SYMBOL: the boundary stub has not been
        // implemented yet; the UnimplementedError propagates from the seam.
        expect(
          outcome,
          isA<SeamThrew>(),
          reason:
              'MISSING_SYMBOL: UnimplementedLedger.deposit throws '
              'UnimplementedError; evaluateCase must classify this as '
              'SeamThrew (red-for-the-right-reason), not as a test failure.',
        );
      },
    );

    test(
      'negative case → SeamThrew (MISSING_SYMBOL: deposit not implemented)',
      () async {
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
              'UnimplementedError; evaluateCase must classify this as '
              'SeamThrew (red-for-the-right-reason).',
        );
      },
    );
  });

  // ── GREEN: reference → CasePassed ─────────────────────────────────────────

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
      if (outcome is CaseRejected) {
        for (final f in outcome.failures) {
          printOnFailure('  rejection: actual=${f.actual}, which=${f.which}');
        }
      }

      expect(
        outcome,
        isA<CasePassed>(),
        reason:
            'ReferenceLedger.deposit(Money(100)) should return '
            'Right(AccountState) with balance ≥ 0, satisfying balanceNonNeg.',
      );
    });

    test(
      'negative case → CasePassed (Left(AmountMustBePositive) matched)',
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
        if (outcome is CaseRejected) {
          for (final f in outcome.failures) {
            printOnFailure('  rejection: actual=${f.actual}, which=${f.which}');
          }
        }

        expect(
          outcome,
          isA<CasePassed>(),
          reason:
              'ReferenceLedger.deposit(Money(0)) should return '
              'Left(AmountMustBePositive), which matches the declared '
              'depositAmountMustBePositive FailureMode.',
        );
      },
    );
  });

  // ── bind() suite — real test-runner integration (GREEN, reference only) ────
  //
  // This is the canonical integration path: bind() wires the contract to
  // package:test, producing green test() calls from the reference act.
  // The stub/red demonstration lives exclusively in the evaluateCase group
  // above — we never commit a bind suite wired to the stub.

  bind<_R>(
    accountOpeningContract,
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
              'deposit(Money(0)) is rejected with '
              'AmountMustBePositive',
          given: 'fresh ledger AccountId("eac-bind-neg"), amount=Money(0)',
          when: () => _depositVia(
            ReferenceLedger.open,
            const AccountId('eac-bind-neg'),
            const Money(0),
          ),
          then: rejects<_R, AmountMustBePositive>(depositAmountMustBePositive),
          tags: {'deposit', 'negative', 'bind'},
        ),
      );
    },
  );
}

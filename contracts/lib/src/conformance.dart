// This kit authors the spec against abc_accounting's *contract-only* barrel
// (the Ledger surface + vocabulary), so the implementation is genuinely out of
// scope while contracting — it cannot be named here, let alone depended on.
// Bind the LedgerFactory seam to a stub/reference/real SUT to run.
import 'package:abc_accounting/abc_accounting_contract.dart';
import 'package:bnd_eac/matchers.dart';
import 'package:checks/checks.dart';
import 'package:contracts_for_abc_accounting/src/ledger_checks.dart';
import 'package:contracts_for_abc_accounting/src/ledger_contract.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

/// A reusable, black-box **acceptance suite** written against the [Ledger]
/// *interface*, obtaining its system under test through a [LedgerFactory] seam.
///
/// Bind [factory] to [UnimplementedLedger] to author the spec before any
/// implementation exists (every scenario goes red with `UnimplementedError` —
/// the TDD "red"); bind it to a real implementation to make the spec pass. The
/// *same* suite later serves as a contract test for any future [Ledger].
///
/// The suite is also an **Executable Agent Contract**: [ledgerBrief] is
/// `install`ed in the outer `setUp`, and each scenario sub-group sets its
/// contract clause (`setRule`) and the domain types in scope (`filterTypes`)
/// in its own `setUp`. While green the brief is silent; on any failure the
/// `═══ BRIEF ═══` block surfaces — composed with the `package:checks` diff —
/// as the steering prompt for the implementer that must make the clause pass.
void ledgerAcceptance(String name, LedgerFactory factory) {
  group('Ledger acceptance: $name', () {
    late Ledger ledger;

    // Layer 1: the brief is in scope for every test's failure output.
    setUp(ledgerBrief.install);
    setUp(() async {
      ledger = await factory(const AccountId('sut'));
      Ledger.verify(ledger); // the SUT must `extend` the token-guarded base
    });
    tearDown(() => ledger.dispose());

    group('opening', () {
      setUp(
        () => ledgerBrief
          ..setRule('A fresh ledger opens at zero balance, version 0, '
              'status open.')
          ..filterTypes({AccountState}),
      );

      test('opens at zero balance, version 0, status open', () {
        // checkAllOf reports every violated invariant at once, so the
        // implementer fixes the whole opening state in a single pass.
        checkAllOf<AccountState>(ledger.state, [
          (Subject<AccountState> s) => s.balance.equals(Money.zero),
          (Subject<AccountState> s) => s.version.equals(const Version(0)),
          (Subject<AccountState> s) => s.status.equals(AccountStatus.open),
        ]);
      });
    });

    group('deposit', () {
      setUp(
        () => ledgerBrief
          ..setRule('deposit adds money; the new balance reflects the amount.')
          ..filterTypes({AccountState}),
      );

      test('deposit increases the balance', () async {
        check(await ledger.deposit(const Money(500)))
            .success
            .balance
            .equals(const Money(500));
      });
    });

    group('withdraw', () {
      setUp(
        () => ledgerBrief
          ..setRule('withdraw removes money when funds suffice.')
          ..filterTypes({AccountState}),
      );

      test('withdraw decreases the balance', () async {
        await ledger.deposit(const Money(500));
        check(await ledger.withdraw(const Money(120)))
            .success
            .balance
            .equals(const Money(380));
      });
    });

    group('overdraw', () {
      setUp(
        () => ledgerBrief
          ..setRule('A withdrawal exceeding the balance is rejected with '
              'InsufficientFunds and leaves state unchanged.')
          ..filterTypes({AccountState, InsufficientFunds}),
      );

      test('overdraw is rejected and leaves state unchanged', () async {
        await ledger.deposit(const Money(100));
        final before = ledger.state;
        check(await ledger.withdraw(const Money(1000)))
            .failure
            .isA<InsufficientFunds>();
        check(ledger.state).equals(before);
      });
    });

    group('daily limit', () {
      setUp(
        () => ledgerBrief
          ..setRule('A withdrawal beyond the daily limit is rejected with '
              'DailyLimitExceeded.')
          ..filterTypes({AccountState, DailyLimitExceeded}),
      );

      test('the daily limit is enforced', () async {
        await ledger.deposit(const Money(1000));
        await ledger.setDailyLimit(const Money(300));
        check(await ledger.withdraw(const Money(400)))
            .failure
            .isA<DailyLimitExceeded>();
      });
    });

    group('frozen', () {
      setUp(
        () => ledgerBrief
          ..setRule('A frozen account rejects money movement with '
              'AccountNotActive; freeze is idempotent.')
          ..filterTypes({AccountState, AccountNotActive}),
      );

      test('a frozen account rejects money movement (freeze is idempotent)',
          () async {
        await ledger.deposit(const Money(100));
        await ledger.freeze();
        await ledger.freeze(); // idempotent: no error, no change
        check(await ledger.deposit(const Money(10)))
            .failure
            .isA<AccountNotActive>();
      });
    });

    group('closed', () {
      setUp(
        () => ledgerBrief
          ..setRule('A closed account is terminal: status is closed and '
              'further movement is rejected with AccountNotActive.')
          ..filterTypes({AccountState, AccountNotActive}),
      );

      test('a closed account is terminal', () async {
        await ledger.closeAccount();
        check(ledger.state).status.equals(AccountStatus.closed);
        check(await ledger.deposit(const Money(10)))
            .failure
            .isA<AccountNotActive>();
      });
    });

    group('idempotency', () {
      setUp(
        () => ledgerBrief
          ..setRule('A keyed deposit is applied exactly once across retries '
              '(same key ⇒ same result).')
          ..filterTypes({AccountState}),
      );

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

    group('change feed', () {
      setUp(
        () => ledgerBrief
          ..setRule('Every successful state-changing op emits the new state '
              'exactly once, in order.')
          ..filterTypes({AccountState}),
      );

      test('a series of transactions yields the expected running balance',
          () async {
        final balances = <int>[];
        final sub =
            ledger.changes.listen((s) => balances.add(s.balance.minorUnits));

        await ledger.deposit(const Money(200)); // 200
        await ledger.deposit(const Money(50)); //  250
        await ledger.withdraw(const Money(30)); // 220
        await ledger.setDailyLimit(const Money(1000)); // 220 (limit set)
        await ledger.withdraw(const Money(20)); //  200
        await pumpEventQueue();

        check(ledger.state).balance.equals(const Money(200));
        await sub.cancel();
        // Every state-changing op emits exactly once, in order.
        check(balances).deepEquals([200, 250, 220, 220, 200]);
      });
    });
  });
}

/// A not-yet-implemented [Ledger]: every member throws `UnimplementedError`.
///
/// Because [Ledger] is a token-guarded base whose members default to throwing,
/// the stub is just the base with the token and **no overrides** — overriding
/// nothing *is* the unimplemented ledger. A [LedgerFactory] can yield it so the
/// suite runs in its pre-implementation, red state.
final class UnimplementedLedger extends Ledger {
  /// Creates the stub by passing only [Ledger.token] and overriding nothing.
  UnimplementedLedger() : super(token: Ledger.token);
}

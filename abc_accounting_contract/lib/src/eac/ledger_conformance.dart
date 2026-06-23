/// EAC ledger conformance suite — new-DSL, parameterised by factory.
///
/// Provides [eacLedgerConformance]: a single unified conformance suite
/// that is RED against `UnimplementedLedger` (every [evaluateCase]
/// call returns `SeamThrew`; `check(outcome).isA<CasePassed>()` fails)
/// and GREEN against `ReferenceLedger` (every assertion holds).
// ignore_for_file: avoid_catching_errors
library;

import 'dart:async';

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/execution.dart';
import 'package:checks/checks.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

// Internal result type alias for Ledger operations.
typedef _R = Either<LedgerError, AccountState>;

// Contract-level tag applied to every test in this suite.
const _c = 'contract-ledger';

// Timeout guard for stream tests so an under-emitting stub fails fast.
const _streamTimeout = Timeout(Duration(seconds: 15));

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Registers a complete new-DSL conformance suite for [Ledger] under
/// [group(name)], parameterised by [factory].
///
/// Coverage:
/// - **open** — initial state matches [AccountState.empty].
/// - **deposit** — happy path, [AmountMustBePositive],
///   [AccountNotActive] when frozen.
/// - **withdraw** — happy path, [InsufficientFunds],
///   [AmountMustBePositive].
/// - **setDailyLimit** — happy path, [DailyLimitExceeded].
/// - **freeze** — idempotent; blocks subsequent deposit.
/// - **closeAccount** — terminal; blocks deposit and withdraw.
/// - **idempotency** — keyed deposit applied exactly once.
/// - **change_feed** — ordered emissions via the stream harness.
/// - **lifecycle sequence** — deposit → freeze → deposit-on-frozen.
///
/// RED/GREEN contract:
/// Bound to `UnimplementedLedger` every operation throws
/// `UnimplementedError`; [evaluateCase] returns `SeamThrew`;
/// `check(outcome).isA<CasePassed>()` FAILS — that is the RED.
/// Bound to `ReferenceLedger` every assertion holds — GREEN.
void eacLedgerConformance(String name, LedgerFactory factory) {
  group(name, () {
    _openGroup(factory);
    _depositGroup(factory);
    _withdrawGroup(factory);
    _setDailyLimitGroup(factory);
    _freezeGroup(factory);
    _closeAccountGroup(factory);
    _idempotencyGroup(factory);
    _changeFeedGroup(factory);
    _lifecycleSequence(factory);
  });
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// Disposes the SUT safely for both the stub and the reference.
// UnimplementedLedger.dispose() throws; swallowing the error keeps the
// test failure focused on the check(outcome) assertion below.
Future<void> _dispose(Ledger sut) async {
  try {
    await sut.dispose();
  } on UnimplementedError {
    // Stub: dispose is not yet implemented — expected.
  }
}

// ---------------------------------------------------------------------------
// open
// ---------------------------------------------------------------------------

void _openGroup(LedgerFactory factory) {
  group('open', () {
    test(
      'initial state matches AccountState.empty',
      tags: {_c, 'sig-open', 'kind-positive'},
      () async {
        const id = AccountId('eac-open');
        final sut = await factory(id);
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'open: fresh ledger has empty initial state',
            given: 'factory(AccountId("eac-open")) creates a fresh ledger',
            when: () async => Either<LedgerError, AccountState>.of(sut.state),
            then: succeeds<_R, AccountState>([
              Rule<AccountState>(
                id: 'open-status',
                text: 'status is open',
                condition: (s) =>
                    s.has((a) => a.status, 'status').equals(AccountStatus.open),
              ),
              Rule<AccountState>(
                id: 'open-balance',
                text: 'balance is zero',
                condition: (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(0),
              ),
              Rule<AccountState>(
                id: 'open-version',
                text: 'version is 0',
                condition: (s) =>
                    s.has((a) => a.version.value, 'version.value').equals(0),
              ),
            ]),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// deposit
// ---------------------------------------------------------------------------

void _depositGroup(LedgerFactory factory) {
  group('deposit', () {
    test(
      'happy: deposit Money(100) on fresh account returns Right',
      tags: {_c, 'sig-deposit', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-dep-h'));
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'deposit Money(100) on fresh account',
            given: 'a fresh ledger; deposit amount = Money(100)',
            when: () => sut.deposit(const Money(100)),
            then: succeeds<_R, AccountState>([
              Rule<AccountState>(
                id: 'balance-100',
                text: 'balance equals the deposit amount',
                condition: (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(100),
              ),
              Rule<AccountState>(
                id: 'version-advanced',
                text: 'version advances from 0 to 1 after the deposit',
                condition: (s) =>
                    s.has((a) => a.version.value, 'version.value').equals(1),
              ),
            ]),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: zero amount returns Left(AmountMustBePositive)',
      tags: {_c, 'sig-deposit', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-dep-z'));
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'deposit Money(0) rejected',
            given: 'a fresh ledger; deposit amount = Money(0)',
            when: () => sut.deposit(Money.zero),
            then: rejects<_R, AmountMustBePositive>(
              const FailureMode<AmountMustBePositive>(
                when: 'amount is zero — not positive',
                steer:
                    'return Left(AmountMustBePositive(amount)); '
                    'leave state unchanged',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: negative amount returns Left(AmountMustBePositive)',
      tags: {_c, 'sig-deposit', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-dep-n'));
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'deposit Money(-5) rejected',
            given: 'a fresh ledger; deposit amount = Money(-5)',
            when: () => sut.deposit(const Money(-5)),
            then: rejects<_R, AmountMustBePositive>(
              const FailureMode<AmountMustBePositive>(
                when: 'amount is negative — not positive',
                steer: 'return Left(AmountMustBePositive(amount))',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: frozen account returns Left(AccountNotActive)',
      tags: {_c, 'sig-deposit', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-dep-fr'));
        // Setup: freeze the account first.  If the seam is not yet
        // implemented, freeze() throws; swallowed so evaluateCase
        // below surfaces the SeamThrew for the deposit call.
        try {
          await sut.freeze();
        } on UnimplementedError {
          // Stub: freeze not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'deposit on frozen account',
            given: 'a frozen ledger; deposit amount = Money(50)',
            when: () => sut.deposit(const Money(50)),
            then: rejects<_R, AccountNotActive>(
              const FailureMode<AccountNotActive>(
                when: 'account status is frozen — canTransact is false',
                steer:
                    'return Left(AccountNotActive(status)); '
                    'leave state unchanged',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// withdraw
// ---------------------------------------------------------------------------

void _withdrawGroup(LedgerFactory factory) {
  group('withdraw', () {
    test(
      'happy: withdraw within balance returns Right',
      tags: {_c, 'sig-withdraw', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-wdh'));
        // Setup: fund the account.
        try {
          await sut.deposit(const Money(1000));
        } on UnimplementedError {
          // Stub: deposit not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'withdraw Money(200) from funded account',
            given: 'ledger with balance 1000; withdraw = Money(200)',
            when: () => sut.withdraw(const Money(200)),
            then: succeeds<_R, AccountState>([
              Rule<AccountState>(
                id: 'balance-800',
                text: 'balance equals 1000 - 200 = 800',
                condition: (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(800),
              ),
            ]),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: overdraw returns Left(InsufficientFunds)',
      tags: {_c, 'sig-withdraw', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-wdi'));
        // Setup: fund with 100.
        try {
          await sut.deposit(const Money(100));
        } on UnimplementedError {
          // Stub: deposit not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'withdraw Money(500) with balance 100',
            given: 'ledger with balance 100; withdraw = Money(500)',
            when: () => sut.withdraw(const Money(500)),
            then: rejects<_R, InsufficientFunds>(
              const FailureMode<InsufficientFunds>(
                when: 'withdrawal amount exceeds current balance',
                steer: 'return Left(InsufficientFunds(balance, requested))',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: zero amount returns Left(AmountMustBePositive)',
      tags: {_c, 'sig-withdraw', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-wdz'));
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'withdraw Money(0) rejected',
            given: 'a fresh ledger; withdraw amount = Money(0)',
            when: () => sut.withdraw(Money.zero),
            then: rejects<_R, AmountMustBePositive>(
              const FailureMode<AmountMustBePositive>(
                when: 'withdrawal amount is zero — not positive',
                steer: 'return Left(AmountMustBePositive(amount))',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: negative amount returns Left(AmountMustBePositive)',
      tags: {_c, 'sig-withdraw', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-wdn'));
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'withdraw Money(-5) rejected',
            given: 'a fresh ledger; withdraw amount = Money(-5)',
            when: () => sut.withdraw(const Money(-5)),
            then: rejects<_R, AmountMustBePositive>(
              const FailureMode<AmountMustBePositive>(
                when: 'withdrawal amount is negative — not positive',
                steer: 'return Left(AmountMustBePositive(amount))',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// setDailyLimit
// ---------------------------------------------------------------------------

void _setDailyLimitGroup(LedgerFactory factory) {
  group('setDailyLimit', () {
    test(
      'happy: setDailyLimit returns Right',
      tags: {_c, 'sig-setDailyLimit', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-sdl-h'));
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'setDailyLimit Money(500) on fresh account',
            given: 'a fresh ledger; limit = Money(500)',
            when: () => sut.setDailyLimit(const Money(500)),
            then: succeeds<_R, AccountState>([
              Rule<AccountState>(
                id: 'daily-limit-stored',
                text: 'the daily limit is stored as Money(500)',
                condition: (s) => s
                    .has(
                      (a) => a.dailyLimit.toNullable()?.minorUnits ?? -1,
                      'dailyLimit.minorUnits',
                    )
                    .equals(500),
              ),
            ]),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'happy: withdrawal within the daily limit succeeds',
      tags: {_c, 'sig-setDailyLimit', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-dl-within'));
        // Setup: fund 1000, set a daily limit of 100.
        try {
          await sut.deposit(const Money(1000));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        try {
          await sut.setDailyLimit(const Money(100));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'withdraw Money(80) within daily limit Money(100)',
            given: 'balance 1000, daily limit 100; withdraw = Money(80)',
            when: () => sut.withdraw(const Money(80)),
            then: succeeds<_R, AccountState>([
              Rule<AccountState>(
                id: 'within-limit-balance',
                text: 'balance is 1000 - 80 = 920 after the withdrawal',
                condition: (s) => s
                    .has(
                      (a) => a.balance.minorUnits,
                      'balance.minorUnits',
                    )
                    .equals(920),
              ),
            ]),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: withdraw over daily limit returns Left(DailyLimitExceeded)',
      tags: {_c, 'sig-setDailyLimit', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-dle'));
        // Setup: fund and set a daily limit of Money(100).
        try {
          await sut.deposit(const Money(1000));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        try {
          await sut.setDailyLimit(const Money(100));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'withdraw Money(500) exceeds daily limit Money(100)',
            given: 'balance 1000, daily limit 100; withdraw = Money(500)',
            when: () => sut.withdraw(const Money(500)),
            then: rejects<_R, DailyLimitExceeded>(
              const FailureMode<DailyLimitExceeded>(
                when: 'withdrawal would exceed the configured daily limit',
                steer: 'return Left(DailyLimitExceeded(limit, attempted))',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// freeze
// ---------------------------------------------------------------------------

void _freezeGroup(LedgerFactory factory) {
  group('freeze', () {
    test(
      'idempotent: calling freeze twice leaves account frozen',
      tags: {_c, 'sig-freeze', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-fr-id'));
        // First freeze (setup).
        try {
          await sut.freeze();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        // Second freeze: evaluateCase asserts it still returns Right.
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'second freeze on frozen account is idempotent',
            given: 'an already-frozen ledger',
            when: sut.freeze,
            then: succeeds<_R, AccountState>([
              Rule<AccountState>(
                id: 'still-frozen',
                text: 'status remains frozen after second freeze',
                condition: (s) => s
                    .has((a) => a.status, 'status')
                    .equals(AccountStatus.frozen),
              ),
            ]),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: frozen account blocks deposit with AccountNotActive',
      tags: {_c, 'sig-freeze', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-fr-bl'));
        // Setup: freeze the account.
        try {
          await sut.freeze();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'deposit on frozen account is rejected',
            given: 'a frozen ledger; deposit amount = Money(50)',
            when: () => sut.deposit(const Money(50)),
            then: rejects<_R, AccountNotActive>(
              const FailureMode<AccountNotActive>(
                when: 'account is frozen — canTransact is false',
                steer: 'return Left(AccountNotActive(status))',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: frozen account blocks withdraw with AccountNotActive',
      tags: {_c, 'sig-freeze', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-fr-wd'));
        // Setup: fund, then freeze.
        try {
          await sut.deposit(const Money(100));
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        try {
          await sut.freeze();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'withdraw on frozen account is rejected',
            given: 'a frozen ledger with balance 100; withdraw = Money(50)',
            when: () => sut.withdraw(const Money(50)),
            then: rejects<_R, AccountNotActive>(
              const FailureMode<AccountNotActive>(
                when: 'account is frozen — canTransact is false',
                steer: 'return Left(AccountNotActive(status))',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// closeAccount
// ---------------------------------------------------------------------------

void _closeAccountGroup(LedgerFactory factory) {
  group('closeAccount', () {
    test(
      'terminal: closeAccount sets status to closed',
      tags: {_c, 'sig-closeAccount', 'kind-positive'},
      () async {
        final sut = await factory(const AccountId('eac-ca-t'));
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'closeAccount on open account returns Right(closed)',
            given: 'a fresh open ledger',
            when: sut.closeAccount,
            then: succeeds<_R, AccountState>([
              Rule<AccountState>(
                id: 'status-closed',
                text: 'status is closed after closeAccount',
                condition: (s) => s
                    .has((a) => a.status, 'status')
                    .equals(AccountStatus.closed),
              ),
            ]),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: closed account blocks deposit with AccountNotActive',
      tags: {_c, 'sig-closeAccount', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-ca-bd'));
        // Setup: close the account.
        try {
          await sut.closeAccount();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'deposit on closed account is rejected',
            given: 'a closed ledger; deposit amount = Money(10)',
            when: () => sut.deposit(const Money(10)),
            then: rejects<_R, AccountNotActive>(
              const FailureMode<AccountNotActive>(
                when: 'account is closed — canTransact is false',
                steer: 'return Left(AccountNotActive(status))',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );

    test(
      'negative: closed account blocks withdraw with AccountNotActive',
      tags: {_c, 'sig-closeAccount', 'kind-negative'},
      () async {
        final sut = await factory(const AccountId('eac-ca-bw'));
        // Setup: close the account.
        try {
          await sut.closeAccount();
        } on UnimplementedError {
          // Stub: not yet implemented — expected.
        }
        final outcome = await evaluateCase(
          Case<_R>(
            description: 'withdraw on closed account is rejected',
            given: 'a closed ledger; withdraw amount = Money(10)',
            when: () => sut.withdraw(const Money(10)),
            then: rejects<_R, AccountNotActive>(
              const FailureMode<AccountNotActive>(
                when: 'account is closed — canTransact is false',
                steer: 'return Left(AccountNotActive(status))',
              ),
            ),
          ),
        );
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// idempotency
// ---------------------------------------------------------------------------

void _idempotencyGroup(LedgerFactory factory) {
  group('idempotency', () {
    test(
      'keyed deposit applied exactly once across retries',
      tags: {_c, 'sig-deposit', 'kind-positive'},
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
          Case<_R>(
            description: 'replay of keyed deposit returns cached state',
            given: 'balance == 100 after first keyed deposit; same key',
            when: () => sut.deposit(const Money(100), idempotencyKey: key),
            then: succeeds<_R, AccountState>([
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
        await _dispose(sut);
        check(outcome).isA<CasePassed>();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// change_feed (stream harness)
// ---------------------------------------------------------------------------

void _changeFeedGroup(LedgerFactory factory) {
  group('changeFeed', () {
    test(
      'deposit 100 then 50 emits balances 100, 150 in order',
      tags: {_c, 'sig-changes', 'kind-stream'},
      timeout: _streamTimeout,
      () async {
        final sut = await factory(const AccountId('eac-cf'));
        final outcome = await evaluateStreamCase(
          StreamCase<AccountState>(
            description: 'deposit 100 then 50 emits 100 then 150',
            given: 'a fresh ledger; two deposits: Money(100), Money(50)',
            // Safe stream factory: if the seam is not yet implemented,
            // sut.changes throws UnimplementedError synchronously.
            // Returning an empty stream here lets the act run and
            // surface the UnimplementedError as StreamSeamThrew.
            stream: () {
              try {
                return sut.changes;
              } on UnimplementedError {
                return const Stream<AccountState>.empty();
              }
            },
            // SYNCHRONOUS unawaited emission idiom (see phase4 notes):
            // subscribe before the act so the StreamQueue buffer
            // captures every broadcast emission.
            act: () async {
              unawaited(sut.deposit(const Money(100)));
              unawaited(sut.deposit(const Money(50)));
              // dispose() closes the changes stream so the queue
              // terminates cleanly.
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

// ---------------------------------------------------------------------------
// lifecycle sequence
// ---------------------------------------------------------------------------

void _lifecycleSequence(LedgerFactory factory) {
  testSequence<Ledger>(
    description: 'lifecycle: deposit → freeze → deposit-on-frozen rejects',
    sut: () => factory(const AccountId('eac-seq')),
    steps: [
      Step('deposit Money(100) succeeds', (l) async {
        final r = await l.deposit(const Money(100));
        check(r.isRight()).isTrue();
      }),
      Step('freeze succeeds', (l) async {
        final r = await l.freeze();
        check(r.isRight()).isTrue();
      }),
      Step(
        'deposit on frozen account rejects AccountNotActive',
        (l) async {
          final r = await l.deposit(const Money(50));
          r.match(
            (e) => check(e).isA<AccountNotActive>(),
            (_) => fail('expected Left(AccountNotActive)'),
          );
        },
      ),
    ],
    tags: {_c, 'sig-lifecycle'},
  );
}

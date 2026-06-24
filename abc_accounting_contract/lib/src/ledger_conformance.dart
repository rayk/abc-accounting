/// EAC ledger conformance suite — new-DSL, parameterised by factory.
///
/// A thin aggregator over the per-behaviour case files in `contracts/` and the
/// lifecycle scenario in `scenarios/`. RED against `UnimplementedLedger` (every
/// case is `SeamThrew`) and GREEN against `ReferenceLedger`.
///
/// Each behaviour's declaration and its cases live together in one numbered
/// file (`contracts/001_open.dart` … `008_change_feed.dart`); this file only
/// composes them under a single named group.
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:test/test.dart';

import 'contracts/001_open.dart';
import 'contracts/002_deposit.dart';
import 'contracts/003_withdraw.dart';
import 'contracts/004_set_daily_limit.dart';
import 'contracts/005_freeze.dart';
import 'contracts/006_close.dart';
import 'contracts/007_idempotency.dart';
import 'contracts/008_change_feed.dart';
import 'scenarios/001_account_lifecycle.dart';

/// Registers a complete new-DSL conformance suite for [Ledger] under
/// `group(name)`, parameterised by [factory].
///
/// Coverage:
/// - **open** — initial state matches [AccountState.empty].
/// - **deposit** — happy path, [AmountMustBePositive], [AccountNotActive].
/// - **withdraw** — happy path, [InsufficientFunds], [AmountMustBePositive].
/// - **setDailyLimit** — happy path, within-limit, [DailyLimitExceeded].
/// - **freeze** — idempotent; blocks deposit/withdraw.
/// - **closeAccount** — terminal; blocks deposit/withdraw.
/// - **idempotency** — keyed deposit applied exactly once.
/// - **change_feed** — ordered emissions via the stream harness.
/// - **lifecycle** — deposit → freeze → deposit-on-frozen sequence.
///
/// RED/GREEN contract: bound to `UnimplementedLedger` every operation throws
/// `UnimplementedError`, so each case is `SeamThrew` and the suite is RED;
/// bound to `ReferenceLedger` every assertion holds and the suite is GREEN.
void eacLedgerConformance(String name, LedgerFactory factory) {
  group(name, () {
    openCases(factory);
    depositCases(factory);
    withdrawCases(factory);
    setDailyLimitCases(factory);
    freezeCases(factory);
    closeCases(factory);
    idempotencyCases(factory);
    changeFeedCases(factory);
    accountLifecycleScenario(factory);
  });
}

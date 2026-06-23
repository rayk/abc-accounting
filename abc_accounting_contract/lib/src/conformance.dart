/// Thin aggregator — no test logic of its own.
///
/// Wires all contract and scenario functions into one `ledgerAcceptance` entry
/// point. Callers (test drivers and [LedgerUnderTest]) bind a [LedgerFactory]
/// and invoke this once.
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:test/test.dart';

import 'brief/ledger_brief.dart';
import 'contracts/001_open.dart';
import 'contracts/002_deposit.dart';
import 'contracts/003_withdraw.dart';
import 'contracts/004_daily_limit.dart';
import 'contracts/005_freeze.dart';
import 'contracts/006_close_account.dart';
import 'contracts/007_idempotency.dart';
import 'contracts/008_change_feed.dart';
import 'scenarios/001_account_lifecycle.dart';

/// A reusable, black-box **acceptance suite** written against the [Ledger]
/// *interface*, obtaining its system under test through a [LedgerFactory] seam.
///
/// Bind [factory] to [UnimplementedLedger] to author the spec before any
/// implementation exists; bind it to a real implementation to make the spec
/// pass. The *same* suite later serves as a contract test for any future
/// [Ledger].
void ledgerAcceptance(String name, LedgerFactory factory) {
  group(name, () {
    // setUpAll so install runs before any inner setUpAll (which calls
    // setRule/filterTypes). setUp would run AFTER inner setUpAll, which
    // means filterTypes would be called before install — causing an error.
    setUpAll(ledgerBrief.install);

    openContract(factory);
    depositContract(factory);
    withdrawContract(factory);
    setDailyLimitContract(factory);
    freezeContract(factory);
    closeAccountContract(factory);
    idempotencyContract(factory);
    changeFeedContract(factory);
    accountLifecycleScenario(factory);
  });
}

// UnimplementedLedger is defined in abc_accounting/lib/src/contract/ledger.dart
// and exported via package:abc_accounting/abc_accounting.dart — do not redefine here.

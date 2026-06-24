/// Ledger type-vocabulary contract (`000`).
///
/// Registers the core domain types of the abc_accounting Ledger boundary,
/// correcting mirror erasure of extension types via `typeOverrides` and
/// `structure`. The `Contract.signature` surface is NOT used here — type
/// registration only. The behaviour contracts (`001_open.dart` …
/// `008_change_feed.dart`) `dependsOn` this one for their shared vocabulary.
///
/// **Name collision note.** `package:abc_accounting` exports a domain
/// [abc.Version] extension type (`Version(int value)`). The engine's semver
/// triple is named [ContractVersion] (`ContractVersion(int major, int minor,
/// int patch)`), so there is no collision. The `abc` prefix is kept for
/// clarity and to scope all domain types.
library;

import 'package:abc_accounting/abc_accounting.dart' as abc;
import 'package:bnd_eac/contract.dart';

/// Contract registering the core vocabulary types for the abc_accounting
/// Ledger boundary.
///
/// Covers the four types named in the spec: [abc.AccountStatus],
/// [abc.Money], [abc.AccountState] (with `typeOverrides` for every
/// extension-typed field), and [abc.InsufficientFunds].
///
/// Call [checkContractDrift] after construction to validate the override
/// keys against live mirror reflection of each type.
final ledgerTypeContract =
    Contract(
        name: 'ledger_type_contract',
        version: const ContractVersion(0, 1, 0),
        purpose:
            'Core vocabulary types for the abc_accounting Ledger boundary.',
        tags: {'ledger', 'types'},
      )
      // ── AccountStatus ──
      // A plain enum — mirrors reflect it correctly; no overrides needed.
      ..type<abc.AccountStatus>(
        describe:
            'Lifecycle state of an account: open, frozen, or closed. '
            'The canTransact field gates money movement.',
      )
      // ── Money ──
      // Extension type over int: mirrors erase it to int; importable will be
      // the unresolved sentinel. structure carries the authoritative shape.
      ..type<abc.Money>(
        describe:
            'Integer minor units (e.g. cents). '
            'Zero-cost extension type over int; erased to int by mirrors.',
        structure: 'Money(int minorUnits)',
      )
      // ── AccountState ──
      // final class — mirrors reflect it, but extension-typed fields (id,
      // balance, dailyLimit, withdrawnToday, version) are erased to String/int.
      // typeOverrides restores the authored names; structure carries the full
      // authoritative constructor shape including Option<Money> for dailyLimit.
      ..type<abc.AccountState>(
        describe:
            'Immutable read-model of an account: a left fold over its '
            'event log. Never mutated; evolving produces a new instance.',
        structure:
            'AccountState({'
            'required AccountId id, '
            'required AccountStatus status, '
            'required Money balance, '
            'required Option<Money> dailyLimit, '
            'required Money withdrawnToday, '
            'required Version version '
            '})',
        typeOverrides: {
          'id': 'AccountId',
          'balance': 'Money',
          'dailyLimit': 'Option<Money>',
          'withdrawnToday': 'Money',
          'version': 'Version',
        },
      )
      // ── InsufficientFunds ──
      // final class extending sealed LedgerError. Constructor params are both
      // Money (erased to int by mirrors); typeOverrides restores them.
      ..type<abc.InsufficientFunds>(
        describe:
            'Withdrawal attempted when balance is insufficient. '
            'Carries both the current balance and the requested amount.',
        typeOverrides: {
          'balance': 'Money',
          'requested': 'Money',
        },
      );

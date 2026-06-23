/// Boundary scaffold for the [Ledger] contract and the [ContractBrief] that
/// steers an implementer against it.
///
/// In EAC terms this file is the immutable *Boundary Scaffold* (owned by the
/// test architect): it declares the surface the conformance suite drives and
/// authors the brief that surfaces — on a failing run — as the implementer
/// ALCA's steering prompt.
///
/// Note the altitude adaptation: bnd_eac's [ContractBrief] models a single
/// function-under-test, whereas [Ledger] is a multi-method object boundary
/// obtained black-box through a [LedgerFactory]. So one brief represents the
/// whole boundary (its `Function:` line shows the representative money-moving
/// operation) and the conformance suite refines it per scenario with
/// `setRule` / `filterTypes`.
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:bnd_eac/brief.dart';
import 'package:fpdart/fpdart.dart';

import '../types/type_config.dart';

/// Representative signature for the ledger's money-moving operations
/// ([Ledger.deposit] and [Ledger.withdraw] share its shape), used purely for
/// [ContractBrief] mirror extraction — it is reflected, never called.
///
/// `dart:mirrors` cannot see through `extension type`s, so the brief's
/// rendered `Function:` line shows the *representation* types (`int amount`
/// for [Money], `Option<String>` for `Option<CommandId>`). The real newtypes
/// are restored in the brief's `TYPES:` / `FIELD-FORMATS:` sections via
/// `typeOverrides`. Throwing here mirrors the token-guarded [Ledger] base,
/// whose unimplemented members throw `UnimplementedError` the same way.
LedgerResult ledgerOperation(
  Money amount, {
  Option<CommandId> idempotencyKey = const None(),
}) =>
    throw UnimplementedError('boundary scaffold — reflected, never run');

/// The steering brief for the [Ledger] contract: authored once here, then
/// `install`ed by the conformance suite's outer `setUp` and refined per
/// scenario with `setRule` / `filterTypes`.
///
/// Invisible while green; on any failure within the suite it renders the
/// `═══ BRIEF ═══` block (target file, signature, current contract, the
/// in-scope domain types, and their field formats) as the implementer's
/// prompt.
final ledgerBrief = ContractBrief(
  signatureRef: ledgerOperation,
  function: ledgerOperation,
)
  ..domainType<AccountState>(
    typeOverrides: accountStateOverrides,
    formatNotes: accountStateFormatNotes,
  )
  ..domainType<InsufficientFunds>(
    typeOverrides: insufficientFundsOverrides,
  )
  ..domainType<DailyLimitExceeded>(
    typeOverrides: dailyLimitExceededOverrides,
  )
  ..domainType<AccountNotActive>();

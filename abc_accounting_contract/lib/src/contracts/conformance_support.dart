/// Shared helpers for the per-behaviour conformance case files
/// (`001_open.dart` … `008_change_feed.dart`) and the lifecycle scenario.
// ignore_for_file: avoid_catching_errors
library;

import 'package:abc_accounting/abc_accounting.dart';
import 'package:fpdart/fpdart.dart';

/// The settled result type of every [Ledger] operation: either a typed
/// [LedgerError] (`Left`) or the new [AccountState] (`Right`).
typedef LedgerEither = Either<LedgerError, AccountState>;

/// Disposes [sut] safely for both the stub and the reference.
///
/// `UnimplementedLedger.dispose()` throws; swallowing the error keeps a RED
/// run focused on the `check(outcome)` assertion rather than the teardown.
Future<void> disposeQuietly(Ledger sut) async {
  try {
    await sut.dispose();
  } on UnimplementedError {
    // Stub: dispose is not yet implemented — expected during the RED phase.
  }
}

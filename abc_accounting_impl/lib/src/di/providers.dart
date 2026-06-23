import 'package:riverpod/riverpod.dart';

import '../api/account_ledger.dart';
import 'package:abc_accounting/abc_accounting.dart';
import '../effects/clock.dart';
import '../effects/env.dart';
import '../effects/id_generator.dart';
import '../effects/repository.dart';

/// The user-override seam, expressed as Riverpod providers.
///
/// Each provider supplies a default implementation of one of the public
/// interfaces. Users override any of them in a `ProviderContainer` /
/// `ProviderScope` without touching this library — the same mechanism the tests
/// use to inject deterministic fakes:
///
/// ```dart
/// ProviderContainer(overrides: [
///   clockProvider.overrideWithValue(FixedClock(...)),
///   ledgerRepositoryProvider.overrideWithValue(MyDbRepository(...)),
/// ]);
/// ```

/// The wall clock. Override with a fixed clock for determinism.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Correlation-id source, derived from the [clockProvider].
final idGeneratorProvider = Provider<IdGenerator>(
    (ref) => MonotonicIdGenerator(ref.watch(clockProvider)));

/// The persistence boundary. Override with a real database implementation.
final ledgerRepositoryProvider =
    Provider<LedgerRepository>((ref) => InMemoryLedgerRepository());

/// Assembles the [LedgerEnv] record from the individual dependency providers.
final ledgerEnvProvider = Provider<LedgerEnv>(
  (ref) => (
    repo: ref.watch(ledgerRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

/// A live [Ledger] per [AccountId] — the public entry point.
///
/// Demonstrated Dart/Riverpod feature: a **`FutureProvider.family`** —
/// parameterized (by account id) and asynchronous (the ledger hydrates from the
/// repository). Disposal is wired to the provider's lifecycle. Override the
/// dependency providers above to inject fakes or a real backend.
final ledgerProvider =
    FutureProvider.family<Ledger, AccountId>((ref, id) async {
  final env = ref.watch(ledgerEnvProvider);
  final ledger = await AccountLedger.open(env, id);
  ref.onDispose(ledger.dispose);
  return ledger;
});

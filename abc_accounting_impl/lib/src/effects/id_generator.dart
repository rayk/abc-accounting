import 'package:abc_accounting/abc_accounting.dart';
import 'clock.dart';

/// A source of fresh correlation ids.
///
/// The second nondeterminism seam (alongside [Clock]). When a command carries no
/// idempotency key, the use-case asks the [IdGenerator] for a unique [CommandId]
/// to record as the event's cause — so every event is correlatable, while only
/// user-supplied keys enable de-duplication. Tests inject a deterministic
/// sequence generator.
abstract interface class IdGenerator {
  CommandId next();
}

/// Production generator: time + a monotonic counter, so ids are unique within a
/// process even when the clock has coarse resolution.
final class MonotonicIdGenerator implements IdGenerator {
  MonotonicIdGenerator(this._clock);

  final Clock _clock;
  int _seq = 0;

  @override
  CommandId next() =>
      CommandId('cmd-${_clock.now().microsecondsSinceEpoch}-${_seq++}');
}

/// A source of "now".
///
/// Demonstrated Dart feature: an **`abstract interface class`** — a pure
/// contract that can only be *implemented* (not extended or instantiated). It is
/// the first testability seam: the pure core never calls `DateTime.now()`, so
/// tests inject a fixed clock for fully deterministic timestamps.
abstract interface class Clock {
  DateTime now();
}

/// The production clock, reading the wall clock.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

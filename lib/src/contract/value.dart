/// Structural value-equality, expressed once.
///
/// Mixed into every immutable domain type so that two values are equal iff
/// their [props] are equal — no hand-written `==`/`hashCode` per class, no code
/// generation, no dependency. This is the elegant, DRY alternative to repeating
/// equality boilerplate (or pulling in `equatable`) across a dozen value types.
///
/// Demonstrated Dart feature: a **mixin** used as a reusable capability.
mixin Value {
  /// The fields that define this value's identity, in a stable order.
  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Value &&
          runtimeType == other.runtimeType &&
          _propsEqual(props, other.props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(props));

  @override
  String toString() => '$runtimeType${props}';
}

bool _propsEqual(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

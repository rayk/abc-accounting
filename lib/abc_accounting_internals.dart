/// `abc_accounting` — **advanced / internal** surface.
///
/// A superset of the tight public API (`abc_accounting.dart`, re-exported below)
/// that additionally exposes the pure functional core: the decider, the
/// evolver, the typeclass algebra, the accumulating validator, the command ADT,
/// the `ReaderTaskEither` use-cases, the extensible `EventStore` template, and
/// the stream/sink `AccountController` engine.
///
/// These are *not* part of the usage-based API. They are imported by white-box
/// unit tests (and by power users who want to compose at the functional level),
/// while ordinary consumers and the extension examples depend only on the tight
/// `package:abc_accounting/abc_accounting.dart`.
library;

export 'abc_accounting.dart';

// Pure core.
export 'src/core/algebra.dart';
export 'src/core/decide.dart';
export 'src/core/event_store.dart';
export 'src/core/evolve.dart';
export 'src/core/typedefs.dart';
export 'src/core/validation.dart';

// The internal command ADT (the Value mixin it uses comes from the contract).
export 'src/domain/commands.dart';

// Functional use-cases (ReaderTaskEither) and the effect alias.
export 'src/effects/env.dart' show LedgerEffect;
export 'src/effects/use_cases.dart';

// The stream/sink runtime engine behind the facade.
export 'src/runtime/controller.dart';

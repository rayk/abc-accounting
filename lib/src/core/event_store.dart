import '../contract/contract.dart';
import 'evolve.dart';

/// A reusable event-sourcing template.
///
/// Demonstrated Dart feature: an **`abstract class` meant to be extended** (as
/// opposed to an `abstract interface class`, which is implement-only). It mixes
/// a concrete *template method* ([replay]) with abstract *hooks* ([initial],
/// [apply]) that subclasses fill in. This is extension **Vector 1**: a subclass
/// keeps the [replay] signature but supplies a different process for evolving
/// state — exactly how `example/extensions/v1_substitution.dart` builds on it.
abstract class EventStore<S, E> {
  const EventStore();

  /// The seed state, before any event.
  S get initial;

  /// Fold a single event into the state (the hook subclasses implement).
  S apply(S state, E event);

  /// Rebuild state from [events] — the template method, defined once in terms
  /// of the hooks. Subclasses may override to change the *process* (e.g. fold
  /// from a snapshot) without changing this signature.
  S replay(Iterable<E> events) => events.fold(initial, apply);
}

/// The concrete account event store, wiring the generic template to the
/// account domain by delegating to the pure [applyEvent].
final class AccountEventStore extends EventStore<AccountState, LedgerEvent> {
  const AccountEventStore(this.id);

  final AccountId id;

  @override
  AccountState get initial => AccountState.empty(id);

  @override
  AccountState apply(AccountState state, LedgerEvent event) =>
      applyEvent(state, event);
}

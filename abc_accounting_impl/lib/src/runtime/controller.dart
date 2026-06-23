import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../domain/commands.dart';
import 'package:abc_accounting/abc_accounting.dart';
import '../effects/env.dart';
import '../effects/use_cases.dart';

/// The imperative shell around the functional core: a live, **stateful**
/// account that ingests commands through a [Sink] and emits state through a
/// [Stream].
///
/// State is held in an fpdart [IORef] — a mutable cell that is read and written
/// *inside the `IO` monad*, then run at the boundary. The shell stays thin: all
/// decision logic lives in the pure core and the [handle] use-case; this class
/// only sequences effects and publishes results.
final class AccountController {
  AccountController._(this._env, this._id, this._state, this._out);

  final LedgerEnv _env;
  final AccountId _id;
  final IORef<AccountState> _state;
  final StreamController<AccountState> _out;

  /// Serializes command application so the stream reflects a single, ordered
  /// history even when commands arrive concurrently through the [Sink].
  Future<void> _tail = Future<void>.value();

  /// Build a controller, hydrating its state from the repository.
  static Future<AccountController> create(LedgerEnv env, AccountId id) async {
    final loaded = await currentState(id).run(env);
    final initial = loaded.getOrElse((_) => AccountState.empty(id));
    final ref = IORef.create(initial).run();
    final out = StreamController<AccountState>.broadcast();
    return AccountController._(env, id, ref, out);
  }

  /// The account this controller drives.
  AccountId get id => _id;

  /// The read-model feed: emits the new state after each *successful*,
  /// state-changing command. Broadcast, so multiple observers can subscribe.
  Stream<AccountState> get states => _out.stream;

  /// A synchronous snapshot of the current state, read from the [IORef].
  AccountState get current => _state.read().run();

  /// Apply [command] and await the typed result. The request/response face of
  /// the controller (the async, awaitable counterpart to [commands]).
  Future<Either<LedgerError, AccountState>> send(LedgerCommand command) async {
    final result = await handle(_id, command).run(_env);
    return result.map((next) {
      final changed = next != _state.read().run();
      _state.write(next).run();
      // `states` is a change-feed: idempotent no-ops do not re-emit.
      if (changed && !_out.isClosed) _out.add(next);
      return next;
    });
  }

  /// The ingest point as a [Sink]: fire-and-forget command submission. Commands
  /// are applied in arrival order; observe results via [states].
  Sink<LedgerCommand> get commands => _CommandSink(this);

  void _enqueue(LedgerCommand command) {
    _tail = _tail.then((_) => send(command));
  }

  /// Drain in-flight commands and close the stream.
  Future<void> dispose() async {
    await _tail;
    await _out.close();
  }
}

/// Adapts the controller's [AccountController.send] to the [Sink] interface.
final class _CommandSink implements Sink<LedgerCommand> {
  _CommandSink(this._controller);

  final AccountController _controller;

  @override
  void add(LedgerCommand data) => _controller._enqueue(data);

  @override
  void close() {}
}

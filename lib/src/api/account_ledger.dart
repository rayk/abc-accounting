import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../domain/commands.dart';
import '../contract/contract.dart';
import '../effects/env.dart';
import '../runtime/controller.dart';

/// The concrete [Ledger] — the system under test for the acceptance suite.
///
/// A thin facade over the internal stream/sink [AccountController]: it turns the
/// usage-based intent methods into commands and delegates. All decision logic
/// lives in the pure core; this class only adapts the public signature to the
/// runtime engine.
final class AccountLedger extends Ledger {
  AccountLedger._(this._controller) : super(token: Ledger.token);

  final AccountController _controller;

  /// Open a ledger for [id], hydrating its state from the [env]'s repository.
  static Future<Ledger> open(LedgerEnv env, AccountId id) async =>
      AccountLedger._(await AccountController.create(env, id));

  @override
  AccountId get id => _controller.id;

  @override
  AccountState get state => _controller.current;

  @override
  Stream<AccountState> get changes => _controller.states;

  @override
  LedgerResult deposit(Money amount,
          {Option<CommandId> idempotencyKey = const None()}) =>
      _controller.send(Deposit(amount, idempotencyKey: idempotencyKey));

  @override
  LedgerResult withdraw(Money amount,
          {Option<CommandId> idempotencyKey = const None()}) =>
      _controller.send(Withdraw(amount, idempotencyKey: idempotencyKey));

  @override
  LedgerResult setDailyLimit(Money limit) =>
      _controller.send(SetDailyLimit(limit));

  @override
  LedgerResult freeze() => _controller.send(const Freeze());

  @override
  LedgerResult closeAccount() => _controller.send(const Close());

  @override
  Future<void> dispose() => _controller.dispose();
}

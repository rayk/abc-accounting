import 'package:abc_accounting_impl/abc_accounting_impl_internals.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

/// The stateful shell: sink in, stream out, snapshot via `current`.
void main() {
  const id = AccountId('acc');

  test('sink → stream emits new states in command order', () async {
    final controller = await AccountController.create(testEnv(), id);
    final balances = <int>[];
    final sub =
        controller.states.listen((s) => balances.add(s.balance.minorUnits));

    controller.commands
      ..add(const Deposit(Money(100)))
      ..add(const Withdraw(Money(40)));

    await controller.dispose(); // drains the queue, then closes
    await sub.cancel();

    expect(balances, [100, 60]);
  });

  test('current reflects the latest applied state', () async {
    final controller = await AccountController.create(testEnv(), id);

    await controller.send(const Deposit(Money(100)));
    expect(controller.current.balance, const Money(100));

    await controller.dispose();
  });

  test('a rejected command yields Left and emits nothing', () async {
    final controller = await AccountController.create(testEnv(), id);
    final seen = <AccountState>[];
    final sub = controller.states.listen(seen.add);

    final result = await controller.send(const Withdraw(Money(10))); // no funds
    expect(result.match((_) => true, (_) => false), isTrue);

    await controller.dispose();
    await sub.cancel();
    expect(seen, isEmpty);
  });

  test('broadcast: multiple listeners observe the same feed', () async {
    final controller = await AccountController.create(testEnv(), id);
    final a = <int>[];
    final b = <int>[];
    final sa = controller.states.listen((s) => a.add(s.balance.minorUnits));
    final sb = controller.states.listen((s) => b.add(s.balance.minorUnits));

    await controller.send(const Deposit(Money(10)));

    await controller.dispose();
    await sa.cancel();
    await sb.cancel();

    expect(a, [10]);
    expect(b, [10]);
  });
}

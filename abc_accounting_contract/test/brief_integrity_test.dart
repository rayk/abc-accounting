@TestOn('vm')
library;

import 'dart:mirrors';
import 'package:abc_accounting_contract/abc_accounting_contract.dart';
import 'package:test/test.dart';

Set<String> fieldNamesOf(Type type) {
  final classMirror = reflectClass(type);
  return classMirror.declarations.entries
      .where((e) => e.value is VariableMirror && !(e.value as VariableMirror).isStatic)
      .map((e) => MirrorSystem.getName(e.key))
      .toSet();
}

void main() {
  group('ledgerBrief typeOverrides integrity', () {
    test('AccountState typeOverrides keys are valid field names', () {
      final fields = fieldNamesOf(AccountState);
      const overrideKeys = {'id', 'balance', 'dailyLimit', 'withdrawnToday', 'version'};
      for (final key in overrideKeys) {
        expect(fields, contains(key), reason: 'AccountState has no field named "$key".');
      }
    });
    test('InsufficientFunds typeOverrides keys are valid field names', () {
      final fields = fieldNamesOf(InsufficientFunds);
      const overrideKeys = {'balance', 'requested'};
      for (final key in overrideKeys) {
        expect(fields, contains(key), reason: 'InsufficientFunds has no field named "$key".');
      }
    });
    test('DailyLimitExceeded typeOverrides keys are valid field names', () {
      final fields = fieldNamesOf(DailyLimitExceeded);
      const overrideKeys = {'limit', 'attempted'};
      for (final key in overrideKeys) {
        expect(fields, contains(key), reason: 'DailyLimitExceeded has no field named "$key".');
      }
    });
  });
}

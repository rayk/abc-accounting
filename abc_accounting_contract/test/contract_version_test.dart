@TestOn('vm')
library;

import 'dart:io';

import 'package:abc_accounting/abc_accounting.dart' show contractVersion;
import 'package:test/test.dart';

String _versionOf(Uri pubspecUri) {
  final file = File.fromUri(pubspecUri);
  if (!file.existsSync()) {
    throw StateError('cannot find pubspec at ${file.path}');
  }
  final match = RegExp(r'^version:\s*(\S+)', multiLine: true)
      .firstMatch(file.readAsStringSync());
  if (match == null) throw StateError('no version: in ${file.path}');
  return match.group(1)!;
}

void main() {
  // dart test resolves Platform.script to a temp bootstrap file, not the test
  // file. Use Directory.current (the workspace root when dart test is run from
  // the workspace root) to anchor paths instead.
  final workspaceRoot = Directory.current.uri;
  final contractPubspecUri = workspaceRoot.resolve('abc_accounting_contract/pubspec.yaml');
  final interfacePubspecUri = workspaceRoot.resolve('abc_accounting/pubspec.yaml');

  final contractVersion_ = _versionOf(contractPubspecUri);
  final interfaceVersion = _versionOf(interfacePubspecUri);

  String majorMinor(String v) => v.split('.').take(2).join('.');

  test('abc_accounting and abc_accounting_contract share the same MAJOR.MINOR', () {
    expect(majorMinor(interfaceVersion), majorMinor(contractVersion_),
        reason: 'abc_accounting ($interfaceVersion) and abc_accounting_contract ($contractVersion_) must share MAJOR.MINOR.');
  });

  test('the runtime contractVersion constant agrees with the abc_accounting package version', () {
    expect(contractVersion, interfaceVersion,
        reason: 'The runtime contractVersion ($contractVersion) must equal the abc_accounting pubspec version ($interfaceVersion).');
  });
}

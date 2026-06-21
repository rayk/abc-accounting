import 'dart:io';

import 'package:abc_accounting/abc_accounting.dart' show contractVersion;
import 'package:test/test.dart';

/// Release guard: the implementation (`abc_accounting`) must be released at the
/// version of the contract it complies with. After the collapse, the contract's
/// version is carried by this conformance kit (`contracts_for_abc_accounting`) — it *is* the
/// executable spec — and is also surfaced at runtime as `contractVersion`. The
/// rule is therefore three-way:
///
///   abc pubspec version == contracts pubspec version == contractVersion constant
///
/// Runs from the `contracts/` directory (the default for its tests), where
/// `pubspec.yaml` is the contract and `../pubspec.yaml` is the implementation.
String _versionOf(String pubspecPath) {
  final file = File(pubspecPath);
  if (!file.existsSync()) {
    fail('cannot find $pubspecPath (run from the contracts/ directory)');
  }
  final match = RegExp(r'^version:\s*(\S+)', multiLine: true)
      .firstMatch(file.readAsStringSync());
  if (match == null) fail('no `version:` in $pubspecPath');
  return match.group(1)!;
}

void main() {
  final contractPubspec = _versionOf('pubspec.yaml'); // contracts = the contract
  final implPubspec = _versionOf('../pubspec.yaml'); // abc = the implementation

  test('the implementation pubspec is versioned at the contract version', () {
    expect(
      implPubspec,
      contractPubspec,
      reason:
          'The released abc_accounting version ($implPubspec) must equal the '
          'contract version it complies with ($contractPubspec). Bump '
          'abc_accounting/pubspec.yaml to $contractPubspec (and tag '
          'v$contractPubspec) before releasing — see RELEASING.md.',
    );
  });

  test('the runtime contractVersion constant agrees with both pubspecs', () {
    expect(
      contractVersion,
      contractPubspec,
      reason:
          'The runtime contractVersion ($contractVersion) must equal the '
          'contract (contracts_for_abc_accounting) version ($contractPubspec). Update '
          'lib/src/contract/version.dart in lock-step — see RELEASING.md.',
    );
    expect(
      contractVersion,
      implPubspec,
      reason:
          'The runtime contractVersion ($contractVersion) must equal the '
          'released abc_accounting version ($implPubspec).',
    );
  });
}

/// The version of the `Ledger` **contract** this package implements.
///
/// `abc_accounting` is released at the contract version it complies with, so this
/// equals `pubspec.yaml`'s `version:` and the conformance kit's
/// (`contracts_for_abc_accounting`) `version:`. All three are pinned together by
/// `contracts/test/contract_version_test.dart`; bumping a release means
/// bumping this constant and both pubspecs in lock-step (see `RELEASING.md`).
///
/// Exposing it as a runtime value lets a consumer assert at startup that the
/// implementation it linked against speaks the contract it expects:
///
/// ```dart
/// assert(contractVersion == '0.1.0');
/// ```
const String contractVersion = '0.1.0';

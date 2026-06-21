# Changelog

All notable changes to `abc_accounting` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to [semantic versioning](https://semver.org/spec/v2.0.0.html) **of the contract**
— the released version equals the conformance-kit (contract) version it complies
with. See [`RELEASING.md`](RELEASING.md).

## [Unreleased]

## [0.1.0] - 2026-06-21

### Added

- The token-guarded `Ledger` contract (`lib/src/contract/`): the `Ledger` base
  with `UnimplementedError` defaults and `Ledger.verify`, the `LedgerFactory` /
  `LedgerResult` seams, and the value/event/error/state types it speaks in
  (`Money`, `AccountId`, `AccountState`, `LedgerEvent`, `LedgerError`, …).
- The `AccountLedger` implementation (`lib/src/{domain,core,effects,runtime,api,
  di}/`): a functional core (`decide` / `evolve`), injectable effect seams
  (clock, id generator, repository), a stream/sink controller, and overridable
  Riverpod wiring.
- The dev-only conformance kit `contracts_for_abc_accounting`: `ledgerAcceptance` (the
  executable spec), `UnimplementedLedger` (red stub), `ReferenceLedger` (green
  reference), and the `LedgerUnderTest` switch — path-depending on `abc`.
- Tests: unit, `glados` property tests, `dart_arch_test` architecture rules,
  `mutation_test` configuration, and the shared repository contract test.
- `tool/verify.sh` and a GitHub Actions workflow as the definition of done.
- Project docs: `SPEC.md`, `LIFECYCLE.md`, `RELEASING.md`.

[Unreleased]: https://github.com/rayk/ref-examplar/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/rayk/ref-examplar/releases/tag/v0.1.0

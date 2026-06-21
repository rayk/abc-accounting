# Releasing `abc_accounting`

`abc_accounting` is the only released artifact. Its version **follows the
contract version**, which — after the interface was folded into `abc` — is
carried by the conformance kit **`contracts_for_abc_accounting`** (the executable spec).

## The rule

> **`abc_accounting`'s released version == `contracts_for_abc_accounting`'s version**, and the
> git tag is `v<that version>`.

So a downstream pinning `ref: v1.2.0` is also stating "an implementation
compliant with **contract 1.2.0**." Three things must agree, and
`contracts/test/contract_version_test.dart` pins all three:

- `pubspec.yaml`'s `version:` (the released `abc_accounting`),
- `contracts/pubspec.yaml`'s `version:` (the contract / executable spec),
- `lib/src/contract/version.dart`'s `contractVersion` (the runtime value a
  consumer can assert against).

The git tag (`v<version>`) is checked against these by CI on release tags.

## Versioning the contract (semver)

Bump `contracts/pubspec.yaml`'s `version:` (and, in lock-step,
`pubspec.yaml`'s `version:` and `lib/src/contract/version.dart`'s
`contractVersion`) when the contract changes:

| Change | Bump |
|--------|------|
| Removed/renamed/retyped a `Ledger` member, or changed an operation's semantics | **MAJOR** |
| A **new variant** of a `sealed` type (`LedgerError`, …) | **MAJOR** |
| A new `Ledger` **method** (the token-guard default keeps `extend`-based implementers compiling) | **MINOR** |
| A new conformance scenario that an *existing* implementation already satisfies (a clarification) | **PATCH** |

### Carve-outs — why those rows are where they are

- **A new `Ledger` method is MINOR, but only for `extend`-based implementers.**
  The token guard makes `extend Ledger` the *only* sanctioned way to implement
  the contract, and an added method gets a default `UnimplementedError` body — so
  every existing implementation keeps compiling. The trade-off is runtime, not
  compile time: calling the new method on an implementation that hasn't overridden
  it throws `UnimplementedError`. A consumer that bypassed the guard with
  `implements Ledger` (unsupported — it fails `Ledger.verify`) would get a
  *compile* break instead; that path is out of contract, so it does not force a
  MAJOR.
- **A new `LedgerError` variant is MAJOR.** `LedgerError` is a `sealed class`, so
  any consumer that `switch`es over it exhaustively gets a non-exhaustive-switch
  *compile error* the moment a case is added. The same applies to any other
  `sealed` type in the contract. (Adding a *field* to an existing variant, or a
  wholly new non-sealed value type, is additive → MINOR.)
- **A new conformance scenario is only PATCH when it is a clarification** — i.e.
  every conforming implementation already passes it. If it constrains behaviour
  that was previously unspecified (turning a passing implementation red), it is a
  contract *tightening*: MINOR if implementations are expected to adapt by
  overriding, MAJOR if it changes the meaning of an existing operation.

## Release checklist

1. **Be green on both packages** (the definition of done):
   ```bash
   ./tool/verify.sh    # abc analyze+test, then contracts analyze+test, then assert the stub spec is still red
   ```
2. **Pick the contract version** in `contracts/pubspec.yaml` (`version:`).
3. **Match it in two more places** — `pubspec.yaml`'s `version:` and
   `lib/src/contract/version.dart`'s `contractVersion`. The guard
   `contract_version_test.dart` fails until all three are equal.
4. **Re-run** `(cd contracts && dart test)` so the 3-way version guard passes.
5. **Update `CHANGELOG.md`** — move the entries under a new `## [<version>]`.
6. **Tag and push** (CI re-checks `tag == version == contract`):
   ```bash
   git tag v<version> && git push origin v<version>
   ```

## How downstreams consume it

No `path:`, no `dependency_overrides` (`abc` has no non-hosted dependency):

```yaml
dependencies:
  abc_accounting:
    git:
      url: https://github.com/rayk/ref-examplar.git
      ref: v<version>
```

> Git tags don't compose semver across many independent consumers (each pins a
> `ref`). If a larger stack needs `^x.y.z` resolution, publish `abc_accounting`
> to a hosted pub source; the version rule above is unchanged.

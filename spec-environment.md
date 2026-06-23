# Spec Environment & Resume Guide

Operational companion to **`CONTRACT_AUTHORING_SPEC.md`**. The spec is the *design* (what to build);
this doc is the *environment* (how to operate here) plus the resume plan. Together they are a
complete cold-start kit — no conversation context required.

## Resume plan (two phases)

1. **Build `bnd_eac`** to support the spec's surface. Engine build order = **spec §9**. Develop
   against a local override (below); re-pin when done.
2. **Rewrite `abc_accounting`'s contracts** against the new `bnd_eac`, proving each feature
   fixture-first (write the wished-for contract → red for the right reason → green-then-red). The
   8 contract files + the lifecycle scenario are the targets.

**Read order on resume:** this doc → `CONTRACT_AUTHORING_SPEC.md` → the real `bnd_eac` renderer
(path below) → the current fixture contracts.

## Environment gotchas (CRITICAL)

- **Dart binary.** `dart` is aliased to `fvm dart`, whose wrapper chokes on the workspace-root
  pubspec. ALWAYS use the direct binary for analyze / test / pub:
  `/Users/rayk/.fvm/versions/3.44.2/bin/dart`.
- **Workspace-root pubspec.** Needs `name: abc_accounting_workspace` + `publish_to: none`
  (Dart 3.12 requires a name even for a workspace root). Run `dart pub get` from the **workspace
  root**, never inside a member package.

## `bnd_eac` edit logistics

- **Pinned** in `abc_accounting_contract/pubspec.yaml`: `bnd_eac` git `rayk/bounded.git`
  ref `c9de583…`, path `packages/bnd-eac`.
- **Editable live target:** `/Users/rayk/bounded/packages/bnd-eac` — its brief subsystem is
  byte-identical to the pin. (Other clones `/Users/rayk/bounded-fixtures/bnd-eac` and
  `/Users/rayk/common-repo/bnd-eac` are stale — ignore.)
- **Dev loop:** add `dependency_overrides: { bnd_eac: { path: /Users/rayk/bounded/packages/bnd-eac } }`
  to the workspace-root pubspec; edit the engine there. When done, re-pin
  `abc_accounting_contract/pubspec.yaml` to a NEW **full commit SHA** (never a tag — spec rule) and
  remove the override.
- **Read the renderer first:** `/Users/rayk/bounded/packages/bnd-eac/lib/src/brief/contract_brief.dart`
  (`ContractBrief` / `_renderBriefBlock`). Today it emits only `File:` / `Function:` / `CONTRACT:` /
  optional `SEAMS:` / `TYPES:` / `FIELD-FORMATS:` — the elaborate machinery in
  `WORKSPACE_PATTERN_SPEC.md` (`withContext`/`forImplementation`/CONTEXT/TYPEDEF/sealed-header/
  `tool/harness.dart`) is FICTION and is superseded by `CONTRACT_AUTHORING_SPEC.md`.

## Existing architecture the build leans on (do NOT re-derive)

- **DIP edges:** `impl → interface` (req), `kit → interface` (req), `kit ↔ impl` ZERO
  (compiler-enforced), `interface → impl` forbidden (the registration seam exists to avoid it).
  DIP applies to behaviour, not data: concrete value types live in the contract package; only
  `Ledger` (swappable behaviour) gets the token-guard + factory.
- **Run-to-red seam:** `defaultFactory` throws until `abc_accounting_impl.register()` overrides it;
  `collapse.dart` static-wires it at release. Unimplemented ops are `=> throw UnimplementedError()`,
  so the FIRST red is a **throw**, not a settled `Either` — the spec's seam-throw steering
  (`MISSING_SYMBOL`) depends on this.
- **Token guard:** enforce `extends` not `implements`, so adding a method stays non-breaking
  (subclasses inherit a throwing default). Extending passes the guard but does NOT green the suite —
  only real overrides do.
- Fuller structural detail: `WORKSPACE_PATTERN_SPEC.md` (3-package migration spec; treat its
  brief/harness sections as fiction).

## Foundations — locations & state

- **`cmo_failures`** — github.com/rayk/cmo-failures, git-only (`publish_to: none`), pins
  `fpdart ^1.1.0`. Non-generic `sealed class Failure` value object; rich fields
  (`message`/`category`/`blame`/`recovery`/`diagnostics{what,expected,actual}`/`code`/`scenario`/
  `tags`/`trail`); `toString()` is already an ALCA steering prompt; **no value-equality**
  (match by type + fields). Design: spec §4.1.
- **`cmo_model`** — github.com/rayk/cmo-model, v0.2.0, EARLY-STAGE. `ValueObject` is an empty
  marker; `ScalarValue<T> extends Equatable` (value-equal); smart ctors →
  `Validated<T> = Either<IList<Failure>, T>` (accumulated). **BLOCKER: public barrels broken via
  `kernel_old` → `kernel` rename** — pin a known-good commit or fix the barrels (+ re-point
  `Validated`) before importing the public API; the impl is real/green via deep imports. Design:
  spec §4.2.
- **`glados`** 1.1.7 (already a workspace dep; ~2yr old; SDK upper bound may need an override).
  **`fake_async`** 1.3.3 + **`async`** 2.13.1 — already transitive `test` deps (no pubspec change).
  **`parameterized_test`** 2.0.3 — NOT transitive; add to `dev_dependencies`, SDK `>=3.8.0`.

## Key locations

| What | Path |
|---|---|
| Design spec (read after this) | `CONTRACT_AUTHORING_SPEC.md` |
| `bnd_eac` renderer (read first) | `/Users/rayk/bounded/packages/bnd-eac/lib/src/brief/contract_brief.dart` |
| Current brief / conformance | `abc_accounting_contract/lib/src/brief/ledger_brief.dart`, `…/src/conformance.dart` |
| Type override maps (KEEP — do not retire) | `abc_accounting_contract/lib/src/types/type_config.dart` |
| Contract files (8) | `abc_accounting_contract/lib/src/contracts/001_open.dart .. 008_change_feed.dart` |
| Ledger / vocabulary | `abc_accounting/lib/src/contract/{ledger,vocabulary}.dart` |
| Order-dependent scenario (re-author for random order) | `abc_accounting_contract/lib/src/scenarios/001_account_lifecycle.dart` |
| User's original declarative draft | `abc_accounting_contract/lib/contract-draft.md` |

## Provenance & baseline

- Design committed: `CONTRACT_AUTHORING_SPEC.md` @ `4ec1c53` on `main`. Migration baseline
  `c628c43` (3-package workspace green: 38 pass / 1 skip in the kit, 66 in impl).
- The spec was hardened by a **two-panel expert review (35 agents, all signed off)** + grounded
  experiments (tag delimiter, mirror erasure, `fakeAsync`+`StreamQueue`, broadcast pull-first).
  Findings are folded into the spec; raw evidence is not retained.
- **Frame decision:** Dart-native, write-and-run, **NO codegen**. The "Cairn" standalone-language /
  codegen / stack-agnostic frame was considered and **rejected** for this practice; only its
  *concepts* were borrowed (`requires`/`ensures(old())`/`effects`, the async-temporal clause family,
  the `failureClass` steering taxonomy).
- **Inherited fix-now items** (do during the Phase-2 rewrite): dead `isFactoryRegistered`;
  `di/providers.dart` "public interfaces" wording; the "Never modified" provenance stamps;
  duplicate architecture tests; pair `test_randomize_ordering_seed: random` with re-authoring
  `001_account_lifecycle.dart` into a single sequence body.

# Spec Alignment Audit — abc_accounting workspace

**Date:** 2026-06-24
**Auditor:** Claude Code (multi-agent review, synthesized)
**Subject:** the three-package workspace `abc_accounting` (interface) / `abc_accounting_impl` (implementation) / `abc_accounting_contract` (conformance kit)

## Scope

This audit checked the workspace against three governing specs:

| Spec | What it governs | Audit status |
| --- | --- | --- |
| `CONTRACT_AUTHORING_SPEC.md` | The EAC contract-first authoring practice (run-to-red, single source of truth, Phase 3/4/5/6 declarations, tags/IDs/steering) | ⚠️ **NOT COMPLETED** — reviewer interrupted before returning findings |
| `WORKSPACE_PATTERN_SPEC.md` | The generic 3-package structure: naming, pubspecs, token-guard seam, exports, no-barrels, layout, collapse tooling, version constant | ✅ Completed |
| `spec-environment.md` | Operational environment: SDK constraints, dependency versions/pins, the `bnd_eac` dev-loop, lockfile coherence | ✅ Completed |

> **Coverage caveat:** The `CONTRACT_AUTHORING_SPEC` review — which checks whether the EAC *contracts themselves* follow the authoring practice — did not return. It is arguably the most central of the three for a "review the contracts" request. **This document covers 2 of 3 audits.** Re-run the third to close the gap.

### Supersession boundary (important)

`CONTRACT_AUTHORING_SPEC.md` explicitly **supersedes** the brief/harness machinery described in `WORKSPACE_PATTERN_SPEC.md` — the `withContext` / `forImplementation` / `CONTEXT` / `TYPEDEF:` / `sealed XxxError` header / `tool/harness.dart` machinery "is fiction and is deleted on adoption." The workspace has correctly cut over to the `bnd_eac` `Case`/`Rule`/`FailureMode` DSL. The **absence** of that machinery (`ContractBrief`, `withContext`, `forImplementation`, `tool/harness.dart`, `.harness_scratch/` wiring, `src/types/type_config.dart`, `src/brief/`, the numbered-aggregator `conformance.dart`, and brief-based `pending`/`honest_red`/`brief_integrity` tests) is **correct and is not a finding**.

---

## Executive summary

The workspace is **substantially conformant** — no BLOCKERs. Naming/roles, the token-guard registration seam, the `contractVersion` constant, interface dependency hygiene, the full-SHA `bnd_eac` pin, the committed root lockfile, the exact SDK constraints, and the layered impl structure all match spec. The real issues are:

1. **A genuine spec-vs-spec conflict** — `WORKSPACE_PATTERN_SPEC` prescribes a barrel; `CONTRACT_AUTHORING_SPEC §1.5` forbids barrels. This needs a human decision, not a mechanical fix.
2. **The `bnd_eac` engine handoff is mid-flight** — the local-path override is active, the pin is un-bumped, and the spec text + the pin's upstream repo disagree about where the engine actually lives.

Everything else is minor cleanups and nits.

---

## Findings — by severity

Severity legend: **BLOCKER** (broken / blocks adoption) · **MAJOR** (needs a decision or real fix) · **MINOR** (cleanup) · **NIT** (cosmetic).

### MAJOR-1 · Barrel vs. "no barrels" — the two specs contradict each other
- **Spec refs:** `CONTRACT_AUTHORING_SPEC §1.5` ("No barrels. Interface packages declare published symbols directly in their public library, so a symbol's library URI *is* its importable path") and `§2`; **conflicts with** `WORKSPACE_PATTERN_SPEC` lines 309–315, which *do* prescribe a barrel.
- **Code:**
  - `abc_accounting_contract/lib/src/account_opening.dart:99` — `importable: 'package:abc_accounting/src/contract/ledger.dart'` (a **private `src/` path**).
  - `abc_accounting/lib/abc_accounting.dart:1-5` — barrel re-exporting `src/contract/{ledger,vocabulary,version}.dart` + `src/registration/factory.dart`.
- **Problem:** Published symbols (`Ledger`, vocabulary, factory) live under `lib/src/` behind a barrel, so the only legitimate cross-package import is the barrel `package:abc_accounting/abc_accounting.dart`. The hand-authored `importable:` instead names a private `src/` path, which triggers the `implementation_imports` analyzer warning if a consumer/ALCA imports it. Under `§1.5` the importable should be the symbol's own public library URI.
- **Fix (pick one):**
  - *Adopt §1.5:* move `ledger.dart` / `vocabulary.dart` / `version.dart` out of `lib/src/contract/` into public `lib/` libraries (e.g. `lib/ledger.dart`), drop the barrel, and let `importable` derive from the real library URI.
  - *Retain the WORKSPACE_PATTERN barrel:* change the `importable:` string to `package:abc_accounting/abc_accounting.dart` so it names a legitimately importable URI.

### MAJOR-2 · `bnd_eac` dev-loop path contradicts the spec — but the spec text is what's stale
- **Spec refs:** `spec-environment.md:33` ("Other clones `/Users/rayk/bounded-fixtures/bnd-eac` … are stale — ignore"), `:34` (override should point at `/Users/rayk/bounded/packages/bnd-eac`), `:38`.
- **Code:** `pubspec.yaml:18-20` overrides `bnd_eac` → `/Users/rayk/bounded-fixtures/bnd-eac`.
- **Evidence the spec is wrong, not the override:** the kit imports `package:bnd_eac/contract.dart` and `package:bnd_eac/execution.dart`. Those libraries exist **only** in the override target (`/Users/rayk/bounded-fixtures/bnd-eac/lib/` has `brief/contract/execution/harness/matchers/steering`), whereas the spec's "canonical" `/Users/rayk/bounded/packages/bnd-eac/lib/` has only `brief/harness/matchers`. The override target's git HEAD is `b9c2720 "feat(engine): contract-authoring engine — clauses, temporal, steering, laws"` (the §9 deliverable). Pointing the override at the spec-prescribed path would break resolution.
- **Fix:** Update `spec-environment.md` §"bnd_eac edit logistics" to name `/Users/rayk/bounded-fixtures/bnd-eac` (repo `rayk/bnd-eac.git`, branch `feat/contract-authoring-engine`) as the live editable target and drop the inverted "stale" label. **Do not change the override** — it is correct for the current build state.

### MAJOR-3 · Override source repo ≠ the pin's upstream repo — the eventual re-pin is non-trivial
- **Spec refs:** `spec-environment.md:29` (pin at `rayk/bounded.git` `packages/bnd-eac`), `:36-37` (re-pin to a NEW full SHA when done).
- **Code:** `abc_accounting_contract/pubspec.yaml:19-23` pins `url: https://github.com/rayk/bounded.git … path: packages/bnd-eac`. The override target's git remote is `https://github.com/rayk/bnd-eac.git` (a **standalone** repo), branch `feat/contract-authoring-engine`, HEAD `b9c2720`.
- **Problem:** The engine build lives in `rayk/bnd-eac.git`, but the pin (and re-pin target) is the `rayk/bounded.git` monorepo — two different GitHub repos. The pinned SHA `c9de583` is not present in the local monorepo clone's object store. When the build lands, the re-pin must reconcile which repo hosts the published engine.
- **Fix:** Decide the canonical home; land/push the engine commits there; re-pin to that repo + a full SHA (per spec, never a tag); then remove the override.

### MINOR-4 · `bnd_eac` "REMOVE + re-pin when the build lands" still pending
- **Code:** `pubspec.yaml:14-17` (the REMOVE/re-pin comment) + active override `:18-20`; `abc_accounting_contract/pubspec.yaml:22` still on baseline `c9de583`.
- **Problem:** The §9 engine (clauses/temporal/steering/laws) is committed (`b9c2720`), yet the override is active and the pin un-bumped. Expected mid-handoff, but it is the standing operational TODO.
- **Fix:** Action item — bump the pin and drop the override once the engine-repo decision (MAJOR-3) is settled.

### MINOR-5 · `very_good_analysis` declared in interface/impl but no `analysis_options.yaml` wires it
- **Code:** `abc_accounting/pubspec.yaml:17` and `abc_accounting_impl/pubspec.yaml:24` declare `very_good_analysis: ^10.2.0`, but neither package (nor the workspace root) has an `analysis_options.yaml`. Only `abc_accounting_contract/analysis_options.yaml:1` does `include: package:very_good_analysis/...`.
- **Problem:** The lints are a **no-op** for the interface and impl packages.
- **Fix:** Add an `analysis_options.yaml` with `include: package:very_good_analysis/analysis_options.yaml` to the interface and impl packages (or a single workspace-root one).

### MINOR-6 · Conformance kit consolidated into one file instead of numbered `contracts/NNN` + `scenarios/NNN`
- **Spec refs:** `WORKSPACE_PATTERN_SPEC` "additive-migration principle" (lines 590–596); `CONTRACT_AUTHORING_SPEC §9` names the fixture targets as `…/contracts/001_open.dart .. 008_change_feed.dart` and `scenarios/001_account_lifecycle.dart`.
- **Code:** `abc_accounting_contract/lib/src/ledger_conformance.dart:52-819` holds every operation group (open, deposit, withdraw, setDailyLimit, freeze, closeAccount, idempotency, change_feed, lifecycle) inline; there is no `src/contracts/` or `src/scenarios/` directory.
- **Problem:** Coverage is complete, but the per-operation/per-scenario numbered-file layout both specs call for is absent — everything lives in one mutable file.
- **Fix:** Split `ledger_conformance.dart` into `src/contracts/001_open.dart … 008_change_feed.dart` and `src/scenarios/001_account_lifecycle.dart`, reducing `ledger_conformance.dart` to a thin aggregator. (Transitional; lower priority while the engine build is in flight.)

### MINOR-7 · Duplicate architecture tests in the impl package
- **Spec refs:** `WORKSPACE_PATTERN_SPEC` layout (single `…/test/architecture_test.dart`, line 63); `CONTRACT_AUTHORING_SPEC §8` lists "duplicate architecture tests" as an inherited fix-now cleanup.
- **Code:** `abc_accounting_impl/test/architecture_test.dart` **and** `abc_accounting_impl/test/architecture/architecture_test.dart` differ — the nested one is the richer layered version (`defineLayers(...).enforceDirection(graph)` + a contract-layer rule); the root one is an older subset with a stale path anchor (`.parent.parent`).
- **Fix:** Delete the older `test/architecture_test.dart`; keep `test/architecture/architecture_test.dart`.

### MINOR-8 · `tool/collapse.dart` omits spec steps 8 and 10, hardcodes merged deps
- **Spec refs:** `WORKSPACE_PATTERN_SPEC` "Collapse" steps 8 (copy value-type tests from `{name}/test/`) and 10 (`dart test` the merged package), plus "Dependency conflict resolution" (union/intersection of both pubspecs).
- **Code:** `tool/collapse.dart:194-217` runs `dart pub get` + `dart analyze` only (no `dart test`, no test copy); `tool/collapse.dart:158-169` writes a hardcoded dependency block (`fpdart`, `fast_immutable_collections`, `riverpod`) rather than merging the two source pubspecs.
- **Problem:** The release artifact is analyzed but never test-verified, and a dep later added to `abc_accounting_impl/pubspec.yaml` would not propagate into the merged pubspec.
- **Fix:** Add a step copying `abc_accounting/test/` (no-op if absent) and running `dart test` on `.release/abc_accounting/`; compute merged `dependencies` as the union of both source pubspecs, intersecting on conflict.

### MINOR-9 · Impl exposes a second public library re-exporting the entire `src/` tree
- **Spec refs:** `WORKSPACE_PATTERN_SPEC` Package 2 — "the public barrel only exports `register()` for the harness" (lines 365–379); "What it does NOT contain … Any consumer-facing API."
- **Code:** `abc_accounting_impl/lib/abc_accounting_impl_internals.dart:1-19` exports all of `src/{api,core,domain,effects,runtime,di}` plus `package:abc_accounting/abc_accounting.dart`. (The prescribed `abc_accounting_impl.dart:1-3` correctly exports only `register`.)
- **Problem:** A full internals barrel publishes every implementation type as a package-level API. Low blast radius (`publish_to: none`, not copied by collapse), but it is a public surface the spec says should not exist.
- **Fix:** If it exists only for `example/` and tests, prefer `package:abc_accounting_impl/src/...` deep imports from those call sites and remove the internals barrel; otherwise document it as an explicitly sanctioned workspace-only deviation.

### NIT-10 · Dead `isFactoryRegistered` getter
- **Spec ref:** `CONTRACT_AUTHORING_SPEC §8` lists "dead `isFactoryRegistered`" as a fix-now cleanup.
- **Code:** `abc_accounting/lib/src/registration/factory.dart:17` — `bool get isFactoryRegistered => _factory != null;` (no callers in the workspace).
- **Fix:** Remove it.

### NIT-11 · Stale doc comment in `version.dart` references the old exemplar package name
- **Code:** `abc_accounting/lib/src/contract/version.dart:4-7` references `contracts_for_abc_accounting`, `contracts/test/contract_version_test.dart`, and `RELEASING.md`; current names are `abc_accounting_contract` and `abc_accounting_contract/test/contract_version_test.dart`. (The constant itself is correct.)
- **Fix:** Update the doc comment to the current package/test names.

### NIT-12 · Cross-package SDK floor drift (intentional, documented)
- **Code:** `abc_accounting_contract/pubspec.yaml:9` (`sdk: ">=3.8.0 <4.0.0"`) vs `abc_accounting/pubspec.yaml:8`, `abc_accounting_impl/pubspec.yaml:9`, root `pubspec.yaml:7` (`>=3.5.0 <4.0.0`).
- **Note:** Intentional — the 3.8.0 bump is required by `parameterized_test 2.0.3` per `CONTRACT_AUTHORING_SPEC §1`. Worth tracking only because the kit raises the effective dev SDK floor to 3.8.0 while the root advertises 3.5.0. No action now; reconcile when the engine build lands.

### NIT-13 · `very_good_analysis` declared→resolved drift
- **Code:** `pubspec.lock:442` resolves `10.3.0` from declared `^10.2.0`. Within range, harmless; the spec names no exact version. **No action.**

---

## What is solidly aligned

**Workspace pattern (`WORKSPACE_PATTERN_SPEC`):**
- **Package naming & roles** — `abc_accounting` (interface, no `publish_to`, `version: 0.1.0`), `abc_accounting_impl` (`publish_to: none`, path dep `../abc_accounting`, optional `riverpod ^2.6.0`), `abc_accounting_contract` (`publish_to: none`, path dep, `bnd_eac` git dep). Descriptions match the spec wording almost verbatim. All three carry `resolution: workspace`; root `pubspec.yaml` lists all three members.
- **Token-guard / registration seam** — `abc_accounting/lib/src/contract/ledger.dart:25-88` implements the Expando/`_token`/`verify`/`UnimplementedLedger` pattern exactly. `registration/factory.dart:5-15` throws `StateError` when unregistered. `abc_accounting_impl/lib/src/registration.dart:5-18` carries `contractImplemented = '0.1.0'`, the `_majorMinor` guard, and wires `AccountLedger.open(defaultEnv(), id)`. `AccountLedger extends Ledger` with `Ledger.token` (`api/account_ledger.dart:16-17`).
- **Version constant** — `version.dart:15` is `const String contractVersion = '0.1.0';` (single-quoted, regex-extractable); `collapse.dart:18-23` and `registration.dart` read it as intended; matches both pubspec versions.
- **Interface dependency hygiene** — `abc_accounting` depends only on `fpdart`; `vocabulary.dart` imports only `fpdart`. `NonEmptyChain`/`fast_immutable_collections` correctly relocated to impl (`src/core/chain.dart`).
- **Collapse tooling exists** — `tool/collapse.dart` with correct contract-source copy, MAJOR.MINOR alignment gate (`:36-48`), static `factory.dart` generation with private `_defaultEnv()` (`:111-131`), merged barrel (`:134-144`). Only the MINOR-8 gaps remain.
- **Impl layered structure** — `src/{api,core,domain,effects,runtime,di}` + `registration.dart`.

**Environment (`spec-environment.md`):**
- **SDK constraints exact** — kit `>=3.8.0`, interface/impl/root `>=3.5.0`; no resolution conflict (effective floor pulled to `>=3.12.0` by transitive deps, `pubspec.lock:516`).
- **`parameterized_test ^2.0.3`** in `dev_dependencies` (`abc_accounting_contract/pubspec.yaml:27`) with the SDK bump — resolved `2.0.3` (`pubspec.lock:258`).
- **`fake_async 1.3.3` / `async 2.13.1`** present transitively with no pubspec change (`pubspec.lock:130`, `:35`).
- **`fpdart ^1.2.0`** everywhere (resolved `1.2.0`); **`checks ^0.3.1`** (0.3.1), **`glados ^1.1.7`** (1.1.7), **`test ^1.25.0`** (1.31.1) — all consistent with spec foundations.
- **Pin is a full 40-char SHA, not a tag** (`abc_accounting_contract/pubspec.yaml:22`).
- **Lockfile coherence** — `bnd_eac` is `direct overridden`, `source: path`, `/Users/rayk/bounded-fixtures/bnd-eac`, version `0.2.0` (`pubspec.lock:36-42`); no `cmo_failures`/`cmo_model` in the lock (consistent with spec §4).
- **Workspace root** — `name: abc_accounting_workspace` + `publish_to: none` (`pubspec.yaml:3-4`).
- **Test config** — kit `dart_test.yaml:1` sets `test_randomize_ordering_seed: random`, with derived hyphen tags (`kind-*`, `contract-*`, `sig-*`, `failure-*`) per `CONTRACT_AUTHORING_SPEC §6`.
- **Kit `analysis_options.yaml`** — correctly disables `always_use_package_imports`/`file_names`/`unnecessary_library_directive`/`sort_pub_dependencies` with rationale comments.

---

## Open item: the un-run third audit

The **`CONTRACT_AUTHORING_SPEC` audit** — does each EAC contract follow the authoring practice (run-to-red; single source of truth with enforced declaration↔binding joins; real unimplemented interface symbols, never paper; Phase 3 clauses / Phase 4 temporal / Phase 5 steering / Phase 6 laws-tables realized as prescribed; tag/ID/steering derivation) — **was not completed.** Re-run it to fully close this audit.

Files it would cover: `abc_accounting_contract/lib/src/{account_opening,ledger_conformance,ledger_types,phase3_clauses,ledger_checks,reference_abc_accounting,switch}.dart`, `lib/abc_accounting_contract.dart`, and all of `abc_accounting_contract/test/`.

# flutter_reference

This repo is the seed for a Mason brick — an opinionated, reusable Flutter starter for "bigger apps". It is **not** an app being shipped; everything decided here should be defensible as something we'd want in *every* new Flutter project. App-specific concerns do not belong in the brick.

## Read these first

- **`docs/template-foundations.md`** — the living reference for every locked-in decision (stack, project structure, bootstrap, providers, theming, env, networking, error model, logging, drift, presentation layout). When working on any of those areas, **read the relevant section first** — it may already lock in a decision. Update this doc in the same change that adds or revises a foundation.
- **`docs/pending.md`** — ordered checklist of known gaps (auth, retry interceptor, routing, mason brick variables, etc.). When picking up an item, move it under "In progress"; delete the entry when shipped (the work itself lives in code/foundations doc, not here).

When a "Proposed but not decided" item from `template-foundations.md` becomes relevant, brainstorm it explicitly, then promote it to "Decided foundations" with rationale.

## Stack at a glance

Riverpod 3 (hand-written providers, no codegen) · dio · drift + drift_flutter · talker · flex_seed_scheme · auto_route (not yet wired) · freezed + json_serializable for codegen-needing models.

`riverpod_generator` is intentionally **not** used — see the "Riverpod providers" section in `template-foundations.md` for why. Hand-written providers across the board.

## Layout

```
lib/
  core/           # shared infrastructure (network, database, env, logging, theme, errors)
  features/<name>/
    data/         # repositories, drift tables, freezed DTOs
    presentation/ # notifiers, screens, widgets
  bootstrap.dart  # error handlers, ProviderScope, pre-app setup
  app.dart        # MaterialApp root
  main.dart       # one-line entry
docs/             # template-foundations.md, pending.md
```

Feature-first, no `domain/` layer. Cross-feature widgets graduate to `lib/core/widgets/` when there's a real second consumer — don't pre-share.

## Working principles

- **Iterative, not speculative.** Foundations are added when a feature or concrete problem motivates them — but "thorough template for bigger apps" is the lens. Scaffolding for things real apps need (typed errors, auth, error-branching UX) is in scope even before the toy example exercises them.
- **Class-vs-wiring separation.** Domain classes (repositories, services, table definitions) are pure Dart — no Riverpod imports. The provider lives in a sibling `*_provider.dart` file.
- **Drift row types end-to-end** by default. Reach for a freezed DTO only when wire shape ≠ storage shape, or presentation needs computed fields. Wire-only DTOs (used inside the repo for parsing) are fine and don't count as proliferation.
- **Loggers are global, not provided.** `final talker = TalkerFlutter.init();` at top level — accessible without `ref`.
- **Keep-alive by default for infrastructure and repositories; auto-dispose for feature state.** See the lifecycle pairing table in `template-foundations.md`.

## Codegen

`build_runner` covers `freezed`, `json_serializable`, `drift_dev`, and `auto_route_generator`. Run after touching tables, freezed models, or routes:

```
dart run build_runner build --delete-conflicting-outputs
```

The user runs dart/flutter commands themselves — surface the command, don't execute it.

## Environment

Compile-time via `--dart-define` / `--dart-define-from-file`. All env reads go through `lib/core/env/env.dart` — never call `String.fromEnvironment` directly elsewhere. Never read `.env` files directly; `.env.example` only.

## Mason brick reminder

Anything templated-per-project (package name, app name, seed colours, org id) will become a brick variable. Avoid hard-coded user-specific values. The package import path `package:flutter_reference/...` will be substituted in the brick.

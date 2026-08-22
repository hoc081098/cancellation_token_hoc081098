# Repository Guidelines

## Project Structure & Module Organization

This repository is a Dart package for cooperative cancellation of futures and streams. `lib/cancellation_token_hoc081098.dart` is the public entry point; keep implementation details in `lib/src/` and export only supported APIs. Tests live in `test/cancellation_token_hoc081098_test.dart`. The runnable consumer example is under `example/`, with its own `pubspec.yaml`. Longer design notes belong in `docs/`. CI definitions are in `.github/workflows/`.

## Build, Test, and Development Commands

- `dart pub get` installs package dependencies.
- `dart analyze lib --fatal-infos --fatal-warnings` runs the same strict library analysis used by CI.
- `dart format . --set-exit-if-changed` checks repository-wide Dart formatting; run `dart format .` to apply fixes.
- `dart test --chain-stack-traces` runs the full `package:test` suite with useful asynchronous stack traces.
- `cd example && dart pub get && dart run lib/cancellation_token_hoc081098_example.dart` verifies the package through the local example app.

The CI matrix exercises Dart stable, beta, and the minimum supported SDK (`3.0.0`). Before submitting compatibility-sensitive changes, avoid syntax or APIs unavailable on that minimum version.

## Coding Style & Naming Conventions

Use two-space indentation and let `dart format` decide wrapping. The analyzer extends `package:lints/recommended.yaml` and additionally requires documented public members, explicit return types, single quotes, final locals where possible, relative imports within `lib/src/`, and handled futures. Use `UpperCamelCase` for types, `lowerCamelCase` for members, and `lower_snake_case.dart` for files. Preserve the narrow public barrel file rather than exposing internal files directly.

## Testing Guidelines

Use `package:test`, grouping cases by public API such as `CancellationToken`, `guardFuture`, and `guardStream`. Name tests after observable behavior (`cancel before`, `pause resume`) and cover successful completion, cancellation timing, error delivery, and resource cleanup. Add regression tests for every behavior change. Coverage is uploaded to Codecov, but no numeric threshold is configured in this repository.

## Commit & Pull Request Guidelines

Recent history favors short, imperative subjects with type prefixes, for example `feat: ...`, `docs: ...`, and `chore(deps): ...`. Prefer Conventional Commits (`fix(token): prevent duplicate cancellation`) and keep each commit focused. Pull requests should explain the behavioral change, link relevant issues, list verification commands, and update tests, API documentation, README examples, and `CHANGELOG.md` when public behavior changes. Screenshots are unnecessary unless documentation adds visual output.

# Cancellation 3.0 Redesign

## Summary

Refactor cancellation into one deep in-process module:

- `CancellationTokenSource` owns cancellation authority and handler execution.
- `CancellationToken` is a stable, read-only capability shared by the source.
- Future/Stream guards become real token instance methods.
- `run()` exposes completion versus cancellation request as an exhaustive outcome only at the lifetime-owning seam.
- RxDart remains an adapter outside the core implementation.

Naming follows the cooperative request semantics of [.NET cancellation](https://learn.microsoft.com/en-us/dotnet/standard/threading/cancellation-in-managed-threads): requesting cancellation does not prove underlying work has stopped.

## Public Interface

```dart
final class CancellationTokenSource {
  CancellationTokenSource();

  final CancellationToken token;

  void cancel();

  Future<CancellableOutcome<T>> run<T>(
    FutureOr<T> Function(CancellationToken token) computation,
  );
}

final class CancellationToken {
  bool get isCancellationRequested;

  void throwIfCancellationRequested();

  Future<T> guardFuture<T>(
    FutureOr<T> Function(CancellationToken token) computation,
  );

  Stream<T> guardStream<T>(Stream<T> stream);
}

sealed class CancellableOutcome<T> {
  const CancellableOutcome._();

  const factory CancellableOutcome.completed(T value) =
      OperationCompleted<T>;

  const factory CancellableOutcome.cancellationRequested() =
      CancellationRequested;
}

final class OperationCompleted<T> extends CancellableOutcome<T> {
  const OperationCompleted(this.value) : super._();

  final T value;
}

final class CancellationRequested extends CancellableOutcome<Never> {
  const CancellationRequested() : super._();
}

sealed class CancellationException implements Exception {
  const CancellationException._(this.cancellationToken);

  final CancellationToken cancellationToken;
}
```

Keep unchanged:

- `Stream<T>.guardedBy(token)` as a convenience adapter.
- `useCancellationToken(...)` and its main-barrel export.

Remove without deprecated aliases:

- Public `CancellationToken()` and `CancellationException()` constructors.
- `token.cancel()`, `isCancelled`, and `guard()`.
- The old token extension declarations for `guardFuture`/`guardStream`.

## Semantics and Implementation

- One source owns exactly one stable token. `cancel()` is synchronous, sticky, irreversible, and idempotent; it requests cancellation for all active and future operations.
- `run()` uses that stable token. Pre-cancellation skips the callback; an operation value returns `OperationCompleted`; a matching cancellation request returns `CancellationRequested`; ordinary errors and cancellation from another source propagate with their original stack.
- Cancellation winning `run()` or `guardFuture()` stops waiting immediately but does not terminate the losing Future. Late values/errors are consumed safely.
- Tokens never expire after `run()`: captured or losing work may continue observing the same source.
- Implement a private detachable-registration set. Set the requested flag before draining registrations so reentrancy and concurrent guards remain deterministic.
- Use a private `CancellationException` subtype carrying token identity. Consumers may catch and inspect it but cannot construct, subclass, or forge it.
- Strengthen `guardStream`: preserve broadcastness, avoid upstream subscription when pre-cancelled, initiate upstream cancellation even while paused, emit one cancellation error, surface teardown failures, then close after the [`StreamSubscription.cancel()` cleanup Future](https://api.dart.dev/dart-async/StreamSubscription/cancel.html) settles.
- Move Rx-specific implementation out of the core file. Each subscription creates a source, passes only `source.token`, and calls `source.cancel()` when the Single terminates or is cancelled.
- Do not add public registrations, linked sources, timeouts, reset/dispose, `runStream`, token revocation, or a shared Raise runtime in this slice.

## Migration and Documentation

- Bump package and example versions to `3.0.0-dev.1`; update the tracked example lockfile and add a detailed breaking section to `CHANGELOG.md`.
- Replace all repository call sites with source ownership, explicit request naming, and exhaustive outcome switching.
- Rewrite README examples/API inventory and public Dartdoc, including the current stale `guardFuture` callback examples.
- Update `docs/dart-raise-cancellation-effects-handoff.md` from section 10 onward: settle ownership, handler outcome, identity matching, nested/concurrent behavior, Future limitations, Stream ordering, Rx lifetime, and broad-catch guidance.
- Keep Raise implementation and cross-package control-runtime work out of scope.

## Test and Verification Plan

- Source/token: stable identity, initial/requested state, idempotent cancellation, separate-source isolation, sequential/concurrent runs, and cancellation after prior completion.
- Handler: sync/async and nullable successes, pre-cancel callback suppression, prompt mid-flight cancellation, ordinary error/stack preservation, same-source nesting, and cross-source signal matching.
- Future guard: lazy start, success/error, cancellation winner, continued losing work, late-error consumption, and registration cleanup.
- Stream guard: pre-listen cancellation, normal/error completion, active and paused cancellation, immediate upstream teardown, teardown failure, downstream cancellation, broadcast listeners, event ordering, and `guardedBy` parity.
- Rx adapter: fresh source per subscription, cancellation on disposal, normal-termination disposal, and no cancellation event delivered to an already-cancelled subscriber.
- Add external compile-fail checks proving consumers cannot construct a token/exception or invoke token-side `cancel()`.
- Run formatting, strict analysis, full tests with chain stack traces and coverage, example analysis/execution, Dartdoc generation, `git diff --check`, and targeted searches for removed names.

## Assumptions

- This task prepares the prerelease locally; it does not publish, tag, commit, or push.
- `CancellableOutcome` is intentionally pattern-match oriented and adds no nullable getter, equality contract, or implicit fallback.
- Cancellation remains lifetime control flow, never an `Either.Left` or application error.

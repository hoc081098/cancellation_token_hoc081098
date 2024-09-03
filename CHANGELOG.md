## 2.0.0 - Sep 3, 2022

- Require Dart `^3.0.0` 🎉.
- Update `rxdart_ext` to `^0.3.0`.
- Change `guardFuture<T>(FutureOr<T> Function())` to `guardFuture<T>(FutureOr<T> Function(CancellationToken))`.

## 1.0.0 - Sep 18, 2022

- This is our first stable release 🎉.

## 1.0.0-beta.04 - Sep 16, 2022

- Refactor `guardStream` / `guardedBy`: pause and resume the returned `StreamSubscription` properly.

## 1.0.0-beta.03 - Sep 9, 2022

- Override `CancellationToken.toString()` for better debugging.

## 1.0.0-beta.02 - Sep 6, 2022

- Remove `meta` dependency.
- Optimize `CancellationToken` implementation.

## 1.0.0-beta.01 - Sep 4, 2022

- Initial version.

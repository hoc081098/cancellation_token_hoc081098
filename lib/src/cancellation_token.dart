import 'dart:async';

import 'package:rxdart_ext/single.dart';

/// TODO(docs)
class CancellationToken {
  List<Completer<Never>>? _completers = <Completer<Never>>[];
  var _isCancelled = false;

  /// Returns `true` if the token was cancelled.
  bool get isCancelled => _isCancelled;

  /// Cancel all operations with this token.
  /// If the token was already cancelled, this method does nothing.
  ///
  /// Calling this method will cancel all futures created by [guardFuture],
  /// and cancel all [Single]s created by [useCancellationToken].
  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;

    final completers = [..._completers!];
    _completers!.clear();
    _completers = null;

    for (final completer in completers) {
      completer.completeError(const CancellationException());
    }
  }

  /// Throw a [SimpleCancellationException] if this token was cancelled.
  /// This function should be used in async functions.
  /// For synchronous functions use [isCancelled] instead.
  void guard() {
    if (_isCancelled) {
      throw const CancellationException();
    }
  }

  void _addCompleter(Completer<Never> completer) {
    if (_isCancelled) {
      completer.completeError(const CancellationException());
    } else {
      _completers?.add(completer);
    }
  }

  void _removeCompleter(Completer<void> completer) =>
      _completers?.remove(completer);
}

/// TODO(docs)
Single<T> useCancellationToken<T>(
    Future<T> Function(CancellationToken cancelToken) block) {
  final controller = StreamController<T>(sync: true);

  CancellationToken? cancelToken;
  StreamSubscription<T>? subscription;

  controller.onListen = () =>
      subscription = block(cancelToken = CancellationToken()).asStream().listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
  controller.onCancel = () {
    final future = subscription?.cancel();
    subscription = null;

    cancelToken?.cancel();
    cancelToken = null;

    return future;
  };

  // ignore: invalid_use_of_internal_member
  return Single.safe(controller.stream);
}

/// Provide [onCancelStream] extension method on [CancellationToken].
extension OnCancelStreamCancellationTokenExtension on CancellationToken {
  /// Returns a Stream that emits a [SimpleCancellationException] as error event
  /// and a done event when this token is cancelled.
  ///
  /// This return [Stream] can be used with `rxdart` [TakeUntilExtension.takeUntil] operator,
  /// eg: `aStream.takeUntil(token.onCancelStream())`.
  ///
  /// ### Example
  /// ```dart
  /// final token = CancellationToken();
  /// final stream = Rx.fromCallable(() async {
  ///   print('start...');
  ///
  ///   token.guard();
  ///   await Future<void>.delayed(const Duration(milliseconds: 100));
  ///   token.guard();
  ///
  ///   print('Step 1');
  ///
  ///   token.guard();
  ///   await Future<void>.delayed(const Duration(milliseconds: 100));
  ///   token.guard();
  ///
  ///   print('Step 2');
  ///
  ///   token.guard();
  ///   await Future<void>.delayed(const Duration(milliseconds: 100));
  ///   token.guard();
  ///
  ///   print('done...');
  ///   return 42;
  /// }).takeUntil(token.onCancelStream());
  ///
  /// stream.listen(print, onError: print);
  ///
  /// await Future<void>.delayed(const Duration(milliseconds: 120));
  /// token.cancel();
  ///
  /// await Future<void>.delayed(const Duration(milliseconds: 800));
  /// print('exit...');
  /// ```
  ///
  /// The console will print:
  /// ```
  /// start...
  /// Step 1
  /// Instance of 'CancellationException'
  /// exit
  /// ```
  Stream<Never> onCancelStream() {
    if (isCancelled) {
      return Stream.error(const CancellationException());
    }

    final controller = StreamController<Never>(sync: true);
    Completer<Never>? completer;
    StreamSubscription<Never>? subscription;

    void emitAndClose() {
      controller.addError(const CancellationException());
      controller.close();
    }

    controller.onListen = () {
      if (isCancelled) {
        emitAndClose();
        return;
      }

      completer = Completer<Never>();
      _addCompleter(completer!);

      subscription = completer!.future.asStream().listen(
        null,
        onError: (Object error) {
          if (error is CancellationException) {
            // [CancellationToken.cancel] clears the [CancellationToken._completers] list,
            // so we clear the [completer] here.
            completer = null;
            emitAndClose();
          }
        },
      );
    };
    controller.onCancel = () {
      if (completer != null) {
        _removeCompleter(completer!);
        completer = null;
      }

      final future = subscription?.cancel();
      subscription = null;
      return future;
    };

    return controller.stream;
  }
}

/// Provide [guardFuture] extension method on [CancellationToken].
extension GuardFutureCancellationTokenExtension on CancellationToken {
  /// Run [action] and throw a [SimpleCancellationException] when this token is cancelled.
  ///
  /// ### Example
  /// ```dart
  /// final token = CancellationToken();
  /// final future = token.guardFuture(() async {
  ///   print('start...');
  ///
  ///   token.guard();
  ///   await Future<void>.delayed(const Duration(milliseconds: 100));
  ///   token.guard();
  ///
  ///   print('Step 1');
  ///
  ///   token.guard();
  ///   await Future<void>.delayed(const Duration(milliseconds: 100));
  ///   token.guard();
  ///
  ///   print('Step 2');
  ///
  ///   token.guard();
  ///   await Future<void>.delayed(const Duration(milliseconds: 100));
  ///   token.guard();
  ///
  ///   print('done...');
  ///   return 42;
  /// });
  ///
  /// future.then(print, onError: print);
  ///
  /// await Future<void>.delayed(const Duration(milliseconds: 120));
  /// token.cancel();
  /// await Future<void>.delayed(const Duration(milliseconds: 800));
  /// print('exit...');
  /// ```
  ///
  /// The console will print:
  /// ```
  /// start...
  /// Step 1
  /// Instance of 'CancellationException'
  /// exit...
  /// ```
  Future<T> guardFuture<T>(FutureOr<T> Function() action) {
    if (isCancelled) {
      return Future.error(const CancellationException());
    }

    final completer = Completer<Never>();
    _addCompleter(completer);

    return Future.any<T>([completer.future, Future.sync(action)])
        .whenComplete(() => _removeCompleter(completer));
  }
}

/// A exception that is used to indicate that a [CancellationToken] was cancelled.
class CancellationException implements Exception {
  /// Construct a [CancellationException].
  const CancellationException();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancellationException && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'CancellationException';
}

import 'dart:async';

import 'package:rxdart_ext/single.dart';

import 'cancellation_exception.dart';

/// A token for controlling the cancellation of async operations.
/// A single token can be used for multiple async operations.
///
/// The token can be used with [Future] via [guardFuture] extension method,
/// and with [Stream] via [guardStream] extension method.
///
/// See also:
/// * [guardFuture]
/// * [guardStream]
/// * [GuardedByStreamExtension.guardedBy]
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

/// Returns a [Single] that, when listening to it, calls a [block] function you specify
/// and then emits the value returned from that function.
///
/// When the future which is returned from [block] completes, this [Single] will fire one event, either
/// data or error, and then close with a done-event.
///
/// When stream subscription is cancelled (call [StreamSubscription.cancel] or `Stream.listen(cancelOnError: true)`),
/// [CancellationToken.cancel] will be called, so we can cancel [block]
/// (because [CancellationToken.guard] will throw a [CancellationException]).
///
/// We should use [CancellationToken.guard] or [CancellationToken.isCancelled]
/// inside [block] to check if the token was cancelled.
Single<T> useCancellationToken<T>(
        Future<T> Function(CancellationToken cancelToken) block) =>
    // ignore: invalid_use_of_internal_member
    Single.safe(
      Rx.using<T, CancellationToken>(
        () => CancellationToken(),
        (token) => block(token).asStream(),
        (token) => token.cancel(),
      ),
    );

/// Provide [guardStream] extension method on [CancellationToken].
extension GuardStreamCancellationTokenExtension on CancellationToken {
  /// Returns a [Stream] forwards all events from the source [stream]
  /// until this token is cancelled.
  ///
  /// When cancelling this token, the result stream will emit a [SimpleCancellationException]
  /// as an error event and followed by a done event.
  ///
  /// ### Example
  ///
  /// ```dart
  /// final token = CancellationToken();
  /// final stream = token.guardStream(Rx.fromCallable(() async {
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
  /// }));
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
  Stream<T> guardStream<T>(Stream<T> stream) {
    if (isCancelled) {
      return Stream.error(const CancellationException());
    }

    final controller = StreamController<T>(sync: true);
    Completer<Never>? completer;
    StreamSubscription<T>? subscription;
    StreamSubscription<Never>? completerSubscription;

    void emitCancellationExceptionAndClose([
      CancellationException? error,
      StackTrace? st,
    ]) {
      if (error != null && st != null) {
        controller.addError(error, st);
      } else {
        controller.addError(const CancellationException());
      }
      controller.close();
    }

    controller.onListen = () {
      if (isCancelled) {
        emitCancellationExceptionAndClose();
        return;
      }

      completer = Completer<Never>();
      _addCompleter(completer!);

      completerSubscription = completer!.future.asStream().listen(
        null,
        onError: (Object error, StackTrace st) {
          if (error is CancellationException) {
            // [CancellationToken.cancel] clears the [CancellationToken._completers] list,
            // so we clear the [completer] here.
            completer = null;
            emitCancellationExceptionAndClose(error, st);
          }
        },
      );

      subscription = stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    };
    controller.onCancel = () {
      if (completer != null) {
        _removeCompleter(completer!);
        completer = null;
      }

      final future1 = completerSubscription?.cancel();
      final future2 = subscription?.cancel();

      completerSubscription = null;
      subscription = null;

      return future1 != null && future2 != null
          ? Future.wait([future1, future2])
          : (future1 ?? future2);
    };

    return controller.stream;
  }
}

/// Provide [guardedBy] extension method on [Stream].
extension GuardedByStreamExtension<T> on Stream<T> {
  /// Returns a [Stream] forwards all events from the source [stream]
  /// until this token is cancelled.
  ///
  /// When cancelling this token, the result stream will emit a [SimpleCancellationException]
  /// as an error event and followed by a done event.
  ///
  /// This is equivalent to `token.guardStream(this)`.
  ///
  /// ### Example
  ///
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
  /// }).guardedBy(token);
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
  Stream<T> guardedBy(CancellationToken token) => token.guardStream(this);
}

/// Provide [guardFuture] extension method on [CancellationToken].
extension GuardFutureCancellationTokenExtension on CancellationToken {
  /// Run [action] and throw a [SimpleCancellationException] when this token is cancelled.
  ///
  /// ### Example
  ///
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

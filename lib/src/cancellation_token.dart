import 'dart:async';

import 'package:rxdart_ext/single.dart';

/// TODO(docs)
class CancellationToken {
  List<Completer<Never>>? _completers = <Completer<Never>>[];
  var _isCancelled = false;

  /// TODO(docs)
  bool get isCancelled => _isCancelled;

  /// Cancel this token.
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

/// Returns a Stream that emits a [SimpleCancellationException] as error event
/// and a done event when the given [token] is cancelled.
Stream<Never> onCancel(CancellationToken token) {
  if (token.isCancelled) {
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
    if (token.isCancelled) {
      emitAndClose();
      return;
    }

    completer = Completer<Never>();
    token._addCompleter(completer!);

    subscription = completer!.future.asStream().listen(
      null,
      onError: (Object error) {
        if (error is CancellationException) {
          emitAndClose();
        }
      },
    );
  };
  controller.onCancel = () {
    if (completer != null) {
      token._removeCompleter(completer!);
      completer = null;
    }

    final future = subscription?.cancel();
    subscription = null;
    return future;
  };

  return controller.stream;
}

/// Run [action] with a [CancellationToken].
Future<T> cancellationGuard<T>(
  CancellationToken? token,
  FutureOr<T> Function() action,
) {
  if (token == null) {
    return Future.sync(action);
  }

  if (token.isCancelled) {
    return Future.error(const CancellationException());
  }

  final completer = Completer<Never>();
  token._addCompleter(completer);

  return Future.any<T>([completer.future, Future.sync(action)])
      .whenComplete(() => token._removeCompleter(completer));
}

/// A exception that is used to indicate that a [CancellationToken] was cancelled.
class CancellationException implements Exception {
  /// Construct a [CancellationException].
  const CancellationException();
}

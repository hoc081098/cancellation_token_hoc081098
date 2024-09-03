import 'package:cancellation_token_hoc081098/cancellation_token_hoc081098.dart';
import 'package:rxdart_ext/rxdart_ext.dart';

final separator = '-' * 30;

void onError(Object error, StackTrace stackTrace) =>
    print('[onError] error: $error, stackTrace: $stackTrace');

void main() async {
  print('${separator}guardFutureExample$separator');
  await guardFutureExample();

  print('${separator}guardStreamExample$separator');
  await guardStreamExample();

  print('${separator}reuseTokenExample$separator');
  await reuseTokenExample();

  print('${separator}useCancellationToken$separator');
  await useCancellationTokenExample();

  await delay(2000);
  print('${separator}done$separator');
}

Future<void> guardStreamExample() async {
  final token = CancellationToken();

  // Can use stream.guardedBy(token) instead of token.guardStream(stream).
  final stream = token.guardStream(Rx.fromCallable(() async {
    print('start...');

    token.guard();
    await delay(100);
    token.guard();

    print('Step 1');

    token.guard();
    await delay(100);
    token.guard();

    print('Step 2');

    token.guard();
    await delay(100);
    token.guard();

    print('done...');
    return 42;
  }));

  stream.listen(print, onError: onError);

  await delay(120);
  token.cancel();
  await delay(800);
  print('exit...');
}

Future<void> guardFutureExample() async {
  final token = CancellationToken();

  final future = token.guardFuture((token) async {
    print('start...');

    token.guard();
    await delay(100);
    token.guard();

    print('Step 1');

    token.guard();
    await delay(100);
    token.guard();

    print('Step 2');

    token.guard();
    await delay(100);
    token.guard();

    print('done...');
    return 42;
  });

  future.then(print, onError: onError).ignore();

  await delay(120);
  token.cancel();
  await delay(800);
  print('exit...');
}

Future<void> reuseTokenExample() async {
  final token = CancellationToken();

  final future1 = token.guardFuture((token) async {
    for (var i = 0; i < 10; i++) {
      token.guard();

      print('future1: start $i');
      await delay(100);
      print('future1: end $i');

      token.guard();
    }
  });

  final future2 = token.guardFuture((token) async {
    for (var i = 0; i < 10; i++) {
      token.guard();

      print('future2: start $i');
      await delay(100);
      print('future2: end $i');

      token.guard();
    }
  });

  Future.wait([future1, future2])
      .then((result) => print('result: $result'), onError: onError)
      .ignore();

  await delay(250);
  token.cancel();
  await delay(800);
  print('exit...');
}

Future<void> useCancellationTokenExample() async {
  final single = useCancellationToken((token) async {
    print('start...');

    token.guard();
    await delay(100);
    token.guard();

    print('Step 1');

    token.guard();
    await delay(100);
    token.guard();

    print('Step 2');

    token.guard();
    await delay(100);
    token.guard();

    print('done...');
    return 42;
  });

  final subscription = single.listen(print, onError: onError);

  await delay(120);
  await subscription.cancel();
  await delay(800);
  print('exit...');
}

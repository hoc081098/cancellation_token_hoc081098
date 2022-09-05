import 'package:cancellation_token_hoc081098/cancellation_token_hoc081098.dart';
import 'package:rxdart_ext/rxdart_ext.dart';

void main() async {
  await guardFutureExample();
  print('-' * 80);
  await guardStreamExample();
  print('-' * 80);
  await reuseTokenExample();
}

Future<void> guardStreamExample() async {
  final token = CancellationToken();
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

  stream.listen(print, onError: print);

  await delay(120);
  token.cancel();
  await delay(800);
  print('exit...');
}

Future<void> guardFutureExample() async {
  final token = CancellationToken();

  final future = token.guardFuture(() async {
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

  // ignore: unawaited_futures
  future.then(print, onError: print);

  await delay(120);
  token.cancel();
  await delay(800);
  print('exit...');
}

Future<void> reuseTokenExample() async {
  final token = CancellationToken();
  final future1 = token.guardFuture(() async {
    for (var i = 0; i < 10; i++) {
      token.guard();

      print('future1: start $i');
      await delay(100);
      print('future1: end $i');

      token.guard();
    }
  });
  final future2 = token.guardFuture(() async {
    for (var i = 0; i < 10; i++) {
      token.guard();

      print('future2: start $i');
      await delay(100);
      print('future2: end $i');

      token.guard();
    }
  });

  // ignore: unawaited_futures
  Future.wait([future1, future2]).then(
    (result) => print('result: $result'),
    onError: (Object e, StackTrace s) => print('error: $e, $s'),
  );

  await delay(250);
  token.cancel();
  await delay(800);
  print('exit...');
}

import 'package:cancellation_token_hoc081098/cancellation_token_hoc081098.dart';

void main() async {
  final token = CancellationToken();
  final future = token.guardFuture(() async {
    print('start...');

    token.guard();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    token.guard();

    print('Step 1');

    token.guard();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    token.guard();

    print('Step 2');

    token.guard();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    token.guard();

    print('done...');
    return 42;
  });

  // ignore: unawaited_futures
  future.then(print, onError: print);

  await Future<void>.delayed(const Duration(milliseconds: 120));
  token.cancel();
  await Future<void>.delayed(const Duration(milliseconds: 800));
  print('exit...');
}

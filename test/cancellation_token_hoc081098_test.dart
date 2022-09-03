import 'dart:async';

import 'package:cancellation_token_hoc081098/src/cancellation_token.dart';
import 'package:rxdart_ext/rxdart_ext.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

final isCancellationException = isA<CancellationException>();

void main() {
  group('CancellationToken', () {
    group('isCancelled', () {
      test('true', () {
        final token = CancellationToken();
        token.cancel();
        expect(token.isCancelled, isTrue);
      });

      test('false', () {
        final token = CancellationToken();
        expect(token.isCancelled, isFalse);
      });
    });

    group('guardFuture', () {
      test('do not cancel', () {
        {
          final token = CancellationToken();
          final future = token.guardFuture(() async {
            await delay(100);
            return 42;
          });
          expect(future, completion(42));
        }

        {
          final token = CancellationToken();
          final future = token.guardFuture(() async {
            await delay(100);
            throw Exception();
          });
          expect(future, throwsException);
        }
      });

      test('cancel', () async {
        final list = <int>[];
        final token = CancellationToken();
        final future = token.guardFuture(() async {
          list.add(1);

          await delay(100);

          list.add(2);

          token.guard();

          list.add(3);

          await delay(500);

          list.add(4);

          token.guard();

          await delay(500);

          list.add(5);

          return 42;
        });

        await delay(100);
        token.cancel();

        await expectLater(future, throwsA(isCancellationException));
        expect(list, [1, 2, 3]);
      });
    });

    group('guardStream / guardedBy', () {
      test('cancel', () async {
        final token = CancellationToken();
        final steps = <String>[];

        final stream = Rx.fromCallable(() async {
          steps.add('start...');

          token.guard();
          await delay(100);
          token.guard();

          steps.add('Step 1');

          token.guard();
          await delay(100);
          token.guard();

          steps.add('Step 2');

          token.guard();
          await delay(100);
          token.guard();

          steps.add('done...');
          return 42;
        }).guardedBy(token);

        expect(
          stream,
          emitsInOrder(
            <Object>[
              emitsError(isCancellationException),
              emitsDone,
            ],
          ),
        );

        await delay(120);
        token.cancel();
        await delay(500);

        expect(steps, ['start...', 'Step 1']);
      });

      test('cancel before listen #1', () {
        final token = CancellationToken()..cancel();

        expect(
          Stream.value(1).guardedBy(token),
          emitsInOrder(
            <Object>[
              emitsError(isCancellationException),
              emitsDone,
            ],
          ),
        );
      });

      test('cancel before listen #2', () async {
        final token = CancellationToken();

        // ignore: unawaited_futures
        delay(50).then((_) => token.cancel());

        await delay(100);

        expect(
          Stream.value(1).guardedBy(token),
          emitsInOrder(
            <Object>[
              emitsError(isCancellationException),
              emitsDone,
            ],
          ),
        );
      });

      test('cancel before listen #3', () async {
        {
          final token = CancellationToken()..cancel();

          final stream = Stream.value(1)
              .doOnListen(() => expect(false, true))
              .guardedBy(token);

          expect(
            stream,
            emitsInOrder(
              <Object>[
                emitsError(isCancellationException),
                emitsDone,
              ],
            ),
          );
        }

        {
          final token = CancellationToken();

          final stream = Stream.value(1)
              .doOnListen(() => expect(false, true))
              .guardedBy(token);

          await delay(10);
          token.cancel();

          expect(
            stream,
            emitsInOrder(
              <Object>[
                emitsError(isCancellationException),
                emitsDone,
              ],
            ),
          );
        }
      });

      test('do not cancel', () async {
        final token = CancellationToken();

        await expectLater(
          Stream.value(1).guardedBy(token),
          emitsInOrder(<Object>[
            emits(1),
            emitsDone,
          ]),
        );
        await delay(200);
      });
    });

    group('useCancellationToken', () {
      test('do not cancel', () async {
        final steps = <String>[];

        final single = useCancellationToken((token) async {
          steps.add('start...');

          token.guard();
          await delay(100);
          token.guard();

          steps.add('Step 1');

          token.guard();
          await delay(100);
          token.guard();

          steps.add('Step 2');

          token.guard();
          await delay(100);
          token.guard();

          steps.add('done...');
          return 42;
        });

        final subscription = single.listen(
          expectAsync1((_) => expect(false, true), count: 0),
          onError: expectAsync2((_, __) => expect(false, true), count: 0),
          onDone: expectAsync0(() => expect(false, true), count: 0),
        );

        await delay(120);
        await subscription.cancel();
        await delay(500);

        expect(steps, ['start...', 'Step 1']);
      });

      test('do not cancel', () async {
        final steps = <String>[];

        final single = useCancellationToken((token) async {
          steps.add('start...');

          token.guard();
          await delay(100);
          token.guard();

          steps.add('Step 1');

          token.guard();
          await delay(100);
          token.guard();

          steps.add('Step 2');

          token.guard();
          await delay(100);
          token.guard();

          steps.add('done...');
          return 42;
        });

        await expectLater(
          single,
          emitsInOrder(<Object>[42, emitsDone]),
        );
        expect(steps, ['start...', 'Step 1', 'Step 2', 'done...']);
      });
    });
  });
}

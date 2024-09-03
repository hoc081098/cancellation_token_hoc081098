import 'dart:async';

import 'package:cancellation_token_hoc081098/cancellation_token_hoc081098.dart';
import 'package:rxdart_ext/rxdart_ext.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

final isCancellationException = isA<CancellationException>();

void main() {
  group('CancellationToken', () {
    test('toString', () {
      expect(
        CancellationToken().toString(),
        'CancellationToken { isCancelled: false }',
      );

      expect(
        (CancellationToken()..cancel()).toString(),
        'CancellationToken { isCancelled: true }',
      );
    });

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
          final future = token.guardFuture((_) async {
            await delay(100);
            return 42;
          });
          expect(future, completion(42));
        }

        {
          final token = CancellationToken();
          final future = token.guardFuture((_) async {
            await delay(100);
            throw Exception();
          });
          expect(future, throwsException);
        }
      });

      test('cancel', () async {
        final list = <int>[];
        final token = CancellationToken();
        final future = token.guardFuture((token) async {
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

      test('cancel before', () async {
        final token = CancellationToken()..cancel();
        expect(token.guardFuture((_) => 1), throwsA(isCancellationException));
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

      test('pause resume', () async {
        {
          final subscription = Rx.timer(1, const Duration(milliseconds: 300))
              .guardedBy(CancellationToken())
              .listen(expectAsync1((v) => expect(v, 1), count: 1));

          subscription.pause();
          await delay(100);
          subscription.resume();
        }

        {
          final token = CancellationToken();

          final subscription = Rx.timer(1, const Duration(milliseconds: 300))
              .guardedBy(token)
              .listen(
                expectAsync1((_) => expect(false, true), count: 0),
                onError: expectAsync1(
                  (Object e) => expect(e, isCancellationException),
                  count: 1,
                ),
              );

          subscription.pause();
          token.cancel();

          await delay(100);
          subscription.resume();
        }
      });
    });

    group('useCancellationToken', () {
      test('cancel #1', () async {
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

      test('cancel #2', () async {
        late final CancellationToken token;

        final single = useCancellationToken((cancelToken) async {
          token = cancelToken;
          return 42;
        });

        await single.listen(null).cancel();
        expect(token.isCancelled, isTrue);
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

  group('CancellationException', () {
    test('toString', () {
      expect(
        const CancellationException().toString(),
        'CancellationException',
      );
    });
  });
}

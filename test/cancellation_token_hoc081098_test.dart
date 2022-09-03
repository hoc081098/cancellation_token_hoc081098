import 'dart:async';

import 'package:cancellation_token_hoc081098/src/cancellation_token.dart';
import 'package:rxdart_ext/rxdart_ext.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

final isCancellationException = isA<CancellationException>();

void main() {
  group('CancellationToken', () {
    group('cancellationGuard', () {
      test('do not cancel', () {
        {
          final token = CancellationToken();
          final future = cancellationGuard(token, () async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return 42;
          });
          expect(future, completion(42));
        }

        {
          final token = CancellationToken();
          final future = cancellationGuard(token, () async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            throw Exception();
          });
          expect(future, throwsException);
        }
      });

      test('cancel', () async {
        final list = <int>[];
        final token = CancellationToken();
        final future = cancellationGuard(token, () async {
          list.add(1);

          await Future<void>.delayed(const Duration(milliseconds: 100));

          list.add(2);

          token.guard();

          list.add(3);

          await Future<void>.delayed(const Duration(milliseconds: 500));

          list.add(4);

          token.guard();

          await Future<void>.delayed(const Duration(milliseconds: 500));

          list.add(5);

          return 42;
        });

        await Future<void>.delayed(const Duration(milliseconds: 100));
        token.cancel();

        await expectLater(future, throwsA(isCancellationException));
        expect(list, [1, 2, 3]);
      });
    });

    group('onCancelStream', () {
      test('takeUntil and cancel', () async {
        final token = CancellationToken();
        final steps = <String>[];

        final stream = Rx.fromCallable(() async {
          steps.add('start...');

          token.guard();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          token.guard();

          steps.add('Step 1');

          token.guard();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          token.guard();

          steps.add('Step 2');

          token.guard();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          token.guard();

          steps.add('done...');
          return 42;
        }).takeUntil(token.onCancelStream());

        expect(
          stream,
          emitsInOrder(
            <Object>[
              emitsError(isCancellationException),
              emitsDone,
            ],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 120));
        token.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(steps, ['start...', 'Step 1']);
      });

      test('cancel before listen #1', () {
        final token = CancellationToken()..cancel();

        expect(
          token.onCancelStream(),
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

        Future<void>.delayed(const Duration(milliseconds: 50), () {
          token.cancel();
        });

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          token.onCancelStream(),
          emitsInOrder(
            <Object>[
              emitsError(isCancellationException),
              emitsDone,
            ],
          ),
        );
      });

      test('do not cancel', () async {
        final token = CancellationToken();

        final subscription = token.onCancelStream().listen(
              expectAsync1((_) => expect(false, true), count: 0),
              onError: expectAsync2((_, __) => expect(false, true), count: 0),
              onDone: expectAsync0(() => expect(false, true), count: 0),
            );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        await subscription.cancel();
      });
    });
  });
}

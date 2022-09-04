# cancellation_token_hoc081098

## Author: [Petrus Nguyễn Thái Học](https://github.com/hoc081098)

[![Dart CI](https://github.com/hoc081098/cancellation_token_hoc081098/actions/workflows/dart.yml/badge.svg)](https://github.com/hoc081098/cancellation_token_hoc081098/actions/workflows/dart.yml)
[![Pub](https://img.shields.io/pub/v/cancellation_token_hoc081098)](https://pub.dev/packages/cancellation_token_hoc081098)
[![Pub](https://img.shields.io/pub/v/cancellation_token_hoc081098?include_prereleases)](https://pub.dev/packages/cancellation_token_hoc081098)
[![codecov](https://codecov.io/gh/hoc081098/cancellation_token_hoc081098/branch/master/graph/badge.svg)](https://codecov.io/gh/hoc081098/cancellation_token_hoc081098)
[![GitHub](https://img.shields.io/github/license/hoc081098/cancellation_token_hoc081098)](https://opensource.org/licenses/MIT)
[![Style](https://img.shields.io/badge/style-lints-40c4ff.svg)](https://pub.dev/packages/lints)
[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fhoc081098%2Fcancellation_token_hoc081098&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)

Dart Cancellation Token.
Inspired by CancellationToken in C#.
A Dart utility package for easy async task cancellation.

## Features

 - [x] Reuse a single `CancellationToken` for multiple tasks, and cancel all of them with a single call to `CancellationToken.cancel()`.
 - [x] Cancel futures and clean-up resources with `token.guardFuture(block)`.
 - [x] Cancel streams and clean-up resources with `token.guardStream(stream)`/`Stream.guardedBy(token)`.
 - [x] Integration with `rxdart`/`rxdart_ext` with `useCancellationToken`. 
 - [x] Very simple, lightweight, and easy to use.

## Getting started

### 1. Add dependency

```yaml
dependencies:
  cancellation_token_hoc081098: <latest_version>
```

### 2. Import

```dart
import 'package:cancellation_token_hoc081098/cancellation_token_hoc081098.dart';
```

## Usage

### 1. `guardFuture`

```dart
void main() async {
  // Create a CancellationToken
  final token = CancellationToken();

  // Simulate a long-running task
  Future<void> doWork(int number) async {
    print('doWork($number) started');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    print('doWork($number) finished');
  }

  // Guard a future
  final future = token.guardFuture(() async {
    for (var i = 0; i < 10; i++) {
      token.guard(); // Throws if token is cancelled
      await doWork(i);
      token.guard(); // Throws if token is cancelled
    }
    return 42;
  });

  future
      .then((v) => print('Result: $v'))
      .onError<Object>((e, st) => print('Error: $e'));

  // Cancel the token after 300ms
  await Future<void>.delayed(const Duration(milliseconds: 300));

  // Cancel the token
  token.cancel();

  // Wait a little longer to ensure that the future is cancelled
  await Future<void>.delayed(const Duration(seconds: 2));

  // Output:
  // doWork(0) started
  // doWork(0) finished
  // doWork(1) started
  // doWork(1) finished
  // doWork(2) started
  // Error: CancellationException.
  // doWork(2) finished
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/hoc081098/cancellation_token_hoc081098/issues).

## License

```
MIT License

Copyright (c) 2022 Petrus Nguyễn Thái Học
```
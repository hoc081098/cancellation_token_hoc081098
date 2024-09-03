/// A exception that is used to indicate that a [CancellationToken] was cancelled.
final class CancellationException implements Exception {
  /// Construct a [CancellationException].
  const CancellationException();

  @override
  String toString() => 'CancellationException';
}

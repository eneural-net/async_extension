import 'dart:async';

/// Lazily computes a value at most once and caches either the result or error.
///
/// The computation may be synchronous or asynchronous. Subsequent calls return
/// the cached value, rethrow the cached error, or await the in-flight Future.
///
/// If [resolve] is true, the computation is started eagerly.
class ComputeOnce<V> {
  final FutureOr<V> Function() _call;

  /// Creates a [ComputeOnce] wrapping [_call].
  ///
  /// If [resolve] is true, starts resolving immediately.
  ComputeOnce(this._call, {bool resolve = true}) {
    if (resolve) {
      resolveAsync();
    }
  }

  /// Returns the cached value if already resolved, otherwise `null`.
  V? get value => _result?.value;

  /// Returns the cached error and stack trace if resolution failed, otherwise `null`.
  ({Object error, StackTrace stackTrace})? get error {
    var result = _result;
    if (result == null) return null;

    var error = result.error;
    var stackTrace = result.stackTrace;
    if (error == null) return null;

    return (error: error, stackTrace: stackTrace!);
  }

  /// Whether the cached result is an error.
  bool get hasError => _result?.error != null;

  ({V? value, Object? error, StackTrace? stackTrace})? _result;

  /// Whether the computation has completed (with value or error).
  bool get isResolved => _result != null;

  Future<V>? _future;

  /// Resolves the computation and returns the value (as [V]) or a [Future].
  ///
  /// If already resolved, returns the cached value or rethrows the cached error.
  /// If a resolution is in progress, returns the same Future.
  FutureOr<V> resolve() {
    var result = _result;
    if (result != null) {
      var error = result.error;
      if (error != null) {
        Error.throwWithStackTrace(error, result.stackTrace!);
      }
      return result.value as V;
    }

    var future = _future;
    if (future != null) return future;

    final FutureOr<V> call;
    try {
      call = _call();

      if (call is Future<V>) {
        future = _future = call;

        future.then(
          (value) {
            _result = (value: value, error: null, stackTrace: null);
            if (identical(future, _future)) {
              _future = null;
            }
          },
          onError: (e, s) {
            _result = (value: null, error: e, stackTrace: s);
            if (identical(future, _future)) {
              _future = null;
            }
          },
        );

        return future;
      } else {
        _result = (value: call, error: null, stackTrace: null);
        return call;
      }
    } catch (e, s) {
      _result = (value: null, error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Resolves the computation asynchronously.
  ///
  /// Always returns a [Future] that completes with the value (as [V]) or error.
  ///
  /// If a resolution is in progress, returns the same Future.
  /// If already resolved, returns an already completed Future.
  Future<V> resolveAsync() {
    var result = _result;
    if (result != null) {
      var error = result.error;
      if (error != null) {
        var stackTrace = result.stackTrace;
        return Future.error(error, stackTrace);
      }
      return Future.value(result.value as V);
    }

    var future = _future;
    if (future != null) return future;

    future = _future = Future(_call);

    future.then(
      (value) {
        _result = (value: value, error: null, stackTrace: null);
        if (identical(future, _future)) {
          _future = null;
        }
      },
      onError: (e, s) {
        _result = (value: null, error: e, stackTrace: s);
        if (identical(future, _future)) {
          _future = null;
        }
      },
    );

    return future;
  }

  /// Chains a callback to the resolved value.
  ///
  /// Equivalent to calling [resolveAsync] and then "[then]" on the resulting [Future].
  Future<R> then<R>(FutureOr<R> Function(V value) onValue,
          {Function? onError}) =>
      resolveAsync().then(onValue, onError: onError);
}

import 'dart:async';

import 'async_extension_base.dart';

/// Signature for a computation executed by [ComputeOnce].
///
/// The callback may return a value synchronously or a [Future] that completes
/// with the value [V] or an error.
typedef ComputeOnceCall<V> = FutureOr<V> Function();

/// Lazily computes a value at most once and caches either the result or error.
///
/// The computation may be synchronous or asynchronous. Subsequent calls return
/// the cached value, rethrow the cached error, or await the in-flight Future.
///
/// If [resolve] is true, the computation is started eagerly.
class ComputeOnce<V> {
  /// The computation callback.
  ///
  /// This is cleared after a successful or failed [resolve]/[resolveAsync] to
  /// release references and prevent the computation from being invoked again.
  ComputeOnceCall<V>? _call;

  /// Creates a [ComputeOnce] wrapping [_call].
  ///
  /// If [resolve] is true, starts resolving immediately.
  ComputeOnce(ComputeOnceCall<V> call, {bool resolve = true}) : _call = call {
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

  /// Whether the computation is currently in progress and not yet resolved.
  bool get isResolving => _result == null && _future != null;

  Future<V>? _future;

  /// Resolves the computation and returns its value ([V]) or a [Future<V>].
  ///
  /// - If already resolved, returns the cached value or handles/rethrows
  ///   the cached error.
  /// - If a resolution is in progress, returns the same in-flight [Future].
  /// - When the computation completes (success or failure), [onCompute]
  ///   is invoked with the resulting value or error.
  ///
  /// Parameters:
  /// - [throwError]:
  ///   When `true` (default), any error is rethrown with its original
  ///   [StackTrace]. When `false`, errors are handled by [onError] or
  ///   [onErrorValue].
  ///
  /// - [onError]:
  ///   Optional error handler invoked when an error occurs and
  ///   [throwError] is `false`. Receives the error object and its
  ///   [StackTrace]. Its return value is used as the resolved value.
  ///
  /// - [onErrorValue]:
  ///   Fallback value (default null) returned when an error occurs,
  ///   [throwError] is `false`, and [onError] is not provided.
  FutureOr<V> resolve({
    bool throwError = true,
    FutureOr<V> Function(Object error, StackTrace stackTrace)? onError,
    V? onErrorValue,
  }) {
    var result = _result;
    if (result != null) {
      var error = result.error;
      if (error != null) {
        var stackTrace = result.stackTrace!;
        if (throwError) {
          Error.throwWithStackTrace(error, stackTrace);
        } else if (onError != null) {
          return onError(error, stackTrace);
        } else {
          return onErrorValue as V;
        }
      }
      return result.value as V;
    }

    var future = _future;
    if (future != null) {
      if (!throwError) {
        return future.catchError(onError ?? (_) => onErrorValue);
      }
      return future;
    }

    final FutureOr<V> call;
    try {
      var computer = _call ?? (throw StateError("Null `_call`"));
      call = computer();

      if (call is Future<V>) {
        future = _future = call;

        future.then(
          (value) {
            _result = (value: value, error: null, stackTrace: null);
            if (identical(future, _future)) {
              _future = null;
            }
            _call = null;
            onCompute(value, null, null);
          },
          onError: (e, s) {
            _result = (value: null, error: e, stackTrace: s);
            if (identical(future, _future)) {
              _future = null;
            }
            _call = null;
            onCompute(null, e, s);
          },
        );

        if (!throwError) {
          return future.catchError(onError ?? (_) => onErrorValue);
        }
        return future;
      } else {
        _result = (value: call, error: null, stackTrace: null);
        _call = null;
        onCompute(value, null, null);
        return call;
      }
    } catch (e, s) {
      _result = (value: null, error: e, stackTrace: s);
      _call = null;
      onCompute(null, e, s);

      if (!throwError) {
        if (onError != null) {
          return onError(e, s);
        } else {
          return onErrorValue as V;
        }
      } else {
        rethrow;
      }
    }
  }

  /// Resolves the computation asynchronously.
  ///
  /// Always returns a [Future<V>] that completes with the resolved value
  /// or completes with an error.
  ///
  /// - If a resolution is in progress, returns the same in-flight [Future].
  /// - If already resolved, returns an already completed [Future].
  /// - When the computation completes (success or failure), [onCompute]
  ///   is invoked with the resulting value or error.
  ///
  /// Parameters:
  /// - [throwError]:
  ///   When `true` (default), the returned [Future] completes with the
  ///   original error and [StackTrace]. When `false`, errors are handled
  ///   by [onError] or [onErrorValue].
  ///
  /// - [onError]:
  ///   Optional asynchronous error handler used only when [throwError]
  ///   is `false`. Receives the error object and its [StackTrace] and must
  ///   return a [Future<V>] whose value becomes the resolution result.
  ///
  /// - [onErrorValue]:
  ///   Fallback value (default null) used to complete the returned [Future]
  ///   when an error occurs, [throwError] is `false`, and [onError] is not
  ///   provided.
  Future<V> resolveAsync({
    bool throwError = true,
    Future<V> Function(Object error, StackTrace stackTrace)? onError,
    V? onErrorValue,
  }) {
    var result = _result;
    if (result != null) {
      var error = result.error;
      if (error != null) {
        var stackTrace = result.stackTrace!;
        if (throwError) {
          return Future.error(error, stackTrace);
        } else if (onError != null) {
          return onError(error, stackTrace);
        } else {
          return Future.value(onErrorValue ?? (null as V));
        }
      }
      return Future.value(result.value as V);
    }

    var future = _future;
    if (future != null) {
      if (!throwError) {
        return future.catchError(onError ?? (_) => onErrorValue);
      }
      return future;
    }

    var computer = _call ?? (throw StateError("Null `_call`"));
    future = _future = Future(computer);

    future.then(
      (value) {
        _result = (value: value, error: null, stackTrace: null);
        if (identical(future, _future)) {
          _future = null;
        }
        _call = null;
        onCompute(value, null, null);
      },
      onError: (e, s) {
        _result = (value: null, error: e, stackTrace: s);
        if (identical(future, _future)) {
          _future = null;
        }
        _call = null;
        onCompute(null, e, s);
      },
    );

    if (!throwError) {
      return future.catchError(onError ?? (_) => onErrorValue);
    }
    return future;
  }

  /// Callback invoked when the computation completes.
  ///
  /// Exactly one of [value] or [error] will be non-null.
  /// If [error] is non-null, [stackTrace] contains the associated stack trace.
  void onCompute(V? value, Object? error, StackTrace? stackTrace) {}

  /// Chains a callback to the resolved value.
  ///
  /// Equivalent to calling [resolveAsync] and then "[then]" on the resulting [Future].
  Future<R> then<R>(FutureOr<R> Function(V value) onValue,
          {Function? onError}) =>
      resolveAsync().then(onValue, onError: onError);

  /// Registers a callback to be executed when resolution completes,
  /// regardless of success or failure.
  ///
  /// Equivalent to calling [resolveAsync] and then invoking
  /// [Future.whenComplete] on the resulting [Future].
  Future<V> whenComplete(FutureOr<void> Function() action) =>
      resolveAsync().whenComplete(action);

  /// Invokes a callback when this value resolves, either successfully
  /// or with an error, and maps the outcome to a new result.
  ///
  /// The [onResolve] callback is always executed:
  /// - On success, it receives the resolved value and `null` error/stackTrace
  /// - On failure, it receives `null` value along with the error and stackTrace
  ///
  /// Errors are not automatically rethrown. The [onResolve] callback
  /// determines how failures are handled by choosing to return a value,
  /// throw a new error, or rethrow the received [error].
  ///
  /// This method delegates to [resolveAsync] and then applies
  /// [Future.whenResolved] on the resulting [Future].
  Future<R> whenResolved<R>(
          FutureOr<R> Function(V? value, Object? error, StackTrace? stackTrace)
              onResolve) =>
      resolveAsync().whenResolved(onResolve);

  /// The class name of this compute implementation.
  ///
  /// Intended to be overridden by subclasses to return their own class name.
  String get className => 'ComputeOnce';

  @override
  String toString() {
    if (isResolved) {
      if (hasError) {
        return '$className<$V>[error: ${_result?.error}]\n'
            '${_result?.stackTrace}';
      } else {
        return '$className<$V><${_result?.value}>';
      }
    } else if (isResolving) {
      return '$className<$V>[resolving...]';
    } else {
      return '$className<$V>@$_call';
    }
  }
}

/// A [ComputeOnce] that records when the computation is resolved.
///
/// The [resolvedAt] timestamp is set when the computation completes,
/// regardless of success or failure.
class TimedComputeOnce<V> extends ComputeOnce<V> {
  TimedComputeOnce(super.call, {super.resolve});

  DateTime? _resolvedAt;

  /// The moment the computation was resolved, or `null` if not yet resolved.
  DateTime? get resolvedAt => _resolvedAt;

  /// Returns the time elapsed since the computation was resolved.
  ///
  /// If the computation has not yet been resolved, returns [Duration.zero].
  /// The optional [now] parameter allows using a custom reference time.
  Duration elapsedTime([DateTime? now]) {
    var resolvedAt = this.resolvedAt;
    if (resolvedAt == null) return Duration.zero;
    now ??= DateTime.now();
    return now.difference(resolvedAt);
  }

  @override
  String get className => 'TimedComputeOnce';

  @override
  void onCompute(V? value, Object? error, StackTrace? stackTrace) {
    _resolvedAt = DateTime.now();
  }
}

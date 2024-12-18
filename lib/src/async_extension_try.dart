import 'dart:async';

FutureOr<R?> _complete<R>(FutureOr<R?> result, _ErrorFunction<R>? errorFunction,
    _FinallyFunction<R>? finallyFunction) {
  if (result is Future<R?>) {
    return result.then((r) {
      return _finally(r, finallyFunction);
    }, onError: (e, s) {
      return _completeError(e, s, errorFunction, finallyFunction);
    });
  } else {
    return _finally(result, finallyFunction);
  }
}

FutureOr<R?> _completeError<R>(Object error, StackTrace stackTrace,
    _ErrorFunction<R>? errorFunction, _FinallyFunction<R>? finallyFunction) {
  if (errorFunction != null) {
    return errorFunction.call(error, stackTrace, finallyFunction);
  } else if (finallyFunction != null) {
    var ret = finallyFunction.call();
    if (ret is Future<R?>) {
      return ret.then((_) {
        throw error;
      }, onError: (e) {
        throw e;
      });
    } else {
      throw error;
    }
  } else {
    throw error;
  }
}

FutureOr<R?> _finally<R>(R? result, _FinallyFunction<R>? finallyFunction,
    [Object? thrownError]) {
  if (finallyFunction != null) {
    return finallyFunction.call(result, thrownError);
  } else {
    if (thrownError != null) {
      throw thrownError;
    }
    return result;
  }
}

class _ThenFunction<R> {
  FutureOr<R?> Function(R?) function;

  _ThenFunction(this.function);

  FutureOr<R?> result;

  bool _called = false;

  FutureOr<R?> call(R? r, _ErrorFunction<R>? errorFunction,
      _FinallyFunction<R>? finallyFunction) {
    if (_called) {
      return result;
    } else {
      _called = true;

      try {
        var ret = function(r);
        result = ret;
        var ret2 = _complete(ret, errorFunction, finallyFunction);
        result = ret2;
        return ret2;
      } catch (e, s) {
        return _completeError(e, s, errorFunction, finallyFunction);
      }
    }
  }
}

class _ErrorFunction<R> {
  Function function;

  _ErrorFunction(this.function);

  R? result;

  bool _called = false;

  FutureOr<R?> call(Object error, StackTrace stackTrace,
      _FinallyFunction<R>? finallyFunction) {
    if (_called) {
      return result;
    }
    _called = true;

    try {
      Object? ret = _callFunction(error, stackTrace);

      if (ret is Future) {
        return ret.then((o) {
          return _callFinally(o, finallyFunction);
        }, onError: (e) {
          return _callFinally(null, finallyFunction, e);
        });
      } else {
        return _callFinally(ret, finallyFunction);
      }
    } catch (e) {
      return _callFinally(null, finallyFunction, e);
    }
  }

  Object? _callFunction(Object error, StackTrace stackTrace) {
    if (function is Function(Object?, StackTrace)) {
      return function(error, stackTrace);
    } else {
      return function(error);
    }
  }

  FutureOr<R?> _callFinally(Object? o, _FinallyFunction<R>? finallyFunction,
      [Object? thrownError]) {
    var r = o is R ? o : null;
    result = r;
    return _finally(r, finallyFunction, thrownError);
  }
}

class _FinallyFunction<R> {
  FutureOr<void> Function() function;

  _FinallyFunction(this.function);

  R? result;

  bool _called = false;

  Future<R?>? _callFuture;

  FutureOr<R?> call([R? r, Object? thrownError]) {
    if (_called) {
      if (_callFuture != null) {
        return _callFuture!;
      } else {
        return result;
      }
    } else {
      _called = true;
      result = r;

      var ret = function();
      if (ret is Future<void>) {
        var future = ret.then((_) {
          if (thrownError != null) {
            throw thrownError;
          }
          return result;
        }, onError: (e) {
          throw e;
        });
        _callFuture = future;
        return future;
      } else {
        if (thrownError != null) {
          throw thrownError;
        }
        return result;
      }
    }
  }
}

/// Executes a [tryBlock] with a `try`, `then`, `catch`, and `finally` flow.
///
/// - [tryBlock]: The operation to execute. If successful, [then] is called.
/// - [then]: A function called after [tryBlock] completes successfully, receiving its result.
/// - [onError]: A callback invoked if [tryBlock] or [then] throws an error, similar to [Future.then]'s `onError` parameter.
/// - [onFinally]: Always called after [tryBlock], [then], and [onError], regardless of success or failure.
///
/// ### Returns:
/// - Result of [tryBlock] passed to [then], or an error handled by [onError]. [onFinally] is always executed.
///
/// ### Example:
/// ```dart
/// final result = await asyncTry<String>(
///   () => fetchData(),
///   then: (r) => processData(r),
///   onError: (error) => handleError(error),
///   onFinally: () => cleanUp(),
/// );
/// ```
FutureOr<R?> asyncTry<R>(FutureOr<R?> Function() tryBlock,
    {FutureOr<R?> Function(R? r)? then,
    Function? onError,
    FutureOr<void> Function()? onFinally}) {
  var thenFunction = then != null ? _ThenFunction<R>(then) : null;
  var errorFunction = onError != null ? _ErrorFunction<R>(onError) : null;
  var finallyFunction =
      onFinally != null ? _FinallyFunction<R>(onFinally) : null;

  try {
    var ret = tryBlock();

    if (ret is Future<R?>) {
      return _returnFuture<R>(
          ret, thenFunction, errorFunction, finallyFunction);
    } else {
      return _returnValue<R>(ret, thenFunction, errorFunction, finallyFunction);
    }
  } catch (e, s) {
    return _completeError(e, s, errorFunction, finallyFunction);
  }
}

Future<R?> _returnFuture<R>(
  Future<R?> ret,
  _ThenFunction<R>? thenFunction,
  _ErrorFunction<R>? errorFunction,
  _FinallyFunction<R>? finallyFunction,
) {
  if (thenFunction != null) {
    return ret.then(
      (r) {
        return thenFunction.call(r, errorFunction, finallyFunction);
      },
      onError: (e, s) {
        return _completeError(e, s, errorFunction, finallyFunction);
      },
    );
  } else if (errorFunction != null || finallyFunction != null) {
    return ret.then(
      (r) {
        return _complete(r, errorFunction, finallyFunction);
      },
      onError: (e, s) {
        return _completeError(e, s, errorFunction, finallyFunction);
      },
    );
  } else {
    return ret;
  }
}

FutureOr<R?> _returnValue<R>(
  R? ret,
  _ThenFunction<R>? thenFunction,
  _ErrorFunction<R>? errorFunction,
  _FinallyFunction<R>? finallyFunction,
) {
  if (thenFunction != null) {
    return thenFunction.call(ret, errorFunction, finallyFunction);
  } else {
    return _finally(ret, finallyFunction);
  }
}

/// Executes an asynchronous operation with retry logic.
///
/// Retries the [tryBlock] function up to [maxRetries] times if it throws an error,
/// with customizable delay and error handling.
///
/// ### Parameters:
/// - [tryBlock]: The operation to execute. Retries if it throws an error.
/// - [defaultValue]: Value to return if retries are exhausted and [throwOnRetryExhaustion] is `false`. Defaults to `null`.
/// - [throwOnRetryExhaustion]: If `true`, rethrows the last error when retries are exhausted.
///   Defaults to `false`, which returns [defaultValue] instead.
/// - [maxRetries]: Maximum number of retry attempts. Defaults to `3`.
/// - [retryDelay]: Fixed delay between retries. Defaults to 1ms. Overridden by [computeDelay] if provided.
/// - [computeDelay]: Computes a custom delay for each retry based on the retry count.
/// - [onError]: Callback to handle errors during retries. Receives:
///   - `error`: The exception thrown by [tryBlock].
///   - `stackTrace`: The stack trace associated with the error.
///   - `retries`: The number of retry attempts already made (starting at 0).
///     If [onError] returns `false`, stops retrying immediately.
///
/// ### Returns:
/// A `FutureOr<R?>` with the result of [tryBlock] if successful.
/// If retries are exhausted:
/// - Returns [defaultValue] if [throwOnRetryExhaustion] is `false`.
/// - Rethrows the last error if [throwOnRetryExhaustion] is `true`.
///
/// ### Example:
/// ```dart
/// // Some network request:
/// Future<String?> fetchData() async {
///   throw Exception('Network error');
/// }
///
/// Future<void> main() async {
///   var result = await asyncRetry<String?>(
///     () => fetchData(),
///     defaultValue: 'Fallback value',  // Return this if retries are exhausted and throwOnRetryExhaustion is false.
///     maxRetries: 5,                   // Retry up to 5 times before giving up.
///     retryDelay: Duration(seconds: 2), // 2 seconds delay between retries.
///     throwOnRetryExhaustion: true,     // Rethrow the last error if all retries fail.
///     onError: (error, stackTrace, retries) {
///       print('Attempt failed (retries: $retries): $error');
///       return null; // Continue retrying based on maxRetries without modifying retry behavior.
///       // If returns `false`, retries stop early.
///       // If returns `true`, retries continue even if maxRetries is exceeded.
///     },
///   );
///
///   print('Result: $result');
/// }
/// ```
///
/// ### Notes:
/// - If [throwOnRetryExhaustion] is `true` and retries fail, the last error will be rethrown.
/// - If [computeDelay] is provided, it overrides [retryDelay].
/// - The [onError] callback can stop retries early by returning `false`.
///
/// ### Throws:
/// - The last error from [tryBlock] if retries are exhausted and [throwOnRetryExhaustion] is `true`.
FutureOr<R?> asyncRetry<R>(FutureOr<R?> Function() tryBlock,
    {R? defaultValue,
    bool throwOnRetryExhaustion = false,
    int maxRetries = 3,
    Duration? retryDelay,
    Duration? Function(int retry)? computeDelay,
    bool? Function(Object error, StackTrace stackTrace, int retries)?
        onError}) {
  if (maxRetries < 0) {
    maxRetries = 0;
  }

  retryDelay ??= Duration(milliseconds: 1);

  return _asyncRetryImpl(tryBlock, 0, maxRetries, defaultValue,
      throwOnRetryExhaustion, retryDelay, computeDelay, onError);
}

FutureOr<R?> _asyncRetryImpl<R>(
  FutureOr<R?> Function() tryBlock,
  int retries,
  int maxRetries,
  R? defaultValue,
  bool throwOnRetryExhaustion,
  Duration retryDelay,
  Duration? Function(int retries)? computeDelay,
  bool? Function(Object error, StackTrace stackTrace, int retries)? onError,
) {
  try {
    var ret = tryBlock();

    if (ret is Future<R?>) {
      return ret.then((r) => r,
          onError: (e, s) => _asyncRetryOnError<R>(
              tryBlock,
              retries,
              maxRetries,
              defaultValue,
              throwOnRetryExhaustion,
              retryDelay,
              computeDelay,
              onError,
              e,
              s));
    } else {
      return ret;
    }
  } catch (e, s) {
    return _asyncRetryOnError<R>(tryBlock, retries, maxRetries, defaultValue,
        throwOnRetryExhaustion, retryDelay, computeDelay, onError, e, s);
  }
}

FutureOr<R?>? _asyncRetryOnError<R>(
  FutureOr<R?> Function() tryBlock,
  int retries,
  int maxRetries,
  R? defaultValue,
  bool throwOnRetryExhaustion,
  Duration retryDelay,
  Duration? Function(int retries)? computeDelay,
  bool? Function(Object error, StackTrace stackTrace, int retries)? onError,
  Object error,
  StackTrace stackTrace,
) {
  var canRetry = retries < maxRetries;
  if (onError != null) {
    canRetry = onError(error, stackTrace, retries) ?? canRetry;
  }

  if (!canRetry) {
    if (throwOnRetryExhaustion) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    return defaultValue;
  }

  if (computeDelay != null) {
    retryDelay = computeDelay(retries) ?? retryDelay;
  }

  return Future.delayed(
    retryDelay,
    () => _asyncRetryImpl<R>(tryBlock, retries + 1, maxRetries, defaultValue,
        throwOnRetryExhaustion, retryDelay, computeDelay, onError),
  );
}

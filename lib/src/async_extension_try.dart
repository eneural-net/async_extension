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

/// Executes a [tryBlock] in a `try`, `then`, `catch` and `finally` execution chain.
/// - [then] is called after execution of [tryBlock].
/// - [onError] is called if [tryBlock] or [then] throws some error. Similar to [Future.then] `onError` parameter.
/// - [onFinally] is called after execution of [tryBlock], [then] and [onError].
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

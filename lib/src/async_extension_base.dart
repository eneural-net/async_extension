import 'dart:async';

/// Extension for [FutureOr].
extension FutureOrExtension<T> on FutureOr<T> {
  /// Returns the type of [T].
  Type get type => T;

  /// Returns a [Future] of this instance.
  Future<T> get asFuture =>
      this is Future ? this as Future<T> : Future<T>.value(this);

  /// Returns `true` if this instance is a [T] value (not a [Future]).
  bool get isResolved => this is! Future;

  /// Resolves this instance.
  ///
  /// - [validate] if returns `false` will resolve to [defaultValue].
  /// - If resolved value is null will return [defaultValue].
  FutureOr<T> resolve(
      {FutureOr<bool> Function(T val)? validate, T? defaultValue}) {
    if (validate == null && defaultValue == null) {
      return this;
    }

    if (this is Future) {
      var future = this as Future<T>;
      return future.then((value) =>
          _validate(value, validate: validate, defaultValue: defaultValue)
              as FutureOr<T>);
    } else {
      return _validate<T>(this as T,
          validate: validate, defaultValue: defaultValue) as FutureOr<T>;
    }
  }

  /// Validate `this` instance with [validate].
  /// Returns [defaultValue] if not valid or value is null.
  FutureOr<T?> validate(FutureOr<bool> Function(T val)? validate,
      {T? defaultValue}) {
    if (validate == null && defaultValue == null) {
      return this;
    }

    if (this is Future<T>) {
      var future = this as Future<T>;
      return future.then((value) =>
          _validate(value, validate: validate, defaultValue: defaultValue)
              as FutureOr<T>);
    } else {
      return _validate(this as T,
          validate: validate, defaultValue: defaultValue);
    }
  }

  static FutureOr<T?> _validate<T>(T value,
      {FutureOr<bool> Function(T val)? validate, T? defaultValue}) {
    if (validate != null) {
      var valid = validate(value);
      return valid.resolveMapped((ok) => ok ? value : defaultValue);
    } else {
      return value ?? defaultValue;
    }
  }

  /// Resolves this instance mapping to [mapper] and return its result.
  ///
  /// - [validate] will validate the result of [mapper].
  FutureOr<R> resolveMapped<R>(FutureOr<R> Function(T val) mapper,
      {FutureOr<bool> Function(R? val)? validate, R? defaultValue}) {
    if (validate == null && defaultValue == null) {
      if (this is Future) {
        var future = this as Future<T>;
        return future.then((r) => mapper(r));
      } else {
        return mapper(this as T);
      }
    }

    if (this is Future) {
      var future = this as Future<T>;
      return future.then((r) {
        var val = mapper(r);
        return val.resolve(validate: validate, defaultValue: defaultValue);
      });
    } else {
      var val = mapper(this as T);
      return val.resolve(validate: validate, defaultValue: defaultValue);
    }
  }

  /// Resolves this instance with [resolver] result.
  ///
  /// - [validate] will validate the result of [resolver].
  FutureOr<R> resolveWith<R>(FutureOr<R> Function() resolver,
      {FutureOr<bool> Function(R? val)? validate, R? defaultValue}) {
    if (validate == null && defaultValue == null) {
      if (this is Future) {
        var future = this as Future<T>;
        return future.then((r) => resolver());
      } else {
        return resolver();
      }
    }

    if (this is Future) {
      var future = this as Future<T>;
      return future.then((r) {
        var val = resolver();
        return val.resolve(validate: validate, defaultValue: defaultValue);
      });
    } else {
      var val = resolver();
      return val.resolve(validate: validate, defaultValue: defaultValue);
    }
  }

  /// Resolves this instance and calls [callback]. Returns `void`.
  FutureOr<void> onResolve<R>(void Function(T r) callback) {
    if (this is Future) {
      var future = this as Future<T>;
      return future.then((r) => callback(r));
    } else {
      callback(this as T);
    }
  }
}

/// Extension for `Iterable<FutureOr<T>>`.
extension IterableFutureOrExtension<T> on Iterable<FutureOr<T>> {
  /// Returns `true` if all elements are a [Future].
  bool get isAllFuture {
    if (this is Iterable<Future<T>>) return true;
    if (this is Iterable<T>) return false;

    for (var e in this) {
      if (e is! Future) return false;
    }
    return true;
  }

  /// Returns `true` if all elements are resolved, NOT a [Future].
  bool get isAllResolved {
    if (this is Iterable<T>) return true;
    if (this is Iterable<Future<T>>) return false;

    for (var e in this) {
      if (e is Future) return false;
    }
    return true;
  }

  /// Returns all [FutureOr] elements as [Future].
  List<Future<T>> get asFutures {
    if (this is List<Future<T>>) return this as List<Future<T>>;
    if (this is Iterable<Future<T>>) return cast<Future<T>>().toList();
    return map((e) => e is Future ? e as Future<T> : Future<T>.value(e))
        .toList();
  }

  /// Filters to [Future] elements.
  Iterable<Future<T>> whereFuture() => whereType<Future<T>>();

  /// Filters to resolved elements (of type [T]).
  Iterable<T> whereResolved() => whereType<T>();

  /// Selects all elements that are a [Future] and returns a [List] of them.
  List<Future<T>> selectFutures() => whereFuture().toList();

  /// Selects all elements that are resolved (of type [T])
  List<T> selectResolved() => whereResolved().toList();

  /// Resolve all elements.
  FutureOr<List<T>> resolveAll() {
    if (isEmpty) return <T>[];

    if (isAllResolved) {
      return cast<T>().toList();
    } else {
      return Future.wait(asFutures);
    }
  }

  /// Resolves all elements and map them with [mapper].
  FutureOr<List<R>> resolveAllMapped<R>(R Function(T e) mapper) {
    if (isEmpty) return <R>[];

    if (isAllResolved) {
      return cast<T>().map(mapper).toList();
    } else {
      return Future.wait(asFutures).then((l) {
        return l.map(mapper).toList();
      });
    }
  }

  /// Resolves all elements and [validate] them.
  /// If an element is not valid will use [defaultValue].
  FutureOr<List<T>> resolveAllValidated(bool Function(T e) validate,
      {T? defaultValue}) {
    if (isEmpty) return <T>[];

    if (isAllResolved) {
      return cast<T>().map((v) => validate(v) ? v : defaultValue as T).toList();
    } else {
      return Future.wait(asFutures).then((l) {
        return l.map((v) => validate(v) ? v : defaultValue as T).toList();
      });
    }
  }

  /// Resolves all elements and join them with [joiner].
  FutureOr<R> resolveAllJoined<R>(FutureOr<R> Function(List<T> r) joiner) {
    if (isEmpty) return joiner(<T>[]);

    if (isAllResolved) {
      var l = cast<T>().toList();
      return joiner(l);
    } else {
      return Future.wait(asFutures).resolveMapped(joiner);
    }
  }

  /// Resolves all elements and reduce them with [reducer].
  FutureOr<T> resolveAllReduced<R>(T Function(T value, T element) reducer) {
    if (isEmpty) return <T>[].reduce(reducer);

    if (isAllResolved) {
      var l = cast<T>().toList();
      return l.reduce(reducer);
    } else {
      return Future.wait(asFutures).resolveMapped((l) {
        return l.reduce(reducer);
      });
    }
  }

  /// Wait all elements that are [Future].
  FutureOr<List<T>> waitFutures() {
    var futures = selectFutures();
    if (futures.isEmpty) {
      return <T>[];
    } else {
      return Future.wait(futures);
    }
  }

  FutureOr<V> waitFuturesAndReturnValue<V>(V value) {
    var futures = selectFutures();
    if (futures.isEmpty) {
      return value;
    } else {
      return Future.wait(futures).then((_) => value);
    }
  }
}

/// Extension for `List<Future<T>>`.
extension ListFutureExtension<T> on List<Future<T>> {
  Future<List<T>> resolveAll() {
    if (isEmpty) {
      return Future.value(<T>[]);
    }
    return Future.wait(this);
  }

  Future<List<R>> resolveAllMapped<R>(R Function(T e) mapper) {
    if (isEmpty) {
      return Future.value(<R>[]);
    }

    return Future.wait(this).then((l) {
      return l.map(mapper).toList();
    });
  }

  Future<List<T>> resolveAllValidated(bool Function(T e) validate,
      {T? defaultValue}) {
    if (isEmpty) {
      return Future.value(<T>[]);
    }

    return Future.wait(this).then((l) {
      return l.map((v) => validate(v) ? v : defaultValue as T).toList();
    });
  }

  Future<R> resolveAllJoined<R>(FutureOr<R> Function(List<T> l) joiner) {
    if (isEmpty) {
      return Future.value(joiner(<T>[]));
    }

    return Future.wait(this).then(joiner);
  }

  Future<T> resolveAllReduced<R>(T Function(T value, T element) reducer) {
    if (isEmpty) {
      return Future.value(<T>[].reduce(reducer));
    }

    return Future.wait(this).then((l) {
      return l.reduce(reducer);
    });
  }

  Future<List<T>> waitFutures() {
    if (isEmpty) {
      return Future.value(<T>[]);
    } else {
      return Future.wait(this);
    }
  }

  Future<V> waitFuturesAndReturnValue<V>(V value) {
    if (isEmpty) {
      return Future.value(value);
    } else {
      return Future.wait(this).then((_) => value);
    }
  }
}

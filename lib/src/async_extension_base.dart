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

    var self = this;

    if (self is Future<T>) {
      return self.then((value) =>
          _validate(value, validate: validate, defaultValue: defaultValue)
              as FutureOr<T>);
    } else {
      return _validate<T>(this as T,
          validate: validate, defaultValue: defaultValue) as FutureOr<T>;
    }
  }

  /// Resolves `this` and [other] with [resolver].
  FutureOr<R> resolveBoth<R>(
      FutureOr<T> other, FutureOr<R> Function(T val1, T val2) resolver) {
    var self = this;

    if (self is Future<T>) {
      if (other is Future<T>) {
        return self.then((v1) {
          return other.then((v2) => resolver(v1, v2));
        });
      } else {
        return self.then((v1) {
          return resolver(v1, other);
        });
      }
    } else {
      if (other is Future<T>) {
        return other.then((v2) => resolver(self, v2));
      } else {
        return resolver(self, other);
      }
    }
  }

  /// Validate `this` instance with [validate].
  /// Returns [defaultValue] if not valid or value is null.
  FutureOr<T?> validate(FutureOr<bool> Function(T val)? validate,
      {T? defaultValue}) {
    if (validate == null && defaultValue == null) {
      return this;
    }

    var self = this;

    if (self is Future<T>) {
      return self.then((value) =>
          _validate(value, validate: validate, defaultValue: defaultValue)
              as FutureOr<T>);
    } else {
      return _validate(self, validate: validate, defaultValue: defaultValue);
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
  FutureOr<R> resolveMapped<R>(FutureOr<R> Function(T val) mapper) {
    var self = this;

    if (self is Future<T>) {
      return self.then((r) => mapper(r));
    } else {
      return mapper(self);
    }
  }

  /// Same as [Future.then].
  ///
  /// - Note: it's not possible to implement `onError` and have the same
  ///   behavior at [Future.then], since `onError` will be called
  ///   only if `this` is a [Future], and not when it's a [T].
  FutureOr<R> then<R>(FutureOr<R> Function(T value) onValue) {
    var self = this;

    if (self is Future<T>) {
      return self.then(onValue);
    } else {
      return onValue(self);
    }
  }

  /// Resolves this instance with [resolver] result.
  FutureOr<R> resolveWith<R>(FutureOr<R> Function() resolver) {
    var self = this;

    if (self is Future<T>) {
      return self.then((r) => resolver());
    } else {
      return resolver();
    }
  }

  /// Resolves this instance and calls [callback]. Returns `void`.
  FutureOr<void> onResolve<R>(void Function(T r) callback) {
    var self = this;

    if (self is Future<T>) {
      return self.then((r) => callback(r));
    } else {
      callback(self);
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

  /// Waits futures and returns [value].
  FutureOr<V> waitFuturesAndReturnValue<V>(V value) {
    var futures = selectFutures();
    if (futures.isEmpty) {
      return value;
    } else {
      return Future.wait(futures).then((_) => value);
    }
  }
}

extension FutureExtension<T> on Future<T> {
  /// Returns the type of [T].
  Type get type => T;

  /// Resolves `this` [Future] and [other] with [resolver].
  Future<R> resolveBoth<R>(
      FutureOr<T> other, FutureOr<R> Function(T val1, T val2) resolver) {
    if (other is Future<T>) {
      return then((v1) {
        return other.then((v2) => resolver(v1, v2));
      });
    } else {
      return then((v1) {
        return resolver(v1, other);
      });
    }
  }
}

/// Extension for `Iterable<Future<T>>`.
extension IterableFutureExtension<T> on Iterable<Future<T>> {
  Future<List<T>> resolveAll() {
    if (isEmpty) {
      return Future.value(<T>[]);
    }
    return Future.wait(this);
  }

  /// Resolves this [Future]s and maps with [mapper].
  Future<List<R>> resolveAllMapped<R>(R Function(T e) mapper) {
    if (isEmpty) {
      return Future.value(<R>[]);
    }

    return Future.wait(this).then((l) {
      return l.map(mapper).toList();
    });
  }

  /// Resolves this [Future]s and validates with [validate].
  Future<List<T>> resolveAllValidated(bool Function(T e) validate,
      {T? defaultValue}) {
    if (isEmpty) {
      return Future.value(<T>[]);
    }

    return Future.wait(this).then((l) {
      return l.map((v) => validate(v) ? v : defaultValue as T).toList();
    });
  }

  /// Resolves this [Future]s and join values with [joiner].
  Future<R> resolveAllJoined<R>(FutureOr<R> Function(List<T> l) joiner) {
    if (isEmpty) {
      return Future.value(joiner(<T>[]));
    }

    return Future.wait(this).then(joiner);
  }

  /// Resolves this [Future]s and reduces values with [reducer].
  Future<T> resolveAllReduced<R>(T Function(T value, T element) reducer) {
    if (isEmpty) {
      return Future.value(<T>[].reduce(reducer));
    }

    return Future.wait(this).then((l) {
      return l.reduce(reducer);
    });
  }

  /// Waits this [Future]s
  Future<List<T>> waitFutures() {
    if (isEmpty) {
      return Future.value(<T>[]);
    } else {
      return Future.wait(this);
    }
  }

  /// Waits this [Future]s and return [value].
  Future<V> waitFuturesAndReturnValue<V>(V value) {
    if (isEmpty) {
      return Future.value(value);
    } else {
      return Future.wait(this).then((_) => value);
    }
  }
}

extension FutureOrIntExtension on FutureOr<int> {
  /// Operator to sum `FutureOr<int>`.
  FutureOr<int> operator +(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 + n2);

  /// Operator to subtract `FutureOr<int>`.
  FutureOr<int> operator -(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 - n2);

  /// Operator to multiply `FutureOr<int>`.
  FutureOr<int> operator *(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 * n2);

  /// Operator to divide `FutureOr<int>`.
  FutureOr<double> operator /(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 / n2);

  /// Operator to divide (to int) `FutureOr<int>`.
  FutureOr<int> operator ~/(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 ~/ n2);
}

extension FutureOrDoubleExtension on FutureOr<double> {
  /// Operator to sum `FutureOr<double>`.
  FutureOr<double> operator +(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 + n2);

  /// Operator to subtract `FutureOr<double>`.
  FutureOr<double> operator -(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 - n2);

  /// Operator to multiply `FutureOr<double>`.
  FutureOr<double> operator *(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 * n2);

  /// Operator to divide `FutureOr<double>`.
  FutureOr<double> operator /(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 / n2);

  /// Operator to divide (to int) `FutureOr<int>`.
  FutureOr<int> operator ~/(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 ~/ n2);
}

extension FutureOrNumExtension on FutureOr<num> {
  /// Operator to sum `FutureOr<num>`.
  FutureOr<num> operator +(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 + n2);

  /// Operator to subtract `FutureOr<num>`.
  FutureOr<num> operator -(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 - n2);

  /// Operator to multiply `FutureOr<num>`.
  FutureOr<num> operator *(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 * n2);

  /// Operator to divide `FutureOr<num>`.
  FutureOr<double> operator /(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 / n2);

  /// Operator to divide (to int) `FutureOr<num>`.
  FutureOr<int> operator ~/(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 ~/ n2);
}

extension FutureIntExtension on Future<int> {
  /// Operator to sum `FutureOr<int>`.
  Future<int> operator +(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 + n2);

  /// Operator to subtract `FutureOr<int>`.
  Future<int> operator -(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 - n2);

  /// Operator to multiply `FutureOr<int>`.
  Future<int> operator *(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 * n2);

  /// Operator to divide `FutureOr<int>`.
  Future<double> operator /(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 / n2);

  /// Operator to divide (to int) `FutureOr<int>`.
  Future<int> operator ~/(FutureOr<int> other) =>
      resolveBoth(other, (n1, n2) => n1 ~/ n2);
}

extension FutureDoubleExtension on Future<double> {
  /// Operator to sum `FutureOr<double>`.
  Future<double> operator +(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 + n2);

  /// Operator to subtract `FutureOr<double>`.
  Future<double> operator -(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 - n2);

  /// Operator to multiply `FutureOr<double>`.
  Future<double> operator *(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 * n2);

  /// Operator to divide `FutureOr<double>`.
  Future<double> operator /(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 / n2);

  /// Operator to divide (to int) `FutureOr<int>`.
  Future<int> operator ~/(FutureOr<double> other) =>
      resolveBoth(other, (n1, n2) => n1 ~/ n2);
}

extension FutureNumExtension on Future<num> {
  /// Operator to sum `FutureOr<num>`.
  Future<num> operator +(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 + n2);

  /// Operator to subtract `FutureOr<num>`.
  Future<num> operator -(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 - n2);

  /// Operator to multiply `FutureOr<num>`.
  Future<num> operator *(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 * n2);

  /// Operator to divide `FutureOr<num>`.
  Future<double> operator /(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 / n2);

  /// Operator to divide (to int) `FutureOr<num>`.
  Future<int> operator ~/(FutureOr<num> other) =>
      resolveBoth(other, (n1, n2) => n1 ~/ n2);
}

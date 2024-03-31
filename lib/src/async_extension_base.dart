import 'dart:async';

import 'async_extension_try.dart';

var _tObjectNull = _typeGetter<Object?>();
var _tFutureNull = _typeGetter<Future?>();

bool _isNotFuture(Type type) {
  return type != Future &&
      type != dynamic &&
      type != Object &&
      type != _tFutureNull &&
      type != _tObjectNull;
}

Type _typeGetter<T>() => T;

/// Extension for [FutureOr].
extension FutureOrExtension<T> on FutureOr<T> {
  /// Returns the type of [T].
  Type get genericType => T;

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
  ///
  /// Note that the parameter [other] should be of the same [Type] of `this` instance.
  ///
  /// See also [resolveOther].
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

  /// Resolves `this` and [other] with [resolver].
  ///
  /// This method is similar to [resolveBoth], but accepts an [other] parameter
  /// with a different [Type] of `this` instance.
  FutureOr<R> resolveOther<R, E>(
      FutureOr<E> other, FutureOr<R> Function(T val1, E val2) resolver) {
    var self = this;

    if (self is Future<T>) {
      if (other is Future<E>) {
        return self.then((v1) {
          return other.then((v2) => resolver(v1, v2));
        });
      } else {
        return self.then((v1) {
          return resolver(v1, other);
        });
      }
    } else {
      if (other is Future<E>) {
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
      return self.then(mapper);
    } else {
      return mapper(self);
    }
  }

  /// Same as [Future.then].
  ///
  /// - Note: it's not possible to implement `onError` with the same
  ///   behavior at [Future.then], since `onError` will be called
  ///   only if `this` is a [Future], and not when it's a [T].
  /// - See [asyncTry].
  FutureOr<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    var self = this;

    if (self is Future<T>) {
      return self.then(onValue, onError: onError);
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

  /// Resolves this instance with [value].
  FutureOr<V> resolveWithValue<V>(V value) {
    var self = this;

    if (self is Future<T>) {
      return self.then((r) => value);
    } else {
      return value;
    }
  }

  /// Resolves this instance and calls [callback]. Returns `void`.
  FutureOr<void> onResolve<R>(void Function(T r) callback) {
    var self = this;

    if (self is Future<T>) {
      return self.then(callback);
    } else {
      callback(self);
    }
  }
}

/// Extensions that apply to iterables with a nullable element type.
extension IterableFutureOrExtensionNullable<T> on Iterable<FutureOr<T?>> {
  /// Selects the non-null elements [T] of this iterable.
  ///
  /// Note that [Future] with null values won't be identified as null elements,
  /// since they are not resolved yet.
  Iterable<FutureOr<T?>> whereNotNullSync() sync* {
    for (var element in this) {
      if (element != null) {
        yield element;
      }
    }
  }

  /// Selects the non-null resolved elements [T] of this iterable.
  Iterable<T> whereNotNullResolved() sync* {
    for (var element in this) {
      if (element != null && element is! Future) {
        yield element!;
      }
    }
  }

  /// Resolve all elements and select all non-null elements.
  FutureOr<List<T>> resolveAllNotNull() {
    var self = this;

    if (_isNotFuture(T)) {
      if (self is List<T>) {
        return self;
      } else if (self is List<T?>) {
        return self.whereNotNullResolved().toList();
      } else if (self is Iterable<T>) {
        return self.toList();
      } else if (self is Iterable<T?>) {
        return self.whereNotNullResolved().toList();
      }
    }

    var all = allAsList;
    if (all.isEmpty) return <T>[];

    if (all.isAllResolved) {
      return all.whereNotNullResolved().toList();
    } else {
      return Future.wait<T?>(all.asFutures).then((values) {
        return values.whereNotNullResolved().toList();
      });
    }
  }

  /// Resolve all elements.
  FutureOr<List<T?>> resolveAllNullable() {
    var self = this;

    if (_isNotFuture(T)) {
      if (self is List<T>) {
        return self;
      } else if (self is List<T?>) {
        return self.toList();
      } else if (self is Iterable<T>) {
        return self.toList();
      } else if (self is Iterable<T?>) {
        return self.toList();
      }
    }

    var all = allAsList;
    if (all.isEmpty) return <T>[];

    if (all.isAllResolved) {
      return all.cast<T?>().toList();
    } else {
      return Future.wait<T?>(all.asFutures).then((values) {
        return values.toList();
      });
    }
  }
}

extension IterableFutureOrNullableExtension<T> on Iterable<FutureOr<T>?> {
  /// Filters to [Future] elements.
  Iterable<Future<T?>> whereFutureNullable() => whereType<Future<T?>>();

  /// Selects all elements that are a [Future] and returns a [List] of them.
  List<Future<T?>> selectFuturesNullable() => whereFutureNullable().toList();

  /// Wait all elements that are [Future].
  FutureOr<List<T?>> waitFuturesNullable() {
    var futures = selectFuturesNullable();
    if (futures.isEmpty) {
      return <T?>[];
    } else {
      return Future.wait(futures);
    }
  }

  /// Returns all [FutureOr] elements as [Future].
  List<Future<T?>> get asFuturesNullable {
    if (this is List<Future<T>>) return this as List<Future<T>>;
    if (this is Iterable<Future<T>>) return cast<Future<T>>().toList();
    if (this is Iterable<Future<T>?>) {
      return whereType<Future<T>>().toList();
    }

    return map((e) => e is Future ? e as Future<T?> : Future<T?>.value(e))
        .toList();
  }
}

/// Extension for `Iterable<FutureOr<T>>`.
extension IterableFutureOrExtension<T> on Iterable<FutureOr<T>> {
  /// Returns `true` if all elements are a [Future].
  bool get isAllFuture {
    if (this is Iterable<Future<T>>) return true;
    if (this is Iterable<T> && _isNotFuture(T)) return false;

    for (var e in this) {
      if (e is! Future) return false;
    }
    return true;
  }

  /// Returns `true` if all elements are resolved, NOT a [Future].
  bool get isAllResolved {
    if (this is Iterable<T> && _isNotFuture(T)) return true;
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

  /// Returns all elements in a List.
  /// Ensures that an [Iterable] is fully constructed.
  List<FutureOr<T>> get allAsList {
    var self = this;

    if (self is List<FutureOr<T>>) {
      return self;
    } else {
      return self.toList();
    }
  }

  /// Resolve all elements.
  FutureOr<List<T>> resolveAll() {
    var self = this;

    if (_isNotFuture(T)) {
      if (self is List<T>) {
        return self;
      } else if (self is Iterable<T>) {
        return self.toList();
      }
    }

    var all = allAsList;
    if (all.isEmpty) return <T>[];

    if (all.isAllResolved) {
      return all.cast<T>();
    } else {
      return Future.wait(all.asFutures);
    }
  }

  /// Resolves all elements then resolves with [resolver] result.
  FutureOr<R> resolveAllWith<R>(FutureOr<R> Function() resolver) {
    var self = this;

    if (_isNotFuture(T) && (self is List<T> || self is Set<T>)) {
      return resolver();
    }

    var all = allAsList;

    if (all.isAllResolved) {
      return resolver();
    } else {
      return Future.wait(all.asFutures).then((r) => resolver());
    }
  }

  /// Same as `Future.wait(this).then`.
  ///
  /// - Note: it's not possible to implement `onError` and have the same
  ///   behavior at [Future.then], since `onError` will be called
  ///   only if `this` is a [Future], and not when it's a [T].
  FutureOr<R> resolveAllThen<R>(FutureOr<R> Function(List<T> values) onValues) {
    var all = resolveAll();

    if (all is List<T>) {
      return onValues(all);
    } else {
      return all.then(onValues);
    }
  }

  /// Resolves all elements then resolves with [value].
  FutureOr<V> resolveAllWithValue<V>(V value) {
    var self = this;

    if (_isNotFuture(T) && (self is List<T> || self is Set<T>)) {
      return value;
    }

    var all = allAsList;

    if (all.isAllResolved) {
      return value;
    } else {
      return Future.wait(all.asFutures).then((r) => value);
    }
  }

  /// Resolves all elements and map them with [mapper].
  FutureOr<List<R>> resolveAllMapped<R>(R Function(T e) mapper) {
    var self = this;

    if (_isNotFuture(T) && self is Iterable<T>) {
      return self.map(mapper).toList();
    }

    var all = allAsList;
    if (all.isEmpty) return <R>[];

    if (all.isAllResolved) {
      return all.cast<T>().map(mapper).toList();
    } else {
      return Future.wait(all.asFutures).then((l) {
        return l.map(mapper).toList();
      });
    }
  }

  /// Resolves all elements and [validate] them.
  /// If an element is not valid will use [defaultValue].
  FutureOr<List<T>> resolveAllValidated(bool Function(T e) validate,
      {T? defaultValue}) {
    var self = this;

    if (_isNotFuture(T) && self is Iterable<T>) {
      return self.map((v) => validate(v) ? v : defaultValue as T).toList();
    }

    var all = allAsList;
    if (all.isEmpty) return <T>[];

    if (all.isAllResolved) {
      return all
          .cast<T>()
          .map((v) => validate(v) ? v : defaultValue as T)
          .toList();
    } else {
      return Future.wait(all.asFutures).then((l) {
        return l.map((v) => validate(v) ? v : defaultValue as T).toList();
      });
    }
  }

  /// Resolves all elements and join them with [joiner].
  FutureOr<R> resolveAllJoined<R>(FutureOr<R> Function(List<T> r) joiner) {
    var self = this;

    if (_isNotFuture(T) && self is Iterable<T>) {
      var l = self.toList();
      return joiner(l);
    }

    var all = allAsList;
    if (all.isEmpty) return joiner(<T>[]);

    if (all.isAllResolved) {
      var l = all.cast<T>();
      return joiner(l);
    } else {
      return Future.wait(all.asFutures).resolveMapped(joiner);
    }
  }

  /// Resolves all elements and reduce them with [reducer].
  FutureOr<T> resolveAllReduced<R>(T Function(T value, T element) reducer) {
    var self = this;

    if (_isNotFuture(T) && self is Iterable<T>) {
      return self.reduce(reducer);
    }

    var all = allAsList;
    if (all.isEmpty) return <T>[].reduce(reducer);

    if (all.isAllResolved) {
      var l = all.cast<T>();
      return l.reduce(reducer);
    } else {
      return Future.wait(all.asFutures).resolveMapped((l) {
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
  Type get genericType => T;

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

typedef AsyncExtensionErrorLogger = void Function(Object? e, StackTrace? s)?;

/// The default [AsyncExtensionErrorLogger].
AsyncExtensionErrorLogger? defaultAsyncExtensionErrorLogger;

extension AsyncExtensionErrorLoggerExtension<T> on AsyncExtensionErrorLogger? {
  void logError(Object? e, StackTrace? s) {
    var logger = this;
    logger ??= defaultAsyncExtensionErrorLogger;
    if (logger != null) {
      logger(e, s);
    }
  }
}

extension FutureOnErrorExtension<T> on Future<T> {
  /// Logs a [Future] error using [errorLogger] or [defaultAsyncExtensionErrorLogger]
  /// if parameter [logError] is `true`.
  Future<T> logError(
      {AsyncExtensionErrorLogger? errorLogger, bool logError = true}) async {
    try {
      return await this;
    } catch (e, s) {
      if (logError) errorLogger.logError(e, s);
      rethrow;
    }
  }

  /// Returns this [Future] value or [onErrorValue] if it throws an error.
  ///
  /// Logs the error using [errorLogger] or [defaultAsyncExtensionErrorLogger]
  /// if parameter [logError] is `true`.
  Future<T> onErrorReturn(T onErrorValue,
      {FutureOr<void> Function(Object e, StackTrace s)? onError,
      AsyncExtensionErrorLogger? errorLogger,
      bool logError = true}) async {
    try {
      return await this;
    } catch (e, s) {
      if (logError) errorLogger.logError(e, s);
      if (onError != null) {
        await onError(e, s);
      }
      return onErrorValue;
    }
  }
}

extension FutureNonNullOnErrorExtension<T extends Object> on Future<T> {
  /// Calls [onSuccess] or [onError] when this [Future] completes.
  ///
  /// Logs the error using [errorLogger] or [defaultAsyncExtensionErrorLogger]
  /// if parameter [logError] is `true`.
  Future<T?> onComplete({
    required FutureOr<void> Function(T r) onSuccess,
    required FutureOr<void> Function(Object e, StackTrace s) onError,
    AsyncExtensionErrorLogger? errorLogger,
    bool logError = true,
  }) async {
    try {
      var r = await this;
      await onSuccess(r);
      return r;
    } catch (e, s) {
      if (logError) errorLogger.logError(e, s);
      await onError(e, s);
      return null;
    }
  }

  /// Returns this [Future] value or `null` if it throws an error.
  ///
  /// Logs the error using [errorLogger] or [defaultAsyncExtensionErrorLogger]
  /// if parameter [logError] is `true`.
  Future<T?> nullOnError(
      {FutureOr<void> Function(Object e, StackTrace s)? onError,
      AsyncExtensionErrorLogger? errorLogger,
      bool logError = true}) async {
    try {
      var r = await this;
      return r;
    } catch (e, s) {
      if (logError) errorLogger.logError(e, s);
      if (onError != null) {
        await onError(e, s);
      }
      return null;
    }
  }
}

extension FutureNullableOnErrorExtension<T extends Object> on Future<T?> {
  /// Calls [onSuccess] or [onError] when this [Future] completes.
  /// If [onErrorOrNull] is defined, calls [onErrorOrNull] if it completes
  /// with `null` or with an error.
  ///
  /// Logs the error using [errorLogger] or [defaultAsyncExtensionErrorLogger]
  /// if parameter [logError] is `true`.
  Future<T?> onComplete({
    required FutureOr<void> Function(T? r) onSuccess,
    FutureOr<void> Function(Object e, StackTrace s)? onError,
    FutureOr<void> Function(Object? e, StackTrace? s)? onErrorOrNull,
    AsyncExtensionErrorLogger? errorLogger,
    bool logError = true,
  }) async {
    try {
      var r = await this;

      if (r == null && onErrorOrNull != null) {
        await onErrorOrNull(null, null);
      } else {
        await onSuccess(r);
      }

      return r;
    } catch (e, s) {
      if (logError) errorLogger.logError(e, s);

      if (onErrorOrNull != null) {
        await onErrorOrNull(e, s);
      } else if (onError != null) {
        await onError(e, s);
      }

      return null;
    }
  }

  /// Calls [onSuccess] or [onErrorOrNull] when this [Future] completes.
  /// Calls [onErrorOrNull] If it completes with `null` or with an error.
  ///
  /// Logs the error using [errorLogger] or [defaultAsyncExtensionErrorLogger]
  /// if parameter [logError] is `true`.
  Future<T?> onCompleteNotNull({
    required FutureOr<void> Function(T r) onSuccess,
    required FutureOr<void> Function(Object? e, StackTrace? s) onErrorOrNull,
    AsyncExtensionErrorLogger? errorLogger,
    bool logError = true,
  }) async {
    try {
      var r = await this;

      if (r == null) {
        await onErrorOrNull(null, null);
      } else {
        await onSuccess(r);
      }

      return r;
    } catch (e, s) {
      if (logError) errorLogger.logError(e, s);

      await onErrorOrNull(e, s);

      return null;
    }
  }

  /// Returns this [Future] value or `null` if it throws an error.
  ///
  /// Logs the error using [errorLogger] or [defaultAsyncExtensionErrorLogger]
  /// if parameter [logError] is `true`.
  Future<T?> nullOnError(
      {FutureOr<void> Function(Object e, StackTrace s)? onError,
      FutureOr<void> Function(Object? e, StackTrace? s)? onErrorOrNull,
      AsyncExtensionErrorLogger? errorLogger,
      bool logError = true}) async {
    try {
      var r = await this;
      if (r == null && onErrorOrNull != null) {
        await onErrorOrNull(null, null);
      }
      return r;
    } catch (e, s) {
      if (logError) errorLogger.logError(e, s);

      if (onErrorOrNull != null) {
        await onErrorOrNull(e, s);
      } else if (onError != null) {
        await onError(e, s);
      }

      return null;
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

extension MapFutureValueExtension<K, V> on Map<K, FutureOr<V>> {
  /// Resolve all [Map] values (non nullable).
  FutureOr<Map<K, V>> resolveAllValues() {
    var self = this;
    if (self is Map<K, V> && _isNotFuture(V)) {
      return self;
    }

    var keys = this.keys.toList(growable: false);
    var futureValues =
        keys.map((k) => this[k]!).cast<FutureOr<V>>().toList(growable: false);

    return futureValues.resolveAllJoined((values) {
      var entries = List.generate(values.length, (i) {
        var k = keys[i];
        var v = values[i];
        return MapEntry(k, v);
      });
      return Map<K, V>.fromEntries(entries);
    });
  }
}

extension MapFutureValueNullableExtension<K, V extends Object>
    on Map<K, FutureOr<V?>> {
  /// Resolve all [Map] values that can be `null`.
  FutureOr<Map<K, V?>> resolveAllValuesNullable() {
    var self = this;
    if (self is Map<K, V?> && _isNotFuture(V)) {
      return self;
    }

    var keys = this.keys.toList(growable: false);
    var futureValues =
        keys.map((k) => this[k]).cast<FutureOr<V?>>().toList(growable: false);

    return futureValues.resolveAllNullable().resolveMapped((values) {
      var entries = List.generate(values.length, (i) {
        var k = keys[i];
        var v = values[i];
        return MapEntry(k, v);
      });
      return Map<K, V?>.fromEntries(entries);
    });
  }
}

extension MapFutureKeyExtension<K, V> on Map<FutureOr<K>, V> {
  /// Resolve all [Map] keys.
  FutureOr<Map<K, V>> resolveAllKeys() {
    var self = this;
    if (self is Map<K, V> && _isNotFuture(K)) {
      return self;
    }

    var futureKeys = keys.toList(growable: false);
    var values = keys.map((k) => this[k]!).toList(growable: false);

    return futureKeys.resolveAllJoined((keys) {
      var entries = List.generate(values.length, (i) {
        var k = keys[i];
        var v = values[i];
        return MapEntry(k, v);
      });
      return Map<K, V>.fromEntries(entries);
    });
  }
}

extension MapFutureExtension<K, V> on Map<FutureOr<K>, FutureOr<V>> {
  /// Resolve all [Map] entries.
  FutureOr<Map<K, V>> resolveAllEntries() {
    var self = this;
    if (self is Map<K, V> && _isNotFuture(K) && _isNotFuture(V)) {
      return self;
    }

    var futureKeys = keys.toList(growable: false);
    var futureValues = keys.map((k) => this[k]!).toList(growable: false);

    return futureKeys.resolveAllJoined((keys) {
      return futureValues.resolveAllJoined((values) {
        var entries = List.generate(values.length, (i) {
          var k = keys[i];
          var v = values[i];
          return MapEntry(k, v);
        });
        return Map<K, V>.fromEntries(entries);
      });
    });
  }
}

extension IterableMapEntryFutureValueExtension<K, V>
    on Iterable<MapEntry<K, FutureOr<V>>> {
  /// Resolve all [MapEntry] values.
  FutureOr<Iterable<MapEntry<K, V>>> resolveAllValues() {
    var self = this;
    if (self is Iterable<MapEntry<K, V>> && _isNotFuture(V)) {
      return self;
    }

    var keys = <K>[];
    var futureValues = <FutureOr<V>>[];

    for (var e in self) {
      keys.add(e.key);
      futureValues.add(e.value);
    }

    return futureValues.resolveAllJoined((values) {
      var entries = List.generate(values.length, (i) {
        var k = keys[i];
        var v = values[i];
        return MapEntry(k, v);
      });
      return entries;
    });
  }
}

extension IterableMapEntryFutureKeyExtension<K, V>
    on Iterable<MapEntry<FutureOr<K>, V>> {
  /// Resolve all [MapEntry] keys.
  FutureOr<Iterable<MapEntry<K, V>>> resolveAllKeys() {
    var self = this;
    if (self is Iterable<MapEntry<K, V>> && _isNotFuture(K)) {
      return self;
    }

    var futureKeys = <FutureOr<K>>[];
    var values = <V>[];

    for (var e in self) {
      futureKeys.add(e.key);
      values.add(e.value);
    }

    return futureKeys.resolveAllJoined((keys) {
      var entries = List.generate(values.length, (i) {
        var k = keys[i];
        var v = values[i];
        return MapEntry(k, v);
      });
      return entries;
    });
  }
}

extension IterableMapEntryFutureExtension<K, V>
    on Iterable<MapEntry<FutureOr<K>, FutureOr<V>>> {
  /// Resolve all [MapEntry] entries.
  FutureOr<Iterable<MapEntry<K, V>>> resolveAllEntries() {
    var self = this;
    if (self is Iterable<MapEntry<K, V>> &&
        _isNotFuture(K) &&
        _isNotFuture(V)) {
      return self;
    }

    var futureKeys = <FutureOr<K>>[];
    var futureValues = <FutureOr<V>>[];

    for (var e in self) {
      futureKeys.add(e.key);
      futureValues.add(e.value);
    }

    return futureKeys.resolveAllJoined((keys) {
      return futureValues.resolveAllJoined((values) {
        var entries = List.generate(values.length, (i) {
          var k = keys[i];
          var v = values[i];
          return MapEntry(k, v);
        });
        return entries;
      });
    });
  }
}

extension FutureOrIterableExtension<T> on FutureOr<Iterable<T>> {
  FutureOr<List<T>> toListAsync({bool growable = true}) =>
      then((itr) => itr.toList());

  FutureOr<Set<T>> toSetAsync() => then((itr) => itr.toSet());

  FutureOr<List<T>> get asListAsync =>
      then((itr) => itr is List<T> ? itr : itr.toList());

  FutureOr<int> get lengthAsync => then((itr) => itr.length);

  FutureOr<bool> get isEmptyAsync => then((itr) => itr.isEmpty);

  FutureOr<bool> get isNotEmptyAsync => then((itr) => itr.isNotEmpty);

  FutureOr<T> get firstAsync => then((itr) => itr.first);

  FutureOr<T?> get firstOrNullAsync =>
      then((itr) => IterableExtensions(itr).firstOrNull);

  FutureOr<T> get lastAsync => then((itr) => itr.last);

  FutureOr<T?> get lastOrNullAsync =>
      then((itr) => IterableExtensions(itr).lastOrNull);
}

extension FutureIterableExtension<T> on Future<Iterable<T>> {
  FutureOr<List<T>> toListAsync({bool growable = true}) =>
      then((itr) => itr.toList());

  Future<Set<T>> toSetAsync() => then((itr) => itr.toSet());

  Future<List<T>> get asListAsync =>
      then((itr) => itr is List<T> ? itr : itr.toList());

  Future<int> get lengthAsync => then((itr) => itr.length);

  Future<bool> get isEmptyAsync => then((itr) => itr.isEmpty);

  Future<bool> get isNotEmptyAsync => then((itr) => itr.isNotEmpty);

  Future<T> get firstAsync => then((itr) => itr.first);

  Future<T?> get firstOrNullAsync => then((itr) => itr.firstOrNull);

  Future<T> get lastAsync => then((itr) => itr.last);

  Future<T?> get lastOrNullAsync => then((itr) => itr.lastOrNull);
}

extension FutureOrIterableNullableExtension<T> on FutureOr<Iterable<T>?> {
  FutureOr<List<T>?> toListOrNullAsync({bool growable = true}) =>
      then((itr) => itr?.toList());

  FutureOr<Set<T>?> toSetOrNullAsync() => then((itr) => itr?.toSet());

  FutureOr<List<T>?> get asListOrNullAsync =>
      then((itr) => itr is List<T> ? itr : itr?.toList());

  FutureOr<bool> get isEmptyOrNullAsync =>
      then((itr) => itr == null || itr.isEmpty);

  FutureOr<bool> get isNotEmptyAsync =>
      then((itr) => itr != null && itr.isNotEmpty);

  FutureOr<T?> get firstOrNullAsync =>
      then((itr) => itr != null ? IterableExtensions(itr).firstOrNull : null);

  FutureOr<T?> get lastOrNullAsync =>
      then((itr) => itr != null ? IterableExtensions(itr).lastOrNull : null);
}

extension FutureIterableNullableExtension<T> on Future<Iterable<T>?> {
  Future<List<T>?> toListOrNullAsync({bool growable = true}) =>
      then((itr) => itr?.toList());

  Future<Set<T>?> toSetOrNullAsync() => then((itr) => itr?.toSet());

  Future<List<T>?> get asListOrNullAsync =>
      then((itr) => itr is List<T> ? itr : itr?.toList());

  Future<bool> get isEmptyOrNullAsync =>
      then((itr) => itr == null || itr.isEmpty);

  Future<bool> get isNotEmptyAsync =>
      then((itr) => itr != null && itr.isNotEmpty);

  Future<T?> get firstOrNullAsync =>
      then((itr) => itr != null ? IterableExtensions(itr).firstOrNull : null);

  Future<T?> get lastOrNullAsync =>
      then((itr) => itr != null ? IterableExtensions(itr).lastOrNull : null);
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

extension FutureNullableExtension<T extends Object> on Future<T?> {
  /// Returns the value of this [Future] ([T]). If the value is null,
  /// it will return the [defaultValue].
  Future<T> orElseAsync(T defaultValue) =>
      then((value) => value ?? defaultValue);

  /// Returns the value of this [Future] ([T]). If the value is null,
  /// it will return the value returned by [defaultGetter].
  Future<T> orElseGeAsync(FutureOr<T> Function() defaultGetter) =>
      then((value) => value ?? defaultGetter());
}

extension FutureOrNullableExtension<T extends Object> on FutureOr<T?> {
  /// Returns the value of this [FutureOr] ([T]). If the value is null,
  /// it will return the [defaultValue].
  FutureOr<T> orElseAsync(T defaultValue) =>
      then((value) => value ?? defaultValue);

  /// Returns the value of this [Future] ([T]). If the value is null,
  /// it will return the value returned by [defaultGetter].
  FutureOr<T> orElseGeAsync(FutureOr<T> Function() defaultGetter) =>
      then((value) => value ?? defaultGetter());
}

extension CompleterExtension<T> on Completer {
  /// Calls [complete] only if ![isCompleted] and returns `true`,
  /// otherwise just returns `false`.
  bool completeSafe([FutureOr<T>? value]) {
    if (!isCompleted) {
      complete(value);
      return true;
    }
    return false;
  }

  /// Calls [completeError] only if ![isCompleted] and returns `true`,
  /// otherwise just returns `false`.
  bool completeErrorSafe(Object error, [StackTrace? stackTrace]) {
    if (!isCompleted) {
      completeError(error, stackTrace);
      return true;
    }
    return false;
  }
}

extension IterableAsyncExtension<T> on Iterable<T> {
  /// Perform a `forEach` allow [FutureOr] returns, then maps all the
  /// results in a single [List].
  FutureOr<List<R>> forEachAsync<R>(FutureOr<R> Function(T e) processor) {
    var itr = iterator;

    if (!itr.moveNext()) {
      return [];
    }

    var e0 = itr.current;
    var r0 = processor(e0);

    if (r0 is Future<R>) {
      return _forEachAIterateAsync(processor, itr, r0, null);
    } else {
      var results = <R>[r0];

      while (itr.moveNext()) {
        var e1 = itr.current;
        var r1 = processor(e1);

        if (r1 is Future<R>) {
          return _forEachAIterateAsync(processor, itr, r1, results);
        } else {
          results.add(r1);
        }
      }

      return results;
    }
  }

  Future<List<R>> _forEachAIterateAsync<R>(FutureOr<R> Function(T e) processor,
      Iterator<T> itr, Future<R> r0Async, List<R>? results) async {
    var r0 = await r0Async;

    if (results == null) {
      results = <R>[r0];
    } else {
      results.add(r0);
    }

    while (itr.moveNext()) {
      var e1 = itr.current;
      var r1 = await processor(e1);
      results.add(r1);
    }

    return results;
  }
}

/// An async loop, similar to a `for` loop block.
///
/// - [i] the `for` cursor.
/// - [condition] the `for` condition.
/// - [next] the `for` next/after statement.
/// - [body] the `for` body/block.
class AsyncLoop<I> {
  /// The `for` cursor.
  I i;

  /// The `for` condition.
  final bool Function(I i) condition;

  /// The `for` next/after statement.
  final I Function(I i) next;

  /// The `for` body/block.
  final FutureOr<bool> Function(I i) body;

  /// Constructor.
  ///
  /// - [init] is the initial value of [i]
  AsyncLoop(I init, this.condition, this.next, this.body)
      :
        // ignore: prefer_initializing_formals
        i = init;

  static AsyncLoop forEach<T>(
      Iterable<T> itr, FutureOr<bool> Function(T e) block) {
    if (itr is List<T>) {
      return AsyncLoop<int>(
          0, (i) => i < itr.length, (i) => i + 1, (i) => block(itr[i]));
    } else {
      var iterator = itr.iterator;
      return AsyncLoop<int>(0, (i) => iterator.moveNext(), (i) => i + 1,
          (_) => block(iterator.current));
    }
  }

  FutureOr<I> run() {
    return _runBody(i);
  }

  FutureOr<I> _runBody(I i) {
    while (condition(i)) {
      var ret = body(i);

      if (ret is Future<bool>) {
        return ret.then((ok) {
          if (!ok) {
            return i;
          }

          i = next(i);
          return _runBody(i);
        });
      } else {
        if (!ret) {
          return i;
        }

        i = next(i);
      }
    }

    return i;
  }
}

/// An async sequence loop, from [i] to [limit] (exclusive).
///
/// - See [AsyncLoop].
class AsyncSequenceLoop {
  /// The `for` cursor.
  int i;

  /// The [i] limit (exclusive) for the sequence.
  final int limit;

  /// The `for` body/block.
  final FutureOr<bool> Function(int i) body;

  /// Constructor.
  ///
  /// - [init] is the initial value of [i].
  AsyncSequenceLoop(int init, this.limit, this.body)
      :
        // ignore: prefer_initializing_formals
        i = init;

  FutureOr<int> run() {
    return _runBody(i);
  }

  FutureOr<int> _runBody(int i) {
    if (i >= limit) {
      return i;
    }

    var ret = body(i);

    if (ret is Future<bool>) {
      return ret.then((ok) {
        if (!ok) {
          return i;
        }

        ++i;
        return _runBody(i);
      });
    } else {
      if (!ret) {
        return i;
      }

      ++i;
      return _runBody(i);
    }
  }
}

extension ExpandoFutureExtension<T> on Expando<Future<T>> {
  Future<T> putIfAbsentAsync(Object? o, FutureOr<T> Function() ifAbsent) {
    if (o == null) {
      return ifAbsent().asFuture;
    }

    var prev = this[o];
    if (prev != null) return prev;

    var ret = ifAbsent().asFuture;
    this[o] = ret;
    return ret;
  }
}

extension ExpandoFutureOrExtension<T extends Object> on Expando<FutureOr<T>> {
  FutureOr<T> putIfAbsentAsync(Object? o, FutureOr<T> Function() ifAbsent) {
    if (o == null) {
      return ifAbsent();
    }

    var prev = this[o];
    if (prev != null) return prev;

    var ret = ifAbsent();

    if (ret is Future<T>) {
      return this[o] = ret.then((r) {
        this[o] = r;
        return r;
      });
    } else {
      this[o] = ret;
      return ret;
    }
  }
}

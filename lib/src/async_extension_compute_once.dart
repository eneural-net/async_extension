import 'dart:async';

import 'async_extension_base.dart';

/// Signature for a computation executed by [ComputeOnce].
///
/// The callback may return a value synchronously or a [Future] that completes
/// with the value [V] or an error.
typedef ComputeCall<V> = FutureOr<V> Function();

/// Callback invoked after a computation completes.
///
/// [value] is non-null on success.
/// [error] and [stackTrace] are non-null on failure.
typedef PosComputeCall<V> = V Function(
    V? value, Object? error, StackTrace? stackTrace)?;

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
  ComputeCall<V>? _call;

  /// Optional callback invoked after the computation completes.
  ///
  /// On success, [value] is non-null.
  /// On failure, [error] and [stackTrace] are non-null.
  PosComputeCall<V>? posCompute;

  /// Creates a [ComputeOnce] wrapping [_call].
  ///
  /// If [resolve] is true, starts resolving immediately.
  ComputeOnce(ComputeCall<V> call, {this.posCompute, bool resolve = true})
      : _call = _resolveCall(call) {
    if (resolve) {
      resolveAsync();
    }
  }

  /// Widens callbacks that return `Future<Never>`.
  ///
  /// A `Future<Never>` cannot produce a `V`, which breaks `onError` and
  /// `onErrorValue`. This wraps the call so it is treated as
  /// `FutureOr<V> Function()` while preserving behavior.
  static ComputeCall<V> _resolveCall<V>(ComputeCall<V> call) {
    if (call is Future<Never> Function()) {
      Future<V> callCast() => call().then<V>((v) => v as V);
      return callCast;
    }
    return call;
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
        if (onError != null) {
          return future.catchError(onError);
        } else {
          return future.catchError((e, s) => onErrorValue as V);
        }
      }
      return future;
    }

    FutureOr<V> resolveError(Object e, StackTrace s) {
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
        Error.throwWithStackTrace(e, s);
      }
    }

    final posCompute = this.posCompute;
    final FutureOr<V> call;

    try {
      var computer = _call ?? (throw StateError("Null `_call`"));
      call = computer();

      if (call is Future<V>) {
        future = _future = call;

        if (posCompute != null) {
          future = _future = future.then((v) {
            return posCompute(v, null, null);
          }, onError: (e, s) {
            return posCompute(null, e, s);
          });
        }

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
          if (onError != null) {
            return future.catchError(onError);
          } else {
            return future.catchError((e, s) => onErrorValue as V);
          }
        }

        return future;
      } else {
        var value = call;
        if (posCompute != null) {
          try {
            value = posCompute(value, null, null);
          } catch (e, s) {
            return resolveError(e, s);
          }
        }

        _result = (value: value, error: null, stackTrace: null);
        _call = null;
        onCompute(value, null, null);
        return call;
      }
    } catch (e, s) {
      return resolveError(e, s);
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
        if (onError != null) {
          return future.catchError(onError);
        } else {
          return future.catchError((e, s) => onErrorValue as V);
        }
      }
      return future;
    }

    var computer = _call ?? (throw StateError("Null `_call`"));
    future = _future = Future(computer);

    final posCompute = this.posCompute;
    if (posCompute != null) {
      future = _future = future.then((v) {
        return posCompute(v, null, null);
      }, onError: (e, s) {
        return posCompute(null, e, s);
      });
    }

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
      if (onError != null) {
        return future.catchError(onError);
      } else {
        return future.catchError((e, s) => onErrorValue as V);
      }
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
  TimedComputeOnce(super.call, {super.posCompute, super.resolve});

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

/// Caches [TimedComputeOnce] instances by key, ensuring each computation
/// is executed only once while retained.
///
/// After resolution, entries are kept for [retentionDuration]. When the
/// duration is zero, entries are removed immediately.
class ComputeOnceCache<K extends Object, V> {
  /// How long a resolved computation is kept in the cache.
  final Duration retentionDuration;

  /// Creates a cache with an optional [retentionDuration].
  ///
  /// Defaults to [Duration.zero], meaning immediate eviction after resolve.
  ComputeOnceCache({this.retentionDuration = Duration.zero});

  final _calls = <K, TimedComputeOnce<V>>{};
  final _timers = <K, Timer>{};

  /// Returns an existing [TimedComputeOnce] for [key] or creates a new one.
  ///
  /// - [call] is executed at most once per key while retained.
  /// - [posCompute], if provided, is invoked after resolution and before the end of the retention period.
  /// - If [resolve] is true, the computation may resolve eagerly.
  TimedComputeOnce<V> get(K key, ComputeCall<V> call,
      {PosComputeCall<V>? posCompute, bool resolve = true}) {
    var computer = _calls[key];
    if (computer != null) {
      return computer;
    }

    computer = _calls[key] =
        TimedComputeOnce(call, posCompute: posCompute, resolve: resolve);

    computer.whenResolved((v, e, s) {
      final prev = _calls[key];
      if (!identical(prev, computer)) return;

      if (retentionDuration == Duration.zero) {
        _removeInternal(key);
      } else {
        _timers[key]?.cancel();
        _timers[key] = Timer(retentionDuration, () {
          final prev = _calls[key];
          if (identical(prev, computer)) {
            _removeInternal(key);
          }
        });
      }
    });

    return computer;
  }

  TimedComputeOnce<V>? _removeInternal(K key) {
    _timers.remove(key)?.cancel();
    return _calls.remove(key);
  }

  /// Removes a cached computation and cancels any associated timer.
  TimedComputeOnce<V>? remove(K key) => _removeInternal(key);

  /// Returns a snapshot of current cached computations.
  Map<K, TimedComputeOnce<V>> calls() => Map.from(_calls);

  /// Clears the cache and cancels all retention timers.
  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _calls.clear();
  }
}

/// Signature for computing values for a list of IDs.
///
/// The callback receives a list of IDs and returns a list of values in the
/// same order, either synchronously or asynchronously.
typedef ComputeCallIDs<D extends Object, V> = FutureOr<List<V>> Function(
    List<D> ids);

/// A [ComputeOnceCache] specialized for batched computations by ID.
///
/// Requests with overlapping ID sets share in-flight computations.
/// Results are merged, deduplicated, and returned in the same order as
/// the requested IDs.
class ComputeOnceCachedIDs<D extends Object, V>
    extends ComputeOnceCache<ComputeIDs<D>, List<V>> {
  /// Optional comparator used to order IDs and results.
  final ComputeIDCompare<D>? compare;

  /// Optional hash function used for IDs.
  final ComputeIDHash<D>? hash;

  /// Creates a cache for batched ID-based computations.
  ///
  /// [compare] defines ID ordering and equality.
  /// [hash] defines how IDs are grouped internally.
  ComputeOnceCachedIDs(
      {super.retentionDuration, ComputeIDCompare<D>? compare, this.hash})
      : compare = _Comparer.resolveCompare(compare);

  /// Returns computations for the given [ids], reusing any overlapping
  /// in-flight computations.
  ///
  /// - Only IDs not already being computed will trigger a new call.
  /// - [posCompute], if provided, is invoked after each computation resolves.
  /// - If [resolve] is true, computations may resolve eagerly.
  ///
  /// Returns a map of computations keyed by their ID sets.
  ///
  /// Each entry represents a computation responsible for a subset of [ids].
  /// Existing in-flight computations are reused, and a new computation is
  /// created only for IDs not currently being computed.
  ///
  /// The returned map contains all computations required to fully resolve
  /// the requested [ids].
  ///
  /// See [computeIDs].
  Map<ComputeIDs<D>, TimedComputeOnce<List<V>>> getByIDs(
      List<D> ids, ComputeCallIDs<D, V> call,
      {PosComputeCall<List<V>>? posCompute, bool resolve = true}) {
    var calling = _calls.entries.where((e) => e.key.containsAny(ids)).toList();

    var callingIDs = calling.map((c) => c.key.ids);

    var idsNotCalling = ids.toList();
    for (var callIDs in callingIDs) {
      for (var id in callIDs) {
        idsNotCalling.remove(id);
      }
    }

    final idsNotCallingKey =
        ComputeIDs(idsNotCalling, compare: compare, hash: hash);

    var computer = get(idsNotCallingKey, () => call(idsNotCallingKey.ids),
        resolve: resolve);

    var computers = Map.fromEntries([
      MapEntry(idsNotCallingKey, computer),
      ...calling,
    ]);

    return computers;
  }

  /// Computes values for the given [ids], reusing and composing the
  /// computations returned by [getByIDs].
  ///
  /// Overlapping or in-flight ID computations are shared, and only missing
  /// IDs trigger new computation.
  ///
  /// The returned list respects the order of [ids] and contains `(ID, value)`
  /// pairs aligned with the input sequence.
  ///
  /// The result may be returned synchronously or asynchronously.
  FutureOr<List<(D, V)>> computeIDs(List<D> ids, ComputeCallIDs<D, V> call,
      {PosComputeCall<List<V>>? posCompute, bool resolve = true}) {
    var computers =
        getByIDs(ids, call, posCompute: posCompute, resolve: resolve);

    return computers.computeAll().resolveMapped((results) {
      var allComputations = results.entries.map((e) {
        var computedIDs = e.key;
        var computedValues = e.value;

        var intersectionIDs = computedIDs.intersection(ids);
        if (intersectionIDs.isEmpty) return <(D, V)>[];

        if (intersectionIDs.length == ids.length) {
          var values = List.generate(computedIDs.length, (i) {
            var id = computedIDs[i];
            var v = computedValues[i];
            return (id, v);
          });
          return values;
        }

        var intersectionValues = computedIDs.getValuesByIndexes(
          intersectionIDs.map((e) => e.$1),
          computedValues,
        );

        return intersectionValues;
      }).toList();

      if (allComputations.isEmpty) {
        return [];
      }

      final cmp = compare ?? _Comparer._defaultCompare;

      List<(D, V)> allComputedValues;

      if (allComputations.length == 1) {
        // Already sorted:
        allComputedValues = allComputations.first;
      } else {
        allComputedValues = allComputations.expand((l) => l).toList();
        // Ensure sorted:
        if (allComputedValues.length > 1) {
          allComputedValues.sort((a, b) => cmp(a.$1, b.$1));
        }
      }

      if (allComputedValues.length <= 1) {
        assert(allComputedValues.isEmpty ||
            ids.contains(allComputedValues.first.$1));

        return allComputedValues;
      }

      var idsValues = ids
          .map((id) => allComputedValues.binarySearch(id, cmp))
          .nonNulls
          .toList();

      return idsValues;
    });
  }
}

/// Binary-search utilities for lists of `(ID, value)` pairs.
///
/// The list **must be sorted by ID** according to the provided comparator
/// (or the default comparator) for correct results.
extension ListIdValuePairExtension<D extends Object, V> on List<(D, V)> {
  /// Returns the index of the entry with the given [id], or `-1` if not found.
  ///
  /// Uses binary search and runs in `O(log n)`.
  /// The list must be sorted by ID using [compare].
  int binarySearchIndex(D id, [ComputeIDCompare<D>? compare]) {
    if (isEmpty) return -1;
    compare ??= _Comparer._defaultCompare;
    var v0 = first.$2;
    return _Comparer.binarySearchIndex<(D, V)>(
        this, (id, v0), (a, b) => compare!(a.$1, b.$1));
  }

  /// Returns the `(ID, value)` pair for [id], or `null` if not found.
  ///
  /// Uses binary search and runs in `O(log n)`.
  /// The list must be sorted by ID using [compare].
  (D, V)? binarySearch(D id, [ComputeIDCompare<D>? compare]) {
    var idx = binarySearchIndex(id, compare);
    if (idx < 0) return null;
    return this[idx];
  }
}

/// Comparator used to order and compare IDs.
typedef ComputeIDCompare<D> = int Function(D a, D b);

/// Hash function used to compute a stable hash for an ID.
typedef ComputeIDHash<D> = int Function(D e);

/// An ordered, comparable, and hashable set of IDs.
///
/// IDs are copied and sorted on construction using [compare].
/// Equality and hashing are based on the ordered ID list.
class ComputeIDs<D extends Object> {
  final List<D> _ids;

  /// Unmodifiable view of the ordered IDs.
  List<D> get ids => List.unmodifiable(_ids);

  /// Comparator used to order and compare IDs.
  final ComputeIDCompare<D>? compare;

  /// Optional hash function used for hashCode computation.
  final ComputeIDHash<D>? hash;

  /// Creates a sorted ID collection.
  ///
  /// IDs are copied from [ids] and sorted using [compare].
  ComputeIDs(List<D> ids, {ComputeIDCompare<D>? compare, this.hash})
      : _ids = ids.toList(),
        compare = _Comparer.resolveCompare(compare) {
    _ids.sort(compare);
  }

  /// Number of IDs.
  int get length => _ids.length;

  /// Returns the ID at [index].
  D operator [](int index) => _ids[index];

  /// Returns the index of [value] using binary search, or `-1` if not found.
  ///
  /// Requires IDs to be sorted using [compare].
  int binarySearchIndex(D value) =>
      _Comparer.binarySearchIndex(_ids, value, compare);

  /// Returns true if any of the provided [ids] exist in this collection.
  bool containsAny(List<D> ids) {
    final compare = this.compare;

    if (compare != null) {
      for (var id in ids) {
        var idx = binarySearchIndex(id);
        if (idx >= 0) return true;
      }
    } else {
      for (var id1 in _ids) {
        for (var id2 in ids) {
          if (id1 == id2) return true;
        }
      }
    }

    return false;
  }

  /// Returns the intersection between this collection and [ids].
  ///
  /// Each entry is a pair of `(index, id)` where `index` refers to this
  /// collection's internal ordering.
  List<(int, D)> intersection(List<D> ids) {
    var l = <(int, D)>[];

    final compare = this.compare;

    if (compare != null) {
      for (var id in ids) {
        var idx = binarySearchIndex(id);
        if (idx >= 0) {
          l.add((idx, id));
        }
      }
    } else {
      final length = _ids.length;
      for (var i = 0; i < length; ++i) {
        var id1 = _ids[i];
        for (var id2 in ids) {
          if (id1 == id2) {
            l.add((i, id2));
          }
        }
      }
    }

    return l;
  }

  /// Returns `(ID, value)` pairs for the given [indexes].
  ///
  /// [values] must be aligned with this collection's internal ordering.
  List<(D, V)> getValuesByIndexes<V>(Iterable<int> indexes, List<V> values) {
    return indexes.map((i) {
      var id = _ids[i];
      return (id, values[i]);
    }).toList();
  }

  /// Returns true if [ids] are equal to this collection's IDs.
  ///
  /// Comparison respects [compare] when provided.
  bool equalsIDs(List<D>? ids) {
    if (ids == null) return false;

    final length = _ids.length;
    if (length != ids.length) return false;

    final compare = this.compare;

    if (compare != null) {
      for (var i = 0; i < length; ++i) {
        var id1 = _ids[i];
        var id2 = ids[i];
        if (compare(id1, id2) != 0) return false;
      }
    } else {
      for (var i = 0; i < length; ++i) {
        var id1 = _ids[i];
        var id2 = ids[i];
        if (id1 != id2) return false;
      }
    }

    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComputeIDs<D> &&
          runtimeType == other.runtimeType &&
          equalsIDs(other._ids);

  int? _hashCode;

  @override
  int get hashCode => _hashCode ??= _Comparer.computeHashcode(_ids, hash);

  @override
  String toString() => 'ComputeIDs$_ids';
}

abstract class _Comparer {
  static ComputeIDCompare<D>? resolveCompare<D>(ComputeIDCompare<D>? compare) {
    if (compare != null) return compare;

    if (D == int) {
      return _cmpInt as ComputeIDCompare<D>;
    } else if (D == double) {
      return _cmpDouble as ComputeIDCompare<D>;
    } else if (D == num) {
      return _cmpNum as ComputeIDCompare<D>;
    } else if (D == String) {
      return _cmpString as ComputeIDCompare<D>;
    }

    return null;
  }

  static int _cmpInt(int a, int b) => a.compareTo(b);

  static int _cmpDouble(double a, double b) => a.compareTo(b);

  static int _cmpNum(num a, num b) => a.compareTo(b);

  static int _cmpString(String a, String b) => a.compareTo(b);

  static int _defaultCompare(Object a, Object b) {
    if (a is Comparable && b is Comparable) {
      return a.compareTo(b);
    }
    throw StateError(
        'No comparator provided and elements are not Comparable: ${a.runtimeType} <=> ${b.runtimeType}');
  }

  static int binarySearchIndex<D extends Object>(List<D> ids, D value,
      [ComputeIDCompare<D>? compare]) {
    final cmp = compare ?? _defaultCompare;

    int low = 0;
    int high = ids.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final c = cmp(ids[mid], value);

      if (c < 0) {
        low = mid + 1;
      } else if (c > 0) {
        high = mid - 1;
      } else {
        return mid;
      }
    }

    return -1;
  }

  static const int _hashMask = 0x7fffffff;

  static int computeHashcode<D extends Object>(
      List<D>? list, ComputeIDHash<D>? hashFunction) {
    if (list == null) return null.hashCode;

    hashFunction ??= _defaultHash;

    // Jenkins's one-at-a-time hash function.
    // This code is almost identical to the one in IterableEquality, except
    // that it uses indexing instead of iterating to get the elements.
    var hash = 0;

    for (var i = 0; i < list.length; i++) {
      var c = hashFunction(list[i]);
      hash = (hash + c) & _hashMask;
      hash = (hash + (hash << 10)) & _hashMask;
      hash ^= hash >> 6;
    }

    hash = (hash + (hash << 3)) & _hashMask;
    hash ^= hash >> 11;
    hash = (hash + (hash << 15)) & _hashMask;

    return hash;
  }

  static int _defaultHash(Object e) => e.hashCode;
}

/// Utilities to resolve multiple [ComputeOnce] instances.
extension IterableComputeOnceExtension<V> on Iterable<ComputeOnce<V>> {
  /// Resolves all computations and returns their results in iteration order.
  ///
  /// If [throwError] is true, the first error is propagated.
  /// Otherwise, [onError] or [onErrorValue] is used to produce a fallback value.
  ///
  /// The result may be returned synchronously or asynchronously.
  FutureOr<List<V>> computeAll({
    bool throwError = true,
    FutureOr<V> Function(Object error, StackTrace stackTrace)? onError,
    V? onErrorValue,
  }) =>
      map((e) => e.resolve(
          throwError: throwError,
          onError: onError,
          onErrorValue: onErrorValue)).resolveAll();

  /// Asynchronously resolves all computations and returns their results
  /// in iteration order.
  ///
  /// Semantics are identical to [computeAll], but always returns a [Future].
  Future<List<V>> computeAllAsync({
    bool throwError = true,
    Future<V> Function(Object error, StackTrace stackTrace)? onError,
    V? onErrorValue,
  }) =>
      map((e) => e.resolveAsync(
          throwError: throwError,
          onError: onError,
          onErrorValue: onErrorValue)).resolveAll();
}

/// Utilities to resolve all [TimedComputeOnce] values in a map keyed by
/// [ComputeIDs].
extension MapComputeIDsExtension<D extends Object, V>
    on Map<ComputeIDs<D>, TimedComputeOnce<V>> {
  /// Resolves all computations and returns a map with the same keys.
  ///
  /// If [throwError] is true, the first error is propagated.
  /// Otherwise, [onError] or [onErrorValue] is used to produce a fallback value.
  ///
  /// The result may be returned synchronously or asynchronously.
  FutureOr<Map<ComputeIDs<D>, V>> computeAll(
          {bool throwError = true,
          FutureOr<V> Function(Object error, StackTrace stackTrace)? onError,
          V? onErrorValue}) =>
      Map.fromEntries(
        entries.map(
          (e) => MapEntry(
              e.key,
              e.value.resolve(
                  throwError: throwError,
                  onError: onError,
                  onErrorValue: onErrorValue)),
        ),
      ).resolveAllValues();

  /// Asynchronously resolves all computations and returns a map with the
  /// same keys.
  ///
  /// Semantics are identical to [computeAll], but always returns a [Future].
  Future<Map<ComputeIDs<D>, V>> computeAllAsync(
          {bool throwError = true,
          Future<V> Function(Object error, StackTrace stackTrace)? onError,
          V? onErrorValue}) =>
      Map<ComputeIDs<D>, Future<V>>.fromEntries(
        entries.map(
          (e) => MapEntry(
              e.key,
              e.value.resolveAsync(
                  throwError: throwError,
                  onError: onError,
                  onErrorValue: onErrorValue)),
        ),
      ).resolveAllValues().asFuture;
}

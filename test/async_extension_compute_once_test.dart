import 'package:async_extension/async_extension.dart';
import 'package:test/test.dart';

void main() {
  group('ComputeOnce', () {
    test('computes synchronously only once', () {
      var calls = 0;

      final c = ComputeOnce<int>(() {
        calls++;
        return 40 + calls;
      }, resolve: false);

      expect(c.isResolved, isFalse);

      final v1 = c.resolve();
      final v2 = c.resolve();

      expect(v1, 41);
      expect(v2, 41);
      expect(calls, 1);
      expect(c.value, 41);
      expect(c.isResolved, isTrue);
      expect(c.hasError, isFalse);
    });

    test('computes asynchronously only once: resolve()', () async {
      var calls = 0;

      final c = ComputeOnce<int>(() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 10 + calls;
      }, resolve: false);

      expect(c.isResolved, isFalse);

      final f1 = c.resolve();
      final f2 = c.resolve();

      expect(c.isResolved, isFalse);

      expect(f1, same(f2));

      final value = await f1;

      expect(value, 11);
      expect(calls, 1);
      expect(c.value, 11);
      expect(c.isResolved, isTrue);
      expect(c.hasError, isFalse);
    });

    test('computes asynchronously only once: resolveAsync()', () async {
      var calls = 0;

      final c = ComputeOnce<int>(() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 10 + calls;
      }, resolve: false);

      expect(c.isResolved, isFalse);

      final f1 = c.resolveAsync();
      final f2 = c.resolveAsync();

      expect(c.isResolved, isFalse);

      expect(f1, same(f2));

      final value = await f1;

      expect(value, 11);
      expect(calls, 1);
      expect(c.value, 11);
      expect(c.isResolved, isTrue);
      expect(c.hasError, isFalse);
    });

    test('caches synchronous error and rethrows', () {
      var calls = 0;
      final error = StateError('boom');

      final c = ComputeOnce<int>(() {
        calls++;
        throw error;
      }, resolve: false);

      expect(c.isResolved, isFalse);

      expect(() => c.resolve(), throwsA(same(error)));
      expect(() => c.resolve(), throwsA(same(error)));

      expect(calls, 1);
      expect(c.isResolved, isTrue);
      expect(c.hasError, isTrue);
      expect(c.error!.error, same(error));
    });

    test('caches asynchronous error and rethrows', () async {
      var calls = 0;
      final error = ArgumentError('fail');

      final c = ComputeOnce<int>(() async {
        calls++;
        throw error;
      }, resolve: false);

      expect(c.isResolved, isFalse);

      await expectLater(c.resolveAsync(), throwsA(same(error)));
      await expectLater(c.resolveAsync(), throwsA(same(error)));

      expect(calls, 1);
      expect(c.isResolved, isTrue);
      expect(c.hasError, isTrue);
      expect(c.error!.error, same(error));
    });

    test('resolveAsync returns completed future when already resolved',
        () async {
      final c = ComputeOnce<int>(() => 10, resolve: false);

      final v = c.resolve();
      expect(v, 10);

      final f = c.resolveAsync();
      expect(await f, 10);
    });

    test('eager resolve starts computation immediately', () async {
      var calls = 0;

      final c = ComputeOnce<int>(() async {
        calls++;
        return 5;
      });

      expect(c.isResolved, isFalse);

      final value = await c.resolveAsync();

      expect(value, 5);
      expect(calls, 1);
      expect(c.isResolved, isTrue);
    });

    test('then chains on resolved value', () async {
      final c = ComputeOnce<int>(() => 3, resolve: false);

      final result = await c.then((v) => v * 2);

      expect(result, 6);
      expect(c.value, 3);
    });

    test('whenComplete is called on successful resolution', () async {
      var completed = false;

      final c = ComputeOnce<int>(() => 10, resolve: false);

      final result = await c.whenComplete(() {
        completed = true;
      });

      expect(result, 10);
      expect(completed, isTrue);
      expect(c.isResolved, isTrue);
      expect(c.hasError, isFalse);
    });

    test('whenComplete is called on failed resolution', () async {
      var completed = false;
      final error = StateError('fail');

      final c = ComputeOnce<int>(() {
        throw error;
      }, resolve: false);

      await expectLater(
        c.whenComplete(() {
          completed = true;
        }),
        throwsA(same(error)),
      );

      expect(completed, isTrue);
      expect(c.isResolved, isTrue);
      expect(c.hasError, isTrue);
    });

    test('whenResolved receives value on success', () async {
      final c = ComputeOnce<int>(() => 7, resolve: false);

      final result = await c.whenResolved<String>((value, error, stack) {
        expect(error, isNull);
        expect(stack, isNull);
        return 'v=$value';
      });

      expect(result, 'v=7');
      expect(c.value, 7);
    });

    test('whenResolved receives error on failure and maps result', () async {
      final error = ArgumentError('bad');

      final c = ComputeOnce<int>(() {
        throw error;
      }, resolve: false);

      final result = await c.whenResolved<String>((value, err, stack) {
        expect(value, isNull);
        expect(err, same(error));
        expect(stack, isNotNull);
        return 'handled';
      });

      expect(result, 'handled');
      expect(c.isResolved, isTrue);
      expect(c.hasError, isTrue);
    });

    test('whenResolved can rethrow received error', () async {
      final error = StateError('boom');

      final c = ComputeOnce<int>(() {
        throw error;
      }, resolve: false);

      await expectLater(
        c.whenResolved((value, err, stack) {
          throw err!;
        }),
        throwsA(same(error)),
      );
    });
  });

  test('isResolving is true while async computation is in flight', () async {
    final c = ComputeOnce<int>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return 1;
    }, resolve: false);

    final f = c.resolveAsync();

    expect(c.isResolved, isFalse);
    expect(c.isResolving, isTrue);

    await f;

    expect(c.isResolving, isFalse);
    expect(c.isResolved, isTrue);
  });

  test('resolve with throwError=false returns fallback value on sync error',
      () {
    final error = StateError('fail');

    final c = ComputeOnce<int>(() {
      throw error;
    }, resolve: false);

    final v = c.resolve(
      throwError: false,
      onErrorValue: 99,
    );

    expect(v, 99);
    expect(c.isResolved, isTrue);
    expect(c.hasError, isTrue);
  });

  test('resolve with throwError=false uses onError callback', () {
    final error = ArgumentError('bad');

    final c = ComputeOnce<int>(() {
      throw error;
    }, resolve: false);

    final v = c.resolve(
      throwError: false,
      onError: (e, s) {
        expect(e, same(error));
        expect(s, isNotNull);
        return 42;
      },
    );

    expect(v, 42);
    expect(c.hasError, isTrue);
  });

  test('resolve with throwError=false returns fallback value on async error',
      () async {
    final error = StateError('fail');

    final c = ComputeOnce<int>(() async {
      throw error;
    }, resolve: false);

    final v = await c.resolve(
      throwError: false,
      onErrorValue: 99,
    );

    expect(v, 99);
    expect(c.isResolved, isTrue);
    expect(c.hasError, isTrue);
  });

  test('resolve with throwError=false uses onError callback', () async {
    final error = ArgumentError('bad');

    final c = ComputeOnce<int>(() async {
      throw error;
    }, resolve: false);

    final v = await c.resolve(
      throwError: false,
      onError: (e, s) {
        expect(e, same(error));
        expect(s, isNotNull);
        return 42;
      },
    );

    expect(v, 42);
    expect(c.hasError, isTrue);
  });

  test('resolveAsync with throwError=false returns fallback on async error',
      () async {
    final error = StateError('boom');

    final c = ComputeOnce<int>(() async {
      throw error;
    }, resolve: false);

    final v = await c.resolveAsync(
      throwError: false,
      onErrorValue: 7,
    );

    expect(v, 7);
    expect(c.isResolved, isTrue);
    expect(c.hasError, isTrue);
  });

  test('resolveAsync with throwError=false uses async onError handler',
      () async {
    final error = ArgumentError('fail');

    final c = ComputeOnce<int>(() async {
      throw error;
    }, resolve: false);

    final v = await c.resolveAsync(
      throwError: false,
      onError: (e, s) async {
        expect(e, same(error));
        expect(s, isNotNull);
        return 123;
      },
    );

    expect(v, 123);
    expect(c.hasError, isTrue);
  });

  test('resolve with delay+throwError=false uses async onError handler',
      () async {
    final error = ArgumentError('fail');

    final c = ComputeOnce<int>(() async {
      await Future.delayed(Duration(milliseconds: 100));
      throw error;
    }, resolve: false);

    final v1Async = c.resolve(
      throwError: false,
      onError: (e, s) async {
        expect(e, same(error));
        expect(s, isNotNull);
        return 123;
      },
    );

    final v2Async = c.resolve(
      throwError: false,
      onError: (e, s) async {
        expect(e, same(error));
        expect(s, isNotNull);
        return 456;
      },
    );

    final v3Async = c.resolve(throwError: false, onErrorValue: 789);

    final v1 = await v1Async;
    final v2 = await v2Async;
    final v3 = await v3Async;

    expect(c.hasError, isTrue);
    expect(c.error?.error, same(error));

    expect(v1, 123);
    expect(v2, 456);
    expect(v3, 789);

    final v4 = await c.resolve(
      throwError: false,
      onError: (e, s) async {
        expect(e, same(error));
        expect(s, isNotNull);
        return -123;
      },
    );

    expect(v4, -123);

    final v5 = await c.resolve(throwError: false, onErrorValue: -456);

    expect(v5, -456);
  });

  test('resolveAsync with delay+throwError=false uses async onError handler',
      () async {
    final error = ArgumentError('fail');

    final c = ComputeOnce<int>(() async {
      await Future.delayed(Duration(milliseconds: 100));
      throw error;
    }, resolve: false);

    final v1Async = c.resolveAsync(
      throwError: false,
      onError: (e, s) async {
        expect(e, same(error));
        expect(s, isNotNull);
        return 123;
      },
    );

    final v2Async = c.resolveAsync(
      throwError: false,
      onError: (e, s) async {
        expect(e, same(error));
        expect(s, isNotNull);
        return 456;
      },
    );

    final v3Async = c.resolveAsync(throwError: false, onErrorValue: 789);

    final v1 = await v1Async;
    final v2 = await v2Async;
    final v3 = await v3Async;

    expect(c.hasError, isTrue);
    expect(c.error?.error, same(error));

    expect(v1, 123);
    expect(v2, 456);
    expect(v3, 789);

    final v4 = await c.resolveAsync(
      throwError: false,
      onError: (e, s) async {
        expect(e, same(error));
        expect(s, isNotNull);
        return -123;
      },
    );

    expect(v4, -123);

    final v5 = await c.resolveAsync(throwError: false, onErrorValue: -456);

    expect(v5, -456);
  });

  test('onCompute is called exactly once on success', () async {
    final c = _MyComputeOnce<int>(() async => 5, resolve: false);

    await c.resolveAsync();

    var onComputeArgs = c.onComputeArgs;
    expect(onComputeArgs!.$1, 5);
    expect(onComputeArgs.$2, isNull);
    expect(onComputeArgs.$3, isNull);
  });

  test('onCompute is called exactly once on failure', () async {
    final error = StateError('fail');

    final c = _MyComputeOnce<int>(() {
      throw error;
    }, resolve: false);

    await expectLater(c.resolveAsync(), throwsA(same(error)));

    var onComputeArgs = c.onComputeArgs;
    expect(onComputeArgs!.$1, isNull);
    expect(onComputeArgs.$2, same(error));
    expect(onComputeArgs.$3, isNotNull);
  });

  test('toString reflects resolving, success and error states', () async {
    final c1 = ComputeOnce<int>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return 1;
    }, resolve: false);

    expect(c1.toString(), contains('@'));

    final f = c1.resolveAsync();
    expect(c1.toString(), contains('resolving'));

    await f;
    expect(c1.toString(), contains('<1>'));

    final c2 = ComputeOnce<int>(() {
      throw StateError('x');
    }, resolve: false);

    try {
      c2.resolve();
    } catch (_) {}

    expect(c2.toString(), contains('error'));
  });

  group('TimedComputeOnce', () {
    test('TimedComputeOnce sets resolvedAt on success and failure', () async {
      final c1 = TimedComputeOnce<int>(() => 10, resolve: false);
      await c1.resolveAsync();

      expect(c1.resolvedAt, isNotNull);
      expect(c1.elapsedTime().inMilliseconds, greaterThanOrEqualTo(0));

      final c2 = TimedComputeOnce<int>(() {
        throw StateError('fail');
      }, resolve: false);

      try {
        c2.resolve();
      } catch (_) {}

      expect(c2.resolvedAt, isNotNull);
    });
  });

  group('ComputeOnce posCompute', () {
    test('resolve(): sync posCompute is applied synchronously', () async {
      final c = ComputeOnce<int>(
        () => 1,
        posCompute: (v, e, s) => (v ?? 0) + 10,
      );

      // resolve may return a value or a Future; normalize with Future.value(...)
      final result = await Future.value(c.resolve());
      expect(result, equals(11));

      // subsequent resolves should return cached result (transformed)
      final result2 = await Future.value(c.resolve());
      expect(result2, equals(11));
    });

    test('resolve(): async posCompute is applied synchronously', () async {
      final c = ComputeOnce<int>(
        () async => 1,
        posCompute: (v, e, s) async => (v ?? 0) + 10,
      );

      // resolve may return a value or a Future; normalize with Future.value(...)
      final result = await Future.value(c.resolve());
      expect(result, equals(11));

      // subsequent resolves should return cached result (transformed)
      final result2 = await Future.value(c.resolve());
      expect(result2, equals(11));
    });

    test('resolveAsync(): sync posCompute is applied asynchronously', () async {
      final c = ComputeOnce<int>(
        () => 2,
        posCompute: (v, e, s) => (v ?? 0) * 10,
      );

      // resolveAsync always returns a Future
      final result = await c.resolveAsync();
      expect(result, equals(20));

      // subsequent resolves should return cached (transformed) result
      final result2 = await c.resolveAsync();
      expect(result2, equals(20));
    });

    test('resolveAsync(): async posCompute is applied asynchronously',
        () async {
      final c = ComputeOnce<int>(
        () async => 2,
        posCompute: (v, e, s) async => (v ?? 0) * 10,
      );

      // resolveAsync always returns a Future
      final result = await c.resolveAsync();
      expect(result, equals(20));

      // subsequent resolves should return cached (transformed) result
      final result2 = await c.resolveAsync();
      expect(result2, equals(20));
    });
  });

  group('ComputeOnceCache retention', () {
    test('entry is removed after retentionDuration elapses', () async {
      final cache = ComputeOnceCache<String, int>(
          retentionDuration: Duration(milliseconds: 20));

      // create a computation that resolves immediately
      final comp = cache.get('key', () async => 42, resolve: true);

      // ensure it resolves
      final res = await comp.resolveAsync();
      expect(res, equals(42));

      // while inside retention window the cache should contain the entry
      final snapshot1 = cache.calls();
      expect(snapshot1.containsKey('key'), isTrue);

      // wait longer than retentionDuration
      await Future.delayed(Duration(milliseconds: 60));

      final snapshot2 = cache.calls();
      expect(snapshot2.containsKey('key'), isFalse);
    });

    test('immediate eviction when retentionDuration is zero', () async {
      final cache =
          ComputeOnceCache<String, int>(retentionDuration: Duration.zero);

      final comp = cache.get('k2', () => Future.value(7), resolve: true);
      final res = await comp.resolveAsync();
      expect(res, equals(7));

      // immediate eviction: no retained entry after resolve
      final snapshot = cache.calls();
      expect(snapshot.containsKey('k2'), isFalse);
    });
  });

  group('ComputeIDs utilities', () {
    test('sorts with custom comparator and binarySearchIndex works', () {
      int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

      final ids = ComputeIDs<String>(['b', 'A', 'c'], compare: cmp);

      // internal ordering should be case-preserving but sorted by comparator
      expect(ids.ids.length, equals(3));
      expect(
          ids.ids[0], anyOf(equals('A'), equals('a'))); // 'A' should be first

      // binary search by different-case key should find correct index
      final idx = ids.binarySearchIndex('B');
      expect(idx, greaterThanOrEqualTo(0));
      expect(ids[idx].toLowerCase(), equals('b'));
    });

    test('intersection returns (index, id) pairs respecting comparator', () {
      int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

      final ids = ComputeIDs<String>(['a', 'b', 'c', 'd'], compare: cmp);
      final inter = ids.intersection(['C', 'x', 'b']);
      // should find 'C' -> 'c' and 'b'
      final foundIds = inter.map((t) => t.$2.toLowerCase()).toList()..sort();
      expect(foundIds, equals(['b', 'c']));
    });

    test('equality and hashCode for same ordered set', () {
      int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

      final a = ComputeIDs<String>(['A', 'b', 'c'], compare: cmp);
      final b = ComputeIDs<String>(['A', 'b', 'c'], compare: cmp);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('IterableComputeOnceExtension', () {
    test(
        'computeAll and computeAllAsync resolve multiple ComputeOnce instances',
        () async {
      final c1 = ComputeOnce<int>(() => 1);
      final c2 = ComputeOnce<int>(() async => 2);

      final res = await [c1, c2].computeAllAsync();
      expect(res, equals([1, 2]));

      // computeAll (sync-or-async path) should also work
      final res2 = await Future.value([c1, c2].computeAll());
      expect(res2, equals([1, 2]));
    });
  });

  group('ComputeOnceCachedIDs - batching and sharing', () {
    test('overlapping requests share in-flight computation when fully covered',
        () async {
      final cache = ComputeOnceCachedIDs<String, int>();
      var calls = 0;

      Future<List<int>> call(List<String> ids) async {
        calls++;
        // simulate work
        await Future.delayed(const Duration(milliseconds: 60));
        return ids.map((e) => int.parse(e)).toList();
      }

      // Start a big request that includes '2' and '3'
      final f1 = cache.computeIDs(['1', '2', '3'], call, resolve: true);

      // Give the first request a small head start so it becomes in-flight
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Second request asks for a subset ('2','3') that should be entirely
      // covered by the first in-flight computation -> no extra call expected.
      final f2 = cache.computeIDs(['2', '3'], call, resolve: true);

      final r1 = await f1;
      final r2 = await f2;

      // The underlying call should have executed only once (the second reused it)
      expect(calls, equals(1));

      // Validate results: both must contain the requested pairs, ordered by request
      expect(r1.map((p) => (p.$1, p.$2)).toList(),
          equals([('1', 1), ('2', 2), ('3', 3)]));
      expect(
          r2.map((p) => (p.$1, p.$2)).toList(), equals([('2', 2), ('3', 3)]));
    });

    test('partial overlap triggers only missing-id computation', () async {
      final cache = ComputeOnceCachedIDs<String, int>();
      var calls = <List<String>>[];

      Future<List<int>> call(List<String> ids) async {
        calls.add(ids.toList());
        await Future.delayed(const Duration(milliseconds: 10));
        return ids.map((e) => int.parse(e) * 10).toList();
      }

      // First request will compute for ['1','2']
      final p1 = cache.computeIDs(['1', '2'], call, resolve: true);

      // Start overlapping request shortly after that requests ['2','3']
      await Future<void>.delayed(const Duration(milliseconds: 3));
      final p2 = cache.computeIDs(['2', '3'], call, resolve: true);

      final r1 = await p1;
      final r2 = await p2;

      // We expect two underlying calls:
      //  - one for ['1','2'] (first request)
      //  - one for ['3'] (to cover missing id from second request)
      // order of calls recorded might be ['1','2'] then ['3']
      expect(calls.length, equals(2));
      expect(calls.any((ids) => ids.length == 1 && ids.first == '3'), isTrue);

      // Validate values: p1 are tens, p2 mixes reused values for '2' and new for '3'
      expect(r1.map((p) => p.$2).toList(), equals([10, 20]));
      // r2 should contain values for '2' and '3' in that order
      expect(r2.map((p) => p.$2).toList(), equals([20, 30]));
    });

    test('empty ids short-circuits and does not call compute function',
        () async {
      final cache = ComputeOnceCachedIDs<String, int>();
      var calls = 0;

      Future<List<int>> call(List<String> ids) async {
        calls++;
        // should not be called for empty ids in ideal behavior
        return ids.map((e) => int.parse(e)).toList();
      }

      final result = await cache.computeIDs([], call, resolve: true);
      expect(result, isEmpty);
      expect(calls, equals(0));
    });

    test('duplicate ids in input are preserved in output order', () async {
      final cache = ComputeOnceCachedIDs<String, int>();
      var callsCount = 0;

      Future<List<int>> call(List<String> ids) async {
        callsCount++;
        // return numeric value for each id in same order
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return ids.map((e) => int.parse(e)).toList();
      }

      // input contains duplicate '1'
      final result =
          await cache.computeIDs(['1', '1', '2'], call, resolve: true);

      // Expect single underlying call
      expect(callsCount, equals(1));

      // result values should preserve duplicates: [1,1,2]
      final values = result.map((p) => p.$2).toList();
      expect(values, equals([1, 1, 2]));
    });
  });

  group('posCompute behavior (success and async error)', () {
    test('posCompute (sync) transforms successful batched results', () async {
      final cache = ComputeOnceCachedIDs<String, int>();

      Future<List<int>> call(List<String> ids) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return ids.map((e) => int.parse(e)).toList();
      }

      // posCompute will add 100 to every value in the produced list.
      FutureOr<List<int>> post(List<int>? value, Object? error, StackTrace? s) {
        if (value == null) return [];
        return value.map((v) => v + 100).toList();
      }

      final res = await cache.computeIDs(
        ['1', '2'],
        call,
        posCompute: post,
        resolve: true,
      );

      expect(res.map((p) => p.$2).toList(), equals([101, 102]));
    });

    test('posCompute invoked on async error and can provide fallback',
        () async {
      final cache = ComputeOnceCachedIDs<String, int>();

      Future<List<int>> call(List<String> ids) async {
        // Always fail asynchronously so that posCompute onError path is executed
        await Future<void>.delayed(const Duration(milliseconds: 5));
        throw StateError('boom');
      }

      // posCompute sees null value and an error; returns a fallback list of -1s
      FutureOr<List<int>> onError(
          List<int>? value, Object? error, StackTrace? s) {
        // Provide fallback values for requested ids (length must match expected behavior)
        // We'll map each requested id to -1 (the caller expects a value for each requested id)
        return List<int>.filled(2, -1);
      }

      final res = await cache.computeIDs(
        ['x', 'y'],
        call,
        posCompute: onError,
        resolve: true,
      );

      expect(res.map((p) => p.$2).toList(), equals([-1, -1]));
    });
  });

  group('custom comparator integration', () {
    test('case-insensitive comparator allows sharing across different cases',
        () async {
      int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

      final cache = ComputeOnceCachedIDs<String, int>(compare: cmp);

      var calls = 0;
      Future<List<int>> call(List<String> ids) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return ids.map((e) => e.length).toList();
      }

      // Start a request with mixed-case ids
      final p1 = cache.computeIDs(['Ab', 'cD'], call, resolve: true);

      await Future<void>.delayed(const Duration(milliseconds: 3));

      // Second request uses same ids using different cases; with case-insensitive comparator
      // the in-flight computation should be reused and no extra compute should run.
      final p2 = cache.computeIDs(['ab', 'CD'], call, resolve: true);

      final r1 = await p1;
      final r2 = await p2;

      expect(calls, equals(1));

      // lengths returned for 'Ab' and 'cD' are both 2
      expect(r1.map((p) => p.$2).toList(), equals([2, 2]));
      expect(r2.map((p) => p.$2).toList(), equals([2, 2]));
    });
  });

  group('ComputeOnceCache & TimedComputeOnce (retention / resolvedAt)', () {
    test(
        'TimedComputeOnce sets resolvedAt and ComputeOnceCache retention works',
        () async {
      final cache = ComputeOnceCache<String, int>(
          retentionDuration: Duration(milliseconds: 40));

      final key = 'keep-me';
      final comp = cache.get(key, () async => 123, resolve: true);

      // Wait for resolution
      final v = await comp.resolveAsync();
      expect(v, equals(123));

      // The instance is a TimedComputeOnce: resolvedAt should be set
      expect(comp.resolvedAt, isNotNull);

      // While in retention window the cache should contain the entry
      final snapshot1 = cache.calls();
      expect(snapshot1.containsKey(key), isTrue);

      // After waiting past retentionDuration the key must be evicted automatically
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final snapshot2 = cache.calls();
      expect(snapshot2.containsKey(key), isFalse);
    });

    test('immediate eviction when retentionDuration is zero', () async {
      final cache =
          ComputeOnceCache<String, int>(retentionDuration: Duration.zero);

      final comp = cache.get('k2', () => Future.value(7), resolve: true);
      final res = await comp.resolveAsync();
      expect(res, equals(7));

      // immediate eviction: no retained entry after resolve
      final snapshot = cache.calls();
      expect(snapshot.containsKey('k2'), isFalse);
    });
  });

  group('ComputeOnceCachedIDs - more batching edge cases', () {
    test(
        'computation for empty ids returns empty list and does not call compute',
        () async {
      final cache = ComputeOnceCachedIDs<String, int>();

      var calls = 0;
      Future<List<int>> call(List<String> ids) async {
        calls++;
        return ids.map((e) => int.parse(e)).toList();
      }

      final res = await cache.computeIDs([], call, resolve: true);
      expect(res, isEmpty);
      expect(calls, equals(0));
    });

    test('duplicate ids in a single input are preserved as duplicate outputs',
        () async {
      final cache = ComputeOnceCachedIDs<String, int>();

      var calls = 0;
      Future<List<int>> call(List<String> ids) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return ids.map((e) => int.parse(e)).toList();
      }

      final res = await cache.computeIDs(['1', '1', '2'], call, resolve: true);

      // single underlying call
      expect(calls, equals(1));

      // duplicates preserved
      expect(res.length, equals(3));
      expect(res.map((p) => p.$2).toList(), equals([1, 1, 2]));
    });

    test('computeIDs returns only found values (missing results are filtered)',
        () async {
      final cache = ComputeOnceCachedIDs<String, int>();

      // call that intentionally returns fewer values than requested (simulates missing)
      Future<List<int>> call(List<String> ids) async {
        // return only the first value
        if (ids.isEmpty) return [];
        return [int.parse(ids.first)];
      }

      final res = await cache.computeIDs(['1', '2'], call, resolve: true);

      // The implementation currently filters by what it can find; expect only the found pair(s)
      expect(res, isNotEmpty);
      expect(res.length, equals(1));
      expect(res.first.$1, equals('1'));
      expect(res.first.$2, equals(1));
    });

    test('posCompute (sync) receives success and can transform the list',
        () async {
      final cache = ComputeOnceCachedIDs<String, int>();

      Future<List<int>> call(List<String> ids) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return ids.map((e) => int.parse(e)).toList();
      }

      FutureOr<List<int>> pos(List<int>? value, Object? error, StackTrace? s) {
        // add 1000 to each element to signal transformation
        return value!.map((v) => v + 1000).toList();
      }

      final res = await cache
          .computeIDs(['3', '4'], call, posCompute: pos, resolve: true);

      expect(res.map((p) => p.$2).toList(), equals([1003, 1004]));
    });

    test('posCompute invoked on error can return fallback values', () async {
      final cache = ComputeOnceCachedIDs<String, int>();

      Future<List<int>> call(List<String> ids) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        throw StateError('failed');
      }

      FutureOr<List<int>> pos(List<int>? value, Object? error, StackTrace? s) {
        // return a fallback list with -1 per requested id
        return List<int>.filled(2, -1);
      }

      final res = await cache
          .computeIDs(['x', 'y'], call, posCompute: pos, resolve: true);

      expect(res.map((p) => p.$2).toList(), equals([-1, -1]));
    });

    test('custom comparator: sharing occurs across case variants', () async {
      int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

      final cache = ComputeOnceCachedIDs<String, int>(compare: cmp);

      var calls = 0;
      Future<List<int>> call(List<String> ids) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return ids.map((e) => e.length).toList();
      }

      final p1 = cache.computeIDs(['Ab', 'Cd'], call, resolve: true);
      await Future<void>.delayed(const Duration(milliseconds: 3));
      final p2 = cache.computeIDs(['ab', 'cD'], call, resolve: true);

      final r1 = await p1;
      final r2 = await p2;

      // Only one underlying call because comparator treats variants equal
      expect(calls, equals(1));
      expect(r1.map((p) => p.$2).toList(), equals([2, 2]));
      expect(r2.map((p) => p.$2).toList(), equals([2, 2]));
    });
  });

  group('ComputeIDs behavior', () {
    test('ComputeIDs constructor sorts and deduplicate', () {
      final ids = ComputeIDs<int>([3, 1, 2, 1]);

      expect(ids.ids, equals([1, 2, 3]));
      expect(ids.length, equals(3));
    });

    test('equalsIDs compares element-by-element; unsorted input differs', () {
      final ids = ComputeIDs<int>([1, 2, 3]);

      // equalsIDs expects same order; provide unsorted list to show it's false
      expect(ids.equalsIDs([3, 2, 1]), isFalse);

      // exact same order -> true
      expect(ids.equalsIDs([1, 2, 3]), isTrue);
    });
  });

  group('ComputeOnce error handling and onErrorValue casting', () {
    test(
        'resolve with synchronous thrown error and onErrorValue null throws StateError',
        () {
      final c = ComputeOnce<int>(() {
        throw StateError('boom');
      }, resolve: false);

      // throwError == false and onErrorValue == null should trigger _castErrorValue
      expect(
        () => c.resolve(throwError: false, onErrorValue: null),
        throwsA(isA<StateError>()),
      );
    });

    test('resolve catches async error and uses onError fallback', () async {
      final c = ComputeOnce<int>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        throw ArgumentError('async fail');
      }, resolve: false);

      final res = await c.resolve(
        throwError: false,
        onError: (e, s) {
          // convert any error to 1234
          return 1234;
        },
      );

      expect(res, equals(1234));
      expect(c.isResolved, isTrue);
    });
  });

  group('MapComputeIDsExtension (computeAll / computeAllAsync)', () {
    test('computeAll resolves synchronous TimedComputeOnce values', () async {
      // Build a map with two keys and synchronous TimedComputeOnce values.
      final k1 = ComputeIDs<int>([1]);
      final k2 = ComputeIDs<int>([2]);

      final m = <ComputeIDs<int>, TimedComputeOnce<int>>{
        k1: TimedComputeOnce<int>(() => 10, resolve: false),
        k2: TimedComputeOnce<int>(() => 20, resolve: false),
      };

      final res = await m.computeAll(); // may return FutureOr<Map<...>>
      expect(res[k1], equals(10));
      expect(res[k2], equals(20));
    });

    test('computeAllAsync resolves asynchronous TimedComputeOnce values',
        () async {
      final k1 = ComputeIDs<String>(['a']);
      final k2 = ComputeIDs<String>(['b']);

      final m = <ComputeIDs<String>, TimedComputeOnce<int>>{
        k1: TimedComputeOnce<int>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return 5;
        }, resolve: false),
        k2: TimedComputeOnce<int>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return 6;
        }, resolve: false),
      };

      final res = await m.computeAllAsync();
      expect(res[k1], equals(5));
      expect(res[k2], equals(6));
    });
  });

  group('ListIdValuePairExtension binary search helpers', () {
    test('binarySearchIndex finds index in list of (id, value) pairs', () {
      final list = <(int, String)>[
        (1, 'a'),
        (3, 'c'),
        (5, 'e'),
        (7, 'g'),
      ];

      final idx = list.binarySearchIndex(5);
      expect(idx, equals(2));
    });

    test('binarySearch returns pair when present and null when absent', () {
      final list = <(int, String)>[
        (2, 'b'),
        (4, 'd'),
        (6, 'f'),
      ];

      final found = list.binarySearch(4);
      expect(found, isNotNull);
      expect(found!.$1, equals(4));
      expect(found.$2, equals('d'));

      final missing = list.binarySearch(3);
      expect(missing, isNull);
    });
  });

  group('ComputeIDs hashing and equals', () {
    test('custom hash function affects hashCode deterministically', () {
      int hashFn(int x) => x * 31;
      final a = ComputeIDs<int>([1, 2, 3], hash: hashFn);
      final b = ComputeIDs<int>([1, 2, 3], hash: hashFn);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different order or different elements produce different equality',
        () {
      final a = ComputeIDs<int>([1, 2, 3]);
      final b = ComputeIDs<int>(
          [3, 2, 1]); // constructor sorts; equal only if same order after sort
      // After construction both are sorted to [1,2,3] -> they are equal
      expect(a, equals(b));
      // However equalsIDs with unsorted external list differs
      expect(a.equalsIDs([3, 2, 1]), isFalse);
    });
  });
}

class _MyComputeOnce<V> extends ComputeOnce<V> {
  _MyComputeOnce(super.call, {super.resolve});

  (V?, Object?, StackTrace?)? onComputeArgs;

  @override
  void onCompute(V? value, Object? error, StackTrace? stackTrace) {
    onComputeArgs = (value, error, stackTrace);
  }
}

import 'package:async_extension/async_extension.dart';
import 'package:test/test.dart';

class _NotComparable {
  final int id;

  _NotComparable(this.id);
}

void main() {
  group('FutureOrFunctionArgs*Extension (Future of a function)', () {
    test('Args0: tryCall / tryCallThen', () async {
      FutureOr<FutureOr<int> Function()> f = Future.value(() => 10);

      expect(f, isA<Future>());
      expect(await f.tryCall(onError: (e, s) => -1), equals(10));
      expect(
        await f.tryCallThen((v) => v * 2, onError: (e, s) => -1),
        equals(20),
      );

      FutureOr<FutureOr<int> Function()> fErr = Future.value(
        () => throw StateError('boom'),
      );

      expect(await fErr.tryCall(onError: (e, s) => -1), equals(-1));
      expect(
        await fErr.tryCallThen((v) => v * 2, onError: (e, s) => -2),
        equals(-2),
      );
    });

    test('Args0: Future of a function that fails asynchronously', () async {
      FutureOr<FutureOr<int> Function()> f = Future.value(
        () => Future<int>.error(StateError('async boom')),
      );

      expect(await f.tryCall(onError: (e, s) => -1), equals(-1));
      expect(
        await f.tryCallThen((v) => v * 2, onError: (e, s) => -2),
        equals(-2),
      );
    });

    test('Args1: tryCall / tryCallThen', () async {
      FutureOr<FutureOr<int> Function(int)> f = Future.value((int a) => a * 10);

      expect(await f.tryCall(3, onError: (e, s) => -1), equals(30));
      expect(
        await f.tryCallThen(3, (v) => v + 1, onError: (e, s) => -1),
        equals(31),
      );

      FutureOr<FutureOr<int> Function(int)> fErr = Future.value(
        (int a) => throw StateError('boom $a'),
      );

      expect(await fErr.tryCall(3, onError: (e, s) => -1), equals(-1));
      expect(
        await fErr.tryCallThen(3, (v) => v + 1, onError: (e, s) => -2),
        equals(-2),
      );
    });

    test('Args2: tryCall / tryCallThen', () async {
      FutureOr<FutureOr<int> Function(int, int)> f = Future.value(
        (int a, int b) => a * b,
      );

      expect(await f.tryCall(3, 4, onError: (e, s) => -1), equals(12));
      expect(
        await f.tryCallThen(3, 4, (v) => v + 1, onError: (e, s) => -1),
        equals(13),
      );

      FutureOr<FutureOr<int> Function(int, int)> fErr = Future.value(
        (int a, int b) => throw StateError('boom $a $b'),
      );

      expect(await fErr.tryCall(3, 4, onError: (e, s) => -1), equals(-1));
      expect(
        await fErr.tryCallThen(3, 4, (v) => v + 1, onError: (e, s) => -2),
        equals(-2),
      );
    });
  });

  group('FunctionArgs*Extension without onError', () {
    test('Args1: tryCall / tryCallThen (sync and async)', () async {
      int f1(int a) => a * 10;
      Future<int> f1Async(int a) async => a * 10;

      expect(f1.tryCall(2), equals(20));
      expect(f1.tryCallThen(2, (v) => v + 1), equals(21));

      var r1 = f1Async.tryCall(2);
      expect(r1, isA<Future<int>>());
      expect(await r1, equals(20));

      var r2 = f1Async.tryCallThen(2, (v) => v + 1);
      expect(r2, isA<Future<int>>());
      expect(await r2, equals(21));
    });

    test('Args1: errors propagate when onError is absent', () async {
      int fErr(int a) => throw StateError('boom $a');
      Future<int> fErrAsync(int a) async => throw StateError('boom $a');

      expect(() => fErr.tryCall(1), throwsStateError);
      expect(() => fErr.tryCallThen(1, (v) => v), throwsStateError);
      expect(fErrAsync.tryCallThen(1, (v) => v), throwsStateError);
    });

    test('Args2: tryCall / tryCallThen (sync and async)', () async {
      int f2(int a, int b) => a + b;
      Future<int> f2Async(int a, int b) async => a + b;

      expect(f2.tryCall(2, 3), equals(5));
      expect(f2.tryCallThen(2, 3, (v) => v * 2), equals(10));

      var r1 = f2Async.tryCall(2, 3);
      expect(r1, isA<Future<int>>());
      expect(await r1, equals(5));

      var r2 = f2Async.tryCallThen(2, 3, (v) => v * 2);
      expect(r2, isA<Future<int>>());
      expect(await r2, equals(10));
    });

    test('Args2: errors propagate when onError is absent', () async {
      int fErr(int a, int b) => throw StateError('boom');
      Future<int> fErrAsync(int a, int b) async => throw StateError('boom');

      expect(() => fErr.tryCall(1, 2), throwsStateError);
      expect(() => fErr.tryCallThen(1, 2, (v) => v), throwsStateError);
      expect(fErrAsync.tryCallThen(1, 2, (v) => v), throwsStateError);
    });
  });

  group('IterableMapEntryFutureExtension', () {
    test(
      'resolveAllEntries returns the same instance when nothing is async',
      () {
        var entries = <MapEntry<String, int>>[
          MapEntry('a', 1),
          MapEntry('b', 2),
        ];

        var resolved = IterableMapEntryFutureExtension<String, int>(entries)
            .resolveAllEntries();

        expect(identical(resolved, entries), isTrue);
      },
    );
  });

  group('ComputeOnce posCompute edge cases', () {
    test('sync call + throwing posCompute caches the error', () async {
      var posCalls = 0;
      var c = ComputeOnce<int>(
        () => 10,
        posCompute: (v, e, s) {
          posCalls++;
          throw StateError('pos failed');
        },
        resolve: false,
      );

      expect(() => c.resolve(), throwsStateError);
      expect(c.isResolved, isTrue);
      expect(c.hasError, isTrue);
      expect(c.error?.error, isA<StateError>());
      expect(posCalls, equals(1));

      // Cached error, posCompute not invoked again:
      expect(c.resolve(throwError: false, onErrorValue: -1), equals(-1));
      expect(c.resolve(throwError: false, onError: (e, s) => -2), equals(-2));
      expect(posCalls, equals(1));
    });

    test('sync call + throwing posCompute with throwError: false', () {
      var c = ComputeOnce<int>(
        () => 10,
        posCompute: (v, e, s) => throw StateError('pos failed'),
        resolve: false,
      );

      expect(c.resolve(throwError: false, onErrorValue: -1), equals(-1));
      expect(c.hasError, isTrue);
    });

    test('async error in resolve() is passed to posCompute', () async {
      Object? posError;
      var c = ComputeOnce<int>(
        () => Future<int>.error(StateError('async boom')),
        posCompute: (v, e, s) {
          posError = e;
          // Recover from the error:
          return -100;
        },
        resolve: false,
      );

      var r = c.resolve();
      expect(r, isA<Future<int>>());
      expect(await r, equals(-100));
      expect(posError, isA<StateError>());
      expect(c.value, equals(-100));
      expect(c.hasError, isFalse);
    });

    test('async error in resolve() rethrown by posCompute', () async {
      var c = ComputeOnce<int>(
        () => Future<int>.error(StateError('async boom')),
        posCompute: (v, e, s) => Error.throwWithStackTrace(e!, s!),
        resolve: false,
      );

      await expectLater(c.resolve(), throwsStateError);
      expect(c.hasError, isTrue);
    });
  });

  group('TimedComputeOnce', () {
    test('className and toString', () async {
      var c = TimedComputeOnce<int>(() => 7, resolve: false);
      expect(c.className, equals('TimedComputeOnce'));
      expect(c.toString(), startsWith('TimedComputeOnce<int>@'));
      expect(c.elapsedTime(), equals(Duration.zero));

      expect(c.resolve(), equals(7));
      expect(c.toString(), equals('TimedComputeOnce<int><7>'));
      expect(c.resolvedAt, isNotNull);
      expect(
        c.elapsedTime(c.resolvedAt!.add(Duration(seconds: 2))),
        equals(Duration(seconds: 2)),
      );
    });
  });

  group('ComputeOnceCache remove / clear', () {
    test('remove returns the entry and allows recomputation', () async {
      var cache = ComputeOnceCache<String, int>(
        retentionDuration: Duration(minutes: 1),
      );
      var calls = 0;

      var c1 = cache.get('a', () => ++calls);
      expect(await c1.resolveAsync(), equals(1));
      expect(cache.callsLength, equals(1));

      // Retained:
      expect(identical(cache.get('a', () => ++calls), c1), isTrue);

      expect(identical(cache.remove('a'), c1), isTrue);
      expect(cache.callsLength, equals(0));
      expect(cache.remove('a'), isNull);

      var c2 = cache.get('a', () => ++calls);
      expect(identical(c2, c1), isFalse);
      expect(await c2.resolveAsync(), equals(2));

      cache.clear();
    });

    test('clear removes all entries and cancels retention timers', () async {
      var cache = ComputeOnceCache<int, String>(
        retentionDuration: Duration(minutes: 1),
      );

      await cache.get(1, () => 'one').resolveAsync();
      await cache.get(2, () => 'two').resolveAsync();
      expect(cache.callsLength, equals(2));
      expect(cache.calls().keys, unorderedEquals([1, 2]));

      cache.clear();
      expect(cache.callsLength, equals(0));
      expect(cache.calls(), isEmpty);

      // A fresh computation is created after clear:
      var calls = 0;
      expect(
        await cache.get(1, () => 'one-${++calls}').resolveAsync(),
        equals('one-1'),
      );
      cache.clear();
    });
  });

  group('ComputeIDs comparators', () {
    test('double IDs use the double comparator', () {
      var ids = ComputeIDs<double>([3.5, 1.25, 2.75, 1.25]);
      expect(ids.ids, equals([1.25, 2.75, 3.5]));
      expect(ids.binarySearchIndex(2.75), equals(1));
      expect(ids.toString(), equals('ComputeIDs(3)[1.25, 2.75, 3.5]'));
    });

    test('num IDs use the num comparator', () {
      var ids = ComputeIDs<num>([3, 1.5, 2, 1.5]);
      expect(ids.ids, equals([1.5, 2, 3]));
      expect(ids.containsAny([2]), isTrue);
      expect(ids.containsAny([4]), isFalse);
    });

    test('non-Comparable IDs without comparator throw StateError', () {
      expect(
        () =>
            ComputeIDs<_NotComparable>([_NotComparable(2), _NotComparable(1)]),
        throwsStateError,
      );

      // A custom comparator makes them usable:
      var ids = ComputeIDs<_NotComparable>(
        [_NotComparable(2), _NotComparable(1)],
        compare: (a, b) => a.id.compareTo(b.id),
        hash: (e) => e.id,
      );
      expect(ids.ids.map((e) => e.id), equals([1, 2]));
      expect(
        ids.hashCode,
        equals(
          ComputeIDs<_NotComparable>(
            [_NotComparable(1), _NotComparable(2)],
            compare: (a, b) => a.id.compareTo(b.id),
            hash: (e) => e.id,
          ).hashCode,
        ),
      );
    });
  });

  group('asyncRetry with async tryBlock', () {
    test('retries async failures using the default delay', () async {
      var attempts = 0;
      var result = await asyncRetry<int>(() async {
        attempts++;
        if (attempts < 3) throw StateError('fail $attempts');
        return 42;
      });

      expect(result, equals(42));
      expect(attempts, equals(3));
    });

    test('returns defaultValue after async failures are exhausted', () async {
      var attempts = 0;
      var result = await asyncRetry<int>(
        () async {
          attempts++;
          throw StateError('fail $attempts');
        },
        maxRetries: 2,
        defaultValue: -1,
      );

      expect(result, equals(-1));
      expect(attempts, equals(3));
    });

    test('rethrows after async failures when throwOnRetryExhaustion', () async {
      var attempts = 0;
      await expectLater(
        asyncRetry<int>(
          () async {
            attempts++;
            throw StateError('fail $attempts');
          },
          maxRetries: 1,
          throwOnRetryExhaustion: true,
        ),
        throwsStateError,
      );
      expect(attempts, equals(2));
    });
  });
}

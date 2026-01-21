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
}

class _MyComputeOnce<V> extends ComputeOnce<V> {
  _MyComputeOnce(super.call, {super.resolve});

  (V?, Object?, StackTrace?)? onComputeArgs;

  @override
  void onCompute(V? value, Object? error, StackTrace? stackTrace) {
    onComputeArgs = (value, error, stackTrace);
  }
}

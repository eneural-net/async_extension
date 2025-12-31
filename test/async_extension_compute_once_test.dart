import 'package:test/test.dart';

import 'package:async_extension/async_extension.dart';

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
  });
}

import 'dart:async';

import 'package:async_extension/async_extension.dart';
import 'package:test/test.dart';

void main() {
  group('FutureOrExtension', () {
    setUp(() {});

    test('resolve', () async {
      expect(_futureOrMultiply(10, 2).resolve(), equals(20));
      expect(await _futureOrMultiply(10, 2).resolve(), equals(20));
      expect(await _futureOrMultiply(10, 2).asFuture, equals(20));

      expect(_futureOrMultiply(-10, 2).resolve() is Future<int>, isTrue);
      expect(await _futureOrMultiply(-10, 2).resolve(), equals(-20));
      expect(await _futureOrMultiply(-10, 2).asFuture, equals(-20));
    });

    test('resolve: validate', () async {
      expect(_futureOrMultiply(10, 2).resolve(validate: _validateEven),
          equals(20));
      expect(await _futureOrMultiply(10, 2).resolve(validate: _validateEven),
          equals(20));

      expect(
          _futureOrMultiply(-10, 2).resolve(validate: _validateEven) is Future,
          isTrue);
      expect(await _futureOrMultiply(-10, 2).resolve(validate: _validateEven),
          equals(-20));

      expect(
          _futureOrMultiply(11, 3)
              .resolve(validate: _validateEven, defaultValue: 0),
          equals(0));
      expect(
          await _futureOrMultiply(11, 3)
              .resolve(validate: _validateEven, defaultValue: 0),
          equals(0));

      expect(
          _futureOrMultiply(-11, 3)
              .resolve(validate: _validateEven, defaultValue: 0) is Future<int>,
          isTrue);
      expect(
          await _futureOrMultiply(-11, 3)
              .resolve(validate: _validateEven, defaultValue: 0),
          equals(0));
    });

    test('resolveMapped', () async {
      expect(
          _futureOrMultiply(10, 2).resolveMapped((n) => n * 10), equals(200));
      expect(await _futureOrMultiply(10, 2).resolveMapped((n) => n * 10),
          equals(200));
      expect(
          await _futureOrMultiply(10, 2).resolveMapped((n) => n * 10).asFuture,
          equals(200));

      expect(
          await _futureOrMultiply(10, 2)
              .resolveMapped((n) => n * 10,
                  validate: _validateEven, defaultValue: -1)
              .asFuture,
          equals(200));

      expect(
          _futureOrMultiply(-10, 2).resolveMapped((n) => n * 10) is Future<int>,
          isTrue);
      expect(await _futureOrMultiply(-10, 2).resolveMapped((n) => n * 10),
          equals(-200));
      expect(
          await _futureOrMultiply(-10, 2).resolveMapped((n) => n * 10).asFuture,
          equals(-200));

      expect(
          await _futureOrMultiply(-10, 2)
              .resolveMapped((n) => n * 10,
                  validate: _validateEven, defaultValue: -1)
              .asFuture,
          equals(-200));
    });

    test('resolveWith', () async {
      expect(_futureOrMultiply(10, 2).resolveWith(() => 1000), equals(1000));
      expect(
          await _futureOrMultiply(10, 2).resolveWith(() => 1000), equals(1000));
      expect(await _futureOrMultiply(10, 2).resolveWith(() => 1000).asFuture,
          equals(1000));

      expect(
          await _futureOrMultiply(10, 2)
              .resolveWith(() => 1000, validate: _validateEven, defaultValue: 0)
              .asFuture,
          equals(1000));

      expect(_futureOrMultiply(-10, 2).resolveWith(() => -1000) is Future<int>,
          isTrue);
      expect(await _futureOrMultiply(-10, 2).resolveWith(() => -1000),
          equals(-1000));
      expect(await _futureOrMultiply(-10, 2).resolveWith(() => -1000).asFuture,
          equals(-1000));

      expect(
          await _futureOrMultiply(-10, 2)
              .resolveWith(() => -1000,
                  validate: _validateEven, defaultValue: 0)
              .asFuture,
          equals(-1000));
    });

    test('isResolved', () async {
      expect(_futureOrMultiply(10, 2).isResolved, isTrue);
      expect(_futureOrMultiply(-10, 2).isResolved, isFalse);
    });

    test('type', () async {
      expect(_futureOrMultiply(10, 2).type, equals(int));
      expect(_futureOrMultiply(-10, 2).type, equals(int));
    });

    test('type', () async {
      expect(_futureOrMultiply(10, 2).validate(_validateEven, defaultValue: 0),
          equals(20));

      expect(
          _futureOrMultiply(-10, 2).validate(_validateEven, defaultValue: 0)
              is Future<int?>,
          isTrue);
      expect(
          await _futureOrMultiply(-10, 2)
              .validate(_validateEven, defaultValue: 0),
          equals(-20));

      expect(_futureOrMultiply(11, 3).validate(_validateEven, defaultValue: 0),
          equals(0));
      expect(
          await _futureOrMultiply(-11, 3)
              .validate(_validateEven, defaultValue: 0),
          equals(0));
    });

    test('onResolve', () async {
      var onResolve1 = <int>[];
      _futureOrMultiply(10, 2).onResolve((r) => onResolve1.add(123));
      expect(onResolve1, equals([123]));

      var onResolve2 = <int>[];
      var ret =
          _futureOrMultiply(-10, 2).onResolve((r) => onResolve2.add(-123));
      expect(onResolve2, isEmpty);
      await ret;
      expect(onResolve2, equals([-123]));
    });
  });

  group('IterableFutureOrExtension', () {
    setUp(() {});

    test('All Resolved', () async {
      var l = [_futureOrMultiply(10, 2), _futureOrMultiply(20, 2)];

      expect(l.isAllResolved, isTrue);
      expect(l.isAllFuture, isFalse);

      expect(l.selectResolved(), equals([20, 40]));
      expect(l.selectFutures(), isEmpty);

      expect(l.asFutures.length, equals(2));
      expect(l.resolveAll(), equals([20, 40]));
      expect(l.waitFutures(), equals([]));
      expect(await l.asFutures.resolveAll(), equals([20, 40]));
      expect(await l.asFutures.waitFutures(), equals([20, 40]));

      expect(l.resolveAllMapped((v) => v * 10), equals([200, 400]));

      expect(l.resolveAllValidated(_validateEven, defaultValue: 0),
          equals([20, 40]));

      expect(l.resolveAllJoined((l) => l.join()), equals('2040'));

      expect(l.resolveAllReduced((a, b) => a + b), equals(60));

      var l2 = [_futureOrMultiply(10, 3), _futureOrMultiply(21, 3)];

      expect(l2.resolveAllJoined((l) => l.join()), equals('3063'));

      expect(l2.resolveAllValidated(_validateEven, defaultValue: 0).isResolved,
          isTrue);
      expect(l2.resolveAllValidated(_validateEven, defaultValue: 0),
          equals([30, 0]));

      expect(l2.resolveAllReduced((a, b) => a + b), equals(93));
    });

    test('Not All Resolved ; Not All Future', () async {
      var l = [_futureOrMultiply(10, 2), _futureOrMultiply(-20, 2)];

      expect(l.isAllResolved, isFalse);
      expect(l.isAllFuture, isFalse);

      expect(l.selectResolved(), equals([20]));
      expect(l.selectFutures().length, equals(1));

      expect(l.asFutures.length, equals(2));
      expect(l.resolveAll().isResolved, isFalse);
      expect(await l.waitFutures(), equals([-40]));
      expect(await l.asFutures.resolveAll(), equals([20, -40]));
      expect(await l.asFutures.waitFutures(), equals([20, -40]));

      expect(l.resolveAllMapped((v) => v * 10).isResolved, isFalse);
      expect(await l.resolveAllMapped((v) => v * 10), equals([200, -400]));

      expect(l.resolveAllValidated(_validateEven, defaultValue: 0).isResolved,
          isFalse);
      expect(await l.resolveAllValidated(_validateEven, defaultValue: 0),
          equals([20, -40]));

      expect(await l.resolveAllJoined((l) => l.join()), equals('20-40'));

      expect(await l.resolveAllReduced((a, b) => a + b), equals(-20));

      var l2 = [_futureOrMultiply(10, 3), _futureOrMultiply(-21, 3)];

      expect(l2.resolveAllValidated(_validateEven, defaultValue: 0).isResolved,
          isFalse);
      expect(await l2.resolveAllValidated(_validateEven, defaultValue: 0),
          equals([30, 0]));
      expect(
          await l2.asFutures
              .resolveAllValidated(_validateEven, defaultValue: 0),
          equals([30, 0]));

      expect(await l2.resolveAllJoined((l) => l.join()), equals('30-63'));
      expect(await l2.asFutures.resolveAllJoined((l) => l.join()),
          equals('30-63'));

      expect(await l2.resolveAllReduced((a, b) => a + b), equals(-33));
      expect(
          await l2.asFutures.resolveAllReduced((a, b) => a + b), equals(-33));
    });

    test('All Future', () async {
      var l = [_futureOrMultiply(-10, 2), _futureOrMultiply(-20, 2)];

      expect(l.isAllResolved, isFalse);
      expect(l.isAllFuture, isTrue);

      expect(l.selectResolved().isEmpty, isTrue);
      expect(l.selectFutures().length, equals(2));

      expect(await l.selectFutures().waitFutures(), equals([-20, -40]));

      expect(l.selectFutures().resolveAll() is Future<List<int>>, isTrue);
      expect(await l.selectFutures().resolveAll(), equals([-20, -40]));

      expect(l.asFutures.length, equals(2));
      expect(l.resolveAll().isResolved, isFalse);
      expect(await l.asFutures.resolveAll(), equals([-20, -40]));

      expect(await l.asFutures.resolveAllMapped((v) => v * 10),
          equals([-200, -400]));

      expect(await l.asFutures.resolveAllJoined((l) => l.join()),
          equals('-20-40'));

      expect(await l.asFutures.resolveAllReduced((a, b) => a + b), equals(-60));

      expect(await l.waitFuturesAndReturnValue(-123), equals(-123));

      expect([].waitFuturesAndReturnValue(-1), equals(-1));

      expect(await [].asFutures.resolveAll(), equals([]));

      expect(await [].asFutures.resolveAllMapped((e) => e * 10), equals([]));

      expect(await [].asFutures.resolveAllValidated(_validateEven), equals([]));

      expect(await [].asFutures.resolveAllJoined((l) => l.join()), equals(''));

      expect(await [].asFutures.waitFutures(), equals([]));

      expect(await l.asFutures.waitFuturesAndReturnValue(-123), equals(-123));

      expect(await [].asFutures.waitFuturesAndReturnValue(-1), equals(-1));

      StateError? noElementError;
      try {
        expect(
            await [].asFutures.resolveAllReduced((a, b) => a + b), equals(-60));
      } catch (e) {
        noElementError = e as StateError;
      }
      expect(noElementError, isNotNull);
    });
  });
}

/// Multiply [a] * [b], and returns `int` for positive [a] and
/// a [Future] for negative [a].
FutureOr<int> _futureOrMultiply(int a, int b) {
  if (a > 0) {
    return a * b;
  } else {
    return Future.value(a * b);
  }
}

bool _validateEven(dynamic v) {
  return v is int && v % 2 == 0;
}

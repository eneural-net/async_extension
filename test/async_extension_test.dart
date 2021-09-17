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
      expect(await _futureOrMultiply(10, 2).resolveWithValue(123), equals(123));

      expect(
          await _futureOrMultiply(10, -2).resolveWithValue(123), equals(123));

      expect(
          await _futureOrMultiply(-10, -2).resolveWithValue(123), equals(123));
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
          _futureOrMultiply(-10, 2).resolveMapped((n) => n * 10) is Future<int>,
          isTrue);
      expect(await _futureOrMultiply(-10, 2).resolveMapped((n) => n * 10),
          equals(-200));
      expect(
          await _futureOrMultiply(-10, 2).resolveMapped((n) => n * 10).asFuture,
          equals(-200));
    });

    test('then', () async {
      expect(_futureOrMultiply(10, 2).then((n) => n * 10), equals(200));
      expect(await _futureOrMultiply(10, 2).then((n) => n * 10), equals(200));
      expect(await _futureOrMultiply(10, 2).then((n) => n * 10).asFuture,
          equals(200));

      expect(
          _futureOrMultiply(-10, 2).then((n) => n * 10) is Future<int>, isTrue);
      expect(await _futureOrMultiply(-10, 2).then((n) => n * 10), equals(-200));
      expect(await _futureOrMultiply(-10, 2).then((n) => n * 10).asFuture,
          equals(-200));
    });

    test('then error', () async {
      expect(() {
        return _futureOrMultiply(10, 2, true).then((n) => n * 10);
      }, throwsStateError);

      expect(() {
        return _futureOrMultiply(-10, 2, true).then((n) => n * 10);
      }, throwsStateError);
    });

    test('resolveWith', () async {
      expect(_futureOrMultiply(10, 2).resolveWith(() => 1000), equals(1000));
      expect(
          await _futureOrMultiply(10, 2).resolveWith(() => 1000), equals(1000));
      expect(await _futureOrMultiply(10, 2).resolveWith(() => 1000).asFuture,
          equals(1000));

      expect(_futureOrMultiply(-10, 2).resolveWith(() => -1000) is Future<int>,
          isTrue);
      expect(await _futureOrMultiply(-10, 2).resolveWith(() => -1000),
          equals(-1000));
      expect(await _futureOrMultiply(-10, 2).resolveWith(() => -1000).asFuture,
          equals(-1000));
    });

    test('resolveBoth', () async {
      expect(
          await _futureOrMultiply(10, 2)
              .resolveBoth(_futureOrMultiply(20, 2), (v1, v2) => v1 + v2),
          equals(60));

      expect(
          await _futureOrMultiply(10, 2)
              .resolveBoth(_futureOrMultiply(-20, 2), (v1, v2) => v1 + v2),
          equals(-20));

      expect(
          await _futureOrMultiply(-10, 2)
              .resolveBoth(_futureOrMultiply(20, 2), (v1, v2) => v1 + v2),
          equals(20));

      expect(
          await _futureOrMultiply(-10, 2)
              .resolveBoth(_futureOrMultiply(-20, 2), (v1, v2) => v1 + v2),
          equals(-60));
    });

    test('AsyncLoop 1', () async {
      var countInt = <int>[0];
      var countFuture = <int>[0];

      var asyncLoop = AsyncLoop<int>(1, (i) => i <= 10, (i) => i + 1, (i) {
        var ret = _futureOrMultiply(i % 2 == 0 ? i : -i, 2);
        if (ret is Future) {
          countFuture[0]++;
        } else {
          countInt[0]++;
        }
        print('$i> $ret');
        return ret.resolveMapped((v) => i < 5);
      });

      expect(await asyncLoop.run(), equals(5));

      expect(countInt[0], equals(2));
      expect(countFuture[0], equals(3));
    });

    test('AsyncLoop 2', () async {
      var countInt = <int>[0];
      var countFuture = <int>[0];

      var asyncLoop = AsyncLoop<int>(1, (i) => i <= 10, (i) => i + 1, (i) {
        var ret = _futureOrMultiply(i % 2 == 0 ? i : -i, 2);
        if (ret is Future) {
          countFuture[0]++;
        } else {
          countInt[0]++;
        }
        print('$i> $ret');
        return ret.resolveMapped((v) => i < 6);
      });

      expect(await asyncLoop.run(), equals(6));

      expect(countInt[0], equals(3));
      expect(countFuture[0], equals(3));
    });

    test('AsyncSequenceLoop 1', () async {
      var countInt = <int>[0];
      var countFuture = <int>[0];

      var asyncLoop = AsyncSequenceLoop(1, 11, (i) {
        var ret = _futureOrMultiply(i % 2 == 0 ? i : -i, 2);
        if (ret is Future) {
          countFuture[0]++;
        } else {
          countInt[0]++;
        }
        print('$i> $ret');
        return ret.resolveMapped((v) => i < 5);
      });

      expect(await asyncLoop.run(), equals(5));

      expect(countInt[0], equals(2));
      expect(countFuture[0], equals(3));
    });

    test('AsyncSequenceLoop 2', () async {
      var countInt = <int>[0];
      var countFuture = <int>[0];

      var asyncLoop = AsyncSequenceLoop(1, 11, (i) {
        var ret = _futureOrMultiply(i % 2 == 0 ? i : -i, 2);
        if (ret is Future) {
          countFuture[0]++;
        } else {
          countInt[0]++;
        }
        print('$i> $ret');
        return ret.resolveMapped((v) => i < 6);
      });

      expect(await asyncLoop.run(), equals(6));

      expect(countInt[0], equals(3));
      expect(countFuture[0], equals(3));
    });

    test('FutureOr operators +,-,*,/,~/ int', () async {
      expect(await (_futureOrMultiply(10, 2) + _futureOrMultiply(20, 2)),
          equals(60));

      expect(await (_futureOrMultiply(10, 2) - _futureOrMultiply(20, 2)),
          equals(-20));

      expect(await (_futureOrMultiply(10, 2) * _futureOrMultiply(20, 2)),
          equals(800));

      expect(await (_futureOrMultiply(10, 2) / _futureOrMultiply(20, 2)),
          equals(0.5));

      expect(await (_futureOrMultiply(20, 2) ~/ _futureOrMultiply(10, 2)),
          equals(2));
    });

    test('FutureOr operators +,-,*,/,~/ double', () async {
      expect(
          await (_futureOrMultiply(10.0, 2.0) + _futureOrMultiply(20.0, 2.0)),
          equals(60));

      expect(
          await (_futureOrMultiply(10.0, 2.0) - _futureOrMultiply(20.0, 2.0)),
          equals(-20));

      expect(
          await (_futureOrMultiply(10.0, 2.0) * _futureOrMultiply(20.0, 2.0)),
          equals(800));

      expect(
          await (_futureOrMultiply(10.0, 2.0) / _futureOrMultiply(20.0, 2.0)),
          equals(0.5));

      expect(
          await (_futureOrMultiply(20.0, 2.0) ~/ _futureOrMultiply(10.0, 2.0)),
          equals(2));
    });

    test('FutureOr operators +,-,*,/,~/ num', () async {
      expect(await (_futureOrMultiply(10.0, 2) + _futureOrMultiply(20, 2)),
          equals(60));

      expect(await (_futureOrMultiply(10.0, 2) - _futureOrMultiply(20, 2)),
          equals(-20));

      expect(await (_futureOrMultiply(10.0, 2) * _futureOrMultiply(20, 2)),
          equals(800));

      expect(await (_futureOrMultiply(10.0, 2) / _futureOrMultiply(20, 2)),
          equals(0.5));

      expect(await (_futureOrMultiply(20.0, 2) ~/ _futureOrMultiply(10, 2)),
          equals(2));
    });

    test('Future operators +,-,*,/,~/ int', () async {
      expect(await (Future.value(10) + Future.value(20)), equals(30));

      expect(await (Future.value(20) - Future.value(10)), equals(10));

      expect(await (Future.value(20) * Future.value(10)), equals(200));

      expect(await (Future.value(10) / Future.value(20)), equals(0.5));

      expect(await (Future.value(20) ~/ Future.value(10)), equals(2));
    });

    test('Future operators +,-,*,/,~/ double', () async {
      expect(await (Future.value(10.0) + Future.value(20.0)), equals(30));

      expect(await (Future.value(20.0) - Future.value(10.0)), equals(10));

      expect(await (Future.value(20.0) * Future.value(10.0)), equals(200));

      expect(await (Future.value(10.0) / Future.value(20.0)), equals(0.5));

      expect(await (Future.value(20.0) ~/ Future.value(10.0)), equals(2));
    });

    test('Future operators +,-,*,/,~/ num', () async {
      expect(
          await (Future<num>.value(10.0) + Future<num>.value(20)), equals(30));

      expect(
          await (Future<num>.value(20.0) - Future<num>.value(10)), equals(10));

      expect(await (Future<num>.value(20.0) * Future<num>.value(10.0)),
          equals(200));

      expect(await (Future<num>.value(10.0) / Future<num>.value(20.0)),
          equals(0.5));

      expect(await (Future<num>.value(20.0) ~/ Future<num>.value(10.0)),
          equals(2));
    });

    test('Future + FutureOr operators +,-,*,/,~/ num', () async {
      expect(await (Future<num>.value(10.0) + 20), equals(30));

      expect(await (Future<num>.value(20.0) - 10), equals(10));

      expect(await (Future<num>.value(20.0) * 10.0), equals(200));

      expect(await (Future<num>.value(10.0) / 20.0), equals(0.5));

      expect(await (Future<num>.value(20.0) ~/ 10.0), equals(2));
    });

    test('FutureOr + Future operators +,-,*,/,~/ num', () async {
      // ignore: unnecessary_cast
      expect(await ((20 as FutureOr<int>) + Future<int>.value(10)), equals(30));

      // ignore: unnecessary_cast
      expect(await ((20 as FutureOr<int>) - Future<int>.value(10)), equals(10));

      expect(
          // ignore: unnecessary_cast
          await ((20 as FutureOr<int>) * Future<int>.value(10)),
          equals(200));

      // ignore: unnecessary_cast
      expect(await ((20 as FutureOr<int>) / Future<int>.value(10)), equals(2));

      // ignore: unnecessary_cast
      expect(await ((20 as FutureOr<int>) ~/ Future<int>.value(10)), equals(2));
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

  group('FutureExtension', () {
    setUp(() {});

    test('All Resolved', () async {
      expect(Future.value(123).type, equals(int));

      expect(
          await Future.value(110)
              .resolveBoth(Future.value(220), (v1, v2) => v1 + v2),
          equals(330));

      expect(await Future.value(110).resolveBoth(220, (v1, v2) => v1 + v2),
          equals(330));
    });
  });

  group('IterableFutureOrExtension', () {
    setUp(() {});

    test('All Resolved', () async {
      var l = [_futureOrMultiply(10, 2), _futureOrMultiply(20, 2)];

      expect(l.isAllResolved, isTrue);
      expect(l.isAllFuture, isFalse);

      expect(l.allAsList, equals([20, 40]));
      expect(l.map((e) => e).allAsList, equals([20, 40]));

      expect(l.resolveAll(), equals([20, 40]));
      expect(l.map((e) => e).resolveAll(), equals([20, 40]));
      expect(l.toList().resolveAll(), equals([20, 40]));
      expect(l.toList().map((e) => e).resolveAll(), equals([20, 40]));

      expect(l.resolveAll() as List<int>, equals([20, 40]));
      expect((l.resolveAll() as List<int>).map((e) => e).resolveAll(),
          equals([20, 40]));

      expect(l.resolveAllWith(() => 123), equals(123));
      expect(
          (l.resolveAll() as List<int>).resolveAllWith(() => 123), equals(123));

      expect(l.resolveAllWithValue(456), equals(456));
      expect(
          (l.resolveAll() as List<int>).resolveAllWithValue(456), equals(456));

      expect(l.resolveAllMapped((value) => value * 10), equals([200, 400]));
      expect(
          (l.resolveAll() as List<int>).resolveAllMapped((value) => value * 10),
          equals([200, 400]));

      expect(l.resolveAllThen((value) => value.reduce((v, e) => v * e)),
          equals(800));

      expect(l.resolveAllValidated((v) => v > 30, defaultValue: 101),
          equals([101, 40]));

      expect(
          (l.resolveAll() as List<int>)
              .resolveAllValidated((v) => v > 30, defaultValue: 101),
          equals([101, 40]));

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

      expect((l2.resolveAll() as List<int>).resolveAllJoined((l) => l.join()),
          equals('3063'));

      expect(l2.resolveAllValidated(_validateEven, defaultValue: 0).isResolved,
          isTrue);
      expect(l2.resolveAllValidated(_validateEven, defaultValue: 0),
          equals([30, 0]));

      expect(l2.resolveAllReduced((a, b) => a + b), equals(93));

      expect((l2.resolveAll() as List<int>).resolveAllReduced((a, b) => a + b),
          equals(93));
    });

    test('Not All Resolved ; Not All Future', () async {
      var l = [_futureOrMultiply(10, 2), _futureOrMultiply(-20, 2)];

      expect(l.isAllResolved, isFalse);
      expect(l.isAllFuture, isFalse);

      expect(l.allAsList.map((e) => e is num ? e : 'future'),
          equals([20, 'future']));
      expect(l.map((e) => e).allAsList.map((e) => e is num ? e : 'future'),
          equals([20, 'future']));

      expect(await l.resolveAll(), equals([20, -40]));
      expect(await l.resolveAllWith(() => 123), equals(123));
      expect(await l.resolveAllWithValue(456), equals(456));

      expect(
          await l.resolveAllMapped((value) => value * 10), equals([200, -400]));

      expect(await l.resolveAllThen((value) => value.reduce((v, e) => v * e)),
          equals(-800));

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

      expect(l.allAsList.map((e) => e is num ? e : 'future'),
          equals(['future', 'future']));

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

  group('IterableFutureOrExtensionNullable', () {
    test('whereNotNull', () async {
      expect(await [20, null, Future.value(40)].whereNotNull().resolveAll(),
          equals([20, 40]));

      expect(
          await [20, null, Future.value(40)]
              .map((e) => e)
              .whereNotNull()
              .resolveAll(),
          equals([20, 40]));

      expect(await [20, Future.value(40)].whereNotNull().resolveAll(),
          equals([20, 40]));

      expect(await [20, 40].whereNotNull().resolveAll(), equals([20, 40]));
      expect([20, 40].whereNotNull().resolveAll(), equals([20, 40]));

      expect(
          await [20, null, 40].whereNotNull().resolveAll(), equals([20, 40]));
      expect([20, null, 40].whereNotNull().resolveAll(), equals([20, 40]));

      expect([20, null, 40].map((e) => e).whereNotNull().resolveAll(),
          equals([20, 40]));
    });

    test('whereNotNullResolved', () async {
      expect([20, null, Future.value(40)].whereNotNullResolved(), equals([20]));

      expect([20, null, Future.value(40)].map((e) => e).whereNotNullResolved(),
          equals([20]));

      expect([20, Future.value(40)].whereNotNullResolved(), equals([20]));

      expect([20, null, 40].whereNotNullResolved(), equals([20, 40]));

      expect([20, null, 40].map((e) => e).whereNotNullResolved(),
          equals([20, 40]));

      expect([20, 40].whereNotNullResolved(), equals([20, 40]));
    });

    test('resolveAllNotNull', () async {
      expect(await ([20, null, Future.value(40)].resolveAllNotNull()),
          equals([20, 40]));

      expect(
          await ([20, null, Future.value(40)]
              .map((e) => e)
              .resolveAllNotNull()),
          equals([20, 40]));

      expect(await ([20, null, 40].resolveAllNotNull()), equals([20, 40]));

      expect(
          await ([20, Future.value(40)].resolveAllNotNull()), equals([20, 40]));

      expect(await ([20, 40].resolveAllNotNull()), equals([20, 40]));

      expect(([20, null, 40].resolveAllNotNull()), equals([20, 40]));

      expect(
          ([20, null, 40].map((e) => e).resolveAllNotNull()), equals([20, 40]));

      expect((<FutureOr<int?>>[20, null, 40].map((e) => e).resolveAllNotNull()),
          equals([20, 40]));

      expect(([20, 40].resolveAllNotNull()), equals([20, 40]));

      expect(([20, 40].map((e) => e).resolveAllNotNull()), equals([20, 40]));
    });
  });
}

/// Multiply [a] * [b], and returns `int` for positive [a] and
/// a [Future] for negative [a].
FutureOr<T> _futureOrMultiply<T extends num>(T a, T b,
    [bool throwError = false]) {
  if (a > 0) {
    if (throwError) {
      throw StateError('Error');
    }
    return (a * b) as T;
  } else {
    if (throwError) {
      return Future.error(StateError('Error'), StackTrace.current);
    }
    return Future<T>.value((a * b) as T);
  }
}

bool _validateEven(dynamic v) {
  return v is int && v % 2 == 0;
}

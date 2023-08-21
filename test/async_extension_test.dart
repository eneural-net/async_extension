import 'package:async_extension/async_extension.dart';
import 'package:test/test.dart';

void main() {
  // Ensure that the standard Dart behavior happens in any platform.
  // Also it's a reference for the `asyncTry` behavior.
  group('Dart standard', () {
    test('try/catch/finally', () {
      Object? error;
      Object? f;
      try {
        throw StateError("e1");
      } catch (e) {
        error = e;
      } finally {
        f = 'final';
      }

      expect(error,
          isA<StateError>().having((e) => e.message, 'message', equals('e1')));

      expect(f, equals('final'));
    });

    test('try/catch/rethrow/finally inside try/catch', () {
      Object? error;
      Object? subError;
      Object? f;

      try {
        try {
          throw StateError("e1");
        } catch (e) {
          subError = e;
          rethrow;
        } finally {
          f = 'final';
        }
      } catch (e) {
        error = e;
      }

      expect(error,
          isA<StateError>().having((e) => e.message, 'message', equals('e1')));

      expect(subError,
          isA<StateError>().having((e) => e.message, 'message', equals('e1')));

      expect(f, equals('final'));
    });

    test('try/catch/rethrow/finally/throw inside try/catch', () {
      Object? error;
      Object? subError;
      Object? f;

      try {
        try {
          throw StateError("e1");
        } catch (e) {
          subError = e;
          rethrow;
        } finally {
          f = 'final';
          throw StateError("e2");
        }
      } catch (e) {
        error = e;
      }

      expect(error,
          isA<StateError>().having((e) => e.message, 'message', equals('e2')));

      expect(subError,
          isA<StateError>().having((e) => e.message, 'message', equals('e1')));

      expect(f, equals('final'));
    });
  });

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

    test('resolveOther', () async {
      expect(
          await _futureOrMultiply(10, 2)
              .resolveOther(_futureOrMultiply(20, 2), (v1, v2) => '$v1,$v2'),
          equals('20,40'));

      expect(
          await _futureOrMultiply(10, 2)
              .resolveOther('foo', (v1, v2) => '$v1,$v2'),
          equals('20,foo'));

      expect(
          await _futureOrMultiply(10, 2)
              .resolveOther(Future.value('bar'), (v1, v2) => '$v1,$v2'),
          equals('20,bar'));

      expect(
          await Future.value('foo')
              .resolveOther(Future.value('bar'), (v1, v2) => '$v1,$v2'),
          equals('foo,bar'));

      expect(await Future.value('foo').resolveOther(200, (v1, v2) => '$v1,$v2'),
          equals('foo,200'));
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

    test('AsyncLoop 3', () async {
      var l = [1, 2, 3];

      var sum = 0;

      var a1 = AsyncLoop.forEach<int>(l, (e) {
        sum += e;
        return true;
      });

      expect(await a1.run(), equals(3));
      expect(sum, equals(6));
    });

    test('AsyncLoop 4', () async {
      var l = [1, 2, 3];

      var sum = 0;

      var a1 = AsyncLoop.forEach<int>(l.map((e) => e * 2), (e) {
        sum += e;
        return true;
      });

      expect(await a1.run(), equals(3));
      expect(sum, equals(12));
    });

    test('AsyncLoop 5', () async {
      var l = [1, 2, 3];

      var sum = 0;

      var a1 = AsyncLoop.forEach<int>(l, (e) {
        return _asFuture(() {
          sum += e;
          return true;
        });
      });

      expect(await a1.run(), equals(3));
      expect(sum, equals(6));
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
      expect(_futureOrMultiply(10, 2).genericType, equals(int));
      expect(_futureOrMultiply(-10, 2).genericType, equals(int));
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
      expect(Future.value(123).genericType, equals(int));

      expect(
          await Future.value(110)
              .resolveBoth(Future.value(220), (v1, v2) => v1 + v2),
          equals(330));

      expect(await Future.value(110).resolveBoth(220, (v1, v2) => v1 + v2),
          equals(330));
    });
  });

  group('FutureOrIterableExtension', () {
    test('Iterable', () {
      FutureOr<Iterable<int>> futureOrItr = [1, 2, 3];

      expect(futureOrItr.toList(), equals([1, 2, 3]));
      expect(futureOrItr.asList, equals([1, 2, 3]));
      expect(futureOrItr.toSet(), equals({1, 2, 3}));
      expect(futureOrItr.length, equals(3));
      expect(futureOrItr.isEmpty, isFalse);
      expect(futureOrItr.isNotEmpty, isTrue);
      expect(futureOrItr.first, equals(1));
      expect(futureOrItr.firstOrNull, equals(1));
      expect(futureOrItr.last, equals(3));
      expect(futureOrItr.lastOrNull, equals(3));
    });
  });

  group('FutureIterableExtension', () {
    test('Iterable', () async {
      Future<Iterable<int>> futureItr = Future.value([1, 2, 3]);

      expect(await futureItr.toList(), equals([1, 2, 3]));
      expect(await futureItr.asList, equals([1, 2, 3]));
      expect(await futureItr.toSet(), equals({1, 2, 3}));
      expect(await futureItr.length, equals(3));
      expect(await futureItr.isEmpty, isFalse);
      expect(await futureItr.isNotEmpty, isTrue);
      expect(await futureItr.first, equals(1));
      expect(await futureItr.firstOrNull, equals(1));
      expect(await futureItr.last, equals(3));
      expect(await futureItr.lastOrNull, equals(3));
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

      expect(await [Future.value(10), Future.value(20)].resolveAll(),
          equals([10, 20]));

      expect(await [Future.value(10), Future.value(20), 30].resolveAll(),
          equals([10, 20, 30]));

      expect(
          await [
            Future.value(Future.value([1, 2])),
            Future.value(Future.value([3, 4])),
            [5, 6]
          ].resolveAll(),
          equals([
            [1, 2],
            [3, 4],
            [5, 6]
          ]));
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

      expect(l.selectFutures().resolveAll(), isA<Future<List<int>>>());
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
      expect(await [20, null, Future.value(40)].whereNotNullSync().resolveAll(),
          equals([20, 40]));

      expect(
          await [20, null, Future.value(40)]
              .map((e) => e)
              .whereNotNullSync()
              .resolveAll(),
          equals([20, 40]));

      expect(await [20, Future.value(40)].whereNotNullSync().resolveAll(),
          equals([20, 40]));

      expect(await [20, 40].whereNotNullSync().resolveAll(), equals([20, 40]));
      expect([20, 40].whereNotNullSync().resolveAll(), equals([20, 40]));

      expect(await [20, null, 40].whereNotNullSync().resolveAll(),
          equals([20, 40]));
      expect([20, null, 40].whereNotNullSync().resolveAll(), equals([20, 40]));

      expect([20, null, 40].map((e) => e).whereNotNullSync().resolveAll(),
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

    test('resolveAllNullable', () async {
      expect(
          await ([20, null, 40].resolveAllNullable()), equals([20, null, 40]));

      expect(await ([20, 30, 40].resolveAllNullable()), equals([20, 30, 40]));

      expect(await ([20, 30, 40].map((e) => e).resolveAllNullable()),
          equals([20, 30, 40]));

      expect(await (<dynamic>[20, 30, 40].resolveAllNullable()),
          equals([20, 30, 40]));

      expect(await ([20, null, 40].map((e) => e).resolveAllNullable()),
          equals([20, null, 40]));

      expect(await ([20, null, Future.value(40)].resolveAllNullable()),
          equals([20, null, 40]));

      expect(
          await ([20, null, Future.value(40)]
              .map((e) => e)
              .resolveAllNullable()),
          equals([20, null, 40]));
    });
  });

  group('MapFutureValueExtension', () {
    test('resolveAllValues', () async {
      expect(await {'a': 1, 'b': Future.value(2)}.resolveAllValues(),
          equals({'a': 1, 'b': 2}));

      expect(
          await {'a': 1, 'b': 2}.resolveAllValues(), equals({'a': 1, 'b': 2}));
    });

    test('resolveAllValuesNullable', () async {
      var map0 = <String, int?>{'a': 1, 'b': 2, 'c': null};
      expect(await map0.resolveAllValuesNullable(),
          equals({'a': 1, 'b': 2, 'c': null}));

      var map1 = <String, FutureOr<int?>>{
        'a': 1,
        'b': Future<int>.value(2),
        'c': null
      };
      expect(await map1.resolveAllValuesNullable(),
          equals({'a': 1, 'b': 2, 'c': null}));

      var map2 = <String, FutureOr<int?>>{
        'a': 1,
        'b': 2,
        'c': Future<int?>.value(null)
      };
      expect(await map2.resolveAllValuesNullable(),
          equals({'a': 1, 'b': 2, 'c': null}));

      var map3 = <String, FutureOr<int?>>{
        'a': 1,
        'b': null,
        'c': Future.value(null),
        'd': Future.value(4)
      };
      expect(await map3.resolveAllValuesNullable(),
          equals({'a': 1, 'b': null, 'c': null, 'd': 4}));

      var map4 = <String, Object?>{
        'a': 1,
        'b': null,
        'c': Future.value(null),
        'd': Future.value(4)
      };
      expect(await map4.resolveAllValuesNullable(),
          equals({'a': 1, 'b': null, 'c': null, 'd': 4}));

      var map5 = <String, dynamic>{
        'a': 1,
        'b': null,
        'c': Future.value(null),
        'd': Future.value(4)
      };
      expect(await map5.resolveAllValuesNullable(),
          equals({'a': 1, 'b': null, 'c': null, 'd': 4}));

      var map6 = <String, Object>{
        'a': 1,
        'b': 2,
        'c': Future.value(null),
        'd': Future.value(4)
      };
      expect(await map6.resolveAllValuesNullable(),
          equals({'a': 1, 'b': 2, 'c': null, 'd': 4}));
    });
  });

  group('MapFutureKeyExtension', () {
    test('resolveAllKeys', () async {
      expect(await {Future.value('a'): 1, 'b': 2}.resolveAllKeys(),
          equals({'a': 1, 'b': 2}));

      expect(await {'a': 1, 'b': 2}.resolveAllKeys(), equals({'a': 1, 'b': 2}));
    });
  });

  group('MapFutureExtension', () {
    test('resolveAllEntries', () async {
      expect(
          await {Future.value('a'): 1, 'b': 2, 'c': Future.value(3)}
              .resolveAllEntries(),
          equals({'a': 1, 'b': 2, 'c': 3}));

      expect(await {'a': 1, 'b': 2, 'c': 3}.resolveAllEntries(),
          equals({'a': 1, 'b': 2, 'c': 3}));
    });
  });

  group('asyncTry', () {
    test('value', () async {
      expect(asyncTry<int>(() => 123), equals(123));

      expect(await asyncTry<int>(() => Future.value(123)), equals(123));

      expect(
          await asyncTry<int>(
              () => _asFuture(() => Future.value(123), delayMs: 50)),
          equals(123));
    });

    test('then', () async {
      expect(asyncTry<int>(() => 123, then: (n) => n! * 2), equals(246));

      expect(
          await asyncTry<int>(
            () => Future.value(123),
            then: (n) => n! * 2,
          ),
          equals(246));

      expect(
          await asyncTry<int>(
            () => _asFuture(() => 123, delayMs: 50),
            then: (n) => n! * 2,
          ),
          equals(246));

      expect(
          await asyncTry<int>(
            () => _asFuture(() => 123, delayMs: 50),
            then: (n) => Future.value(n! * 3),
          ),
          equals(369));
    });

    test('then+catch+delay+error', () async {
      expect(asyncTry<int>(() => 123, then: (n) => n! * 2), equals(246));

      var error1 = <StateError>[];
      expect(
          await asyncTry<int>(
            () => Future.value(123),
            then: (n) => throw StateError('e1'),
            onError: (e) => error1.add(e),
          ),
          isNull);
      expect(error1.map((e) => e.message), equals(['e1']));

      var error2 = <StateError>[];
      expect(
          await asyncTry<int>(
            () => _asFuture(() => 123, delayMs: 50),
            then: (n) => throw StateError('e2'),
            onError: (e) => error2.add(e),
          ),
          isNull);
      expect(error2.map((e) => e.message), equals(['e2']));

      var error3 = <StateError>[];
      expect(
          await asyncTry<int>(
            () => _asFuture(() => 123, delayMs: 50),
            then: (n) => _asFuture(() => throw StateError('e3'), delayMs: 50),
            onError: (e) => error3.add(e),
          ),
          isNull);
      expect(error3.map((e) => e.message), equals(['e3']));
    });

    test('error+catch', () async {
      var error1 = <StateError>[];
      expect(
          asyncTry<int>(() => throw StateError('e1'), onError: (e) {
            error1.add(e);
            return -1;
          }),
          equals(-1));
      expect(error1.map((e) => e.message), equals(['e1']));

      var error2 = <StateError>[];
      var stack2 = <StackTrace>[];
      expect(
          await asyncTry<int>(
            () => Future.microtask(() => throw StateError('e2')),
            onError: (e, s) {
              error2.add(e);
              stack2.add(s);
              return -2;
            },
          ),
          equals(-2));
      expect(error2.map((e) => e.message), equals(['e2']));
      expect(stack2.length, equals(1));

      var error3 = <StateError>[];
      expect(
          await asyncTry<int>(
            () => Future.microtask(() => throw StateError('e3')),
            onError: (e) {
              error3.add(e);
              return _asFuture(() => -3, delayMs: 50);
            },
          ),
          equals(-3));
      expect(error3.map((e) => e.message), equals(['e3']));
    });

    test('error', () async {
      var error1 = <StateError>[];
      FutureOr<int?> ret1;
      try {
        ret1 = asyncTry<int>(() => throw StateError('e1'));
      } catch (e) {
        error1.add(e as StateError);
      }
      expect(ret1, isNull);
      expect(error1.map((e) => e.message), equals(['e1']));

      var error2 = <StateError>[];
      FutureOr<int?> ret2;
      try {
        ret2 = await asyncTry<int>(
            () => _asFuture(() => throw StateError('e2'), delayMs: 50));
      } catch (e) {
        error2.add(e as StateError);
      }
      expect(ret2, isNull);
      expect(error2.map((e) => e.message), equals(['e2']));
    });

    test('finally', () async {
      var finally1 = <int>[];
      expect(
          asyncTry<int>(
            () => 123,
            onFinally: () => finally1.add(1),
          ),
          equals(123));
      expect(finally1, equals([1]));

      var finally2 = <int>[];
      expect(
          await asyncTry<int>(
            () => Future.value(123),
            onFinally: () => finally2.add(2),
          ),
          equals(123));
      expect(finally2, equals([2]));

      var finally3 = <int>[];
      expect(
          await asyncTry<int>(
            () => _asFuture(
                () => _asFuture(() => Future.value(111), delayMs: 50),
                delayMs: 50),
            onFinally: () => finally3.add(3),
          ),
          equals(111));
      expect(finally3, equals([3]));

      var finally4 = <int>[];
      expect(
          await asyncTry<int>(
            () => Future.value(123),
            onFinally: () => _asFuture(() => finally4.add(4), delayMs: 50),
          ),
          equals(123));
      expect(finally4, equals([4]));
    });

    test('error+finally', () async {
      var error1 = <StateError>[];
      var finally1 = <int>[];
      FutureOr<int?> ret1;
      try {
        ret1 = asyncTry<int>(() => throw StateError('e1'),
            onFinally: () => finally1.add(1));
      } catch (e) {
        error1.add(e as StateError);
      }
      expect(ret1, isNull);
      expect(error1.map((e) => e.message), equals(['e1']));
      expect(finally1, equals([1]));

      var error2 = <StateError>[];
      var finally2 = <int>[];
      FutureOr<int?> ret2;
      try {
        ret2 = await asyncTry<int>(
            () => _asFuture(() => throw StateError('e2'), delayMs: 50),
            onFinally: () => finally2.add(2));
      } catch (e) {
        error2.add(e as StateError);
      }
      expect(ret2, isNull);
      expect(error2.map((e) => e.message), equals(['e2']));
      expect(finally2, equals([2]));
    });

    test('error+finally+error2', () async {
      var error1 = <StateError>[];
      var finally1 = <int>[];
      FutureOr<int?> ret1;
      try {
        ret1 = asyncTry<int>(() => throw StateError('e1'),
            // ignore: void_checks
            onFinally: () {
          finally1.add(1);
          throw StateError('fe1');
        });
      } catch (e) {
        error1.add(e as StateError);
      }
      expect(ret1, isNull);
      expect(error1.map((e) => e.message), equals(['fe1']));
      expect(finally1, equals([1]));

      var error2 = <StateError>[];
      var finally2 = <int>[];
      FutureOr<int?> ret2;
      try {
        ret2 = await asyncTry<int>(
            () => _asFuture(() => throw StateError('e2'), delayMs: 50),
            // ignore: void_checks
            onFinally: () => _asFuture(() {
                  finally2.add(2);
                  throw StateError('fe2');
                }));
      } catch (e) {
        error2.add(e as StateError);
      }
      expect(ret2, isNull);
      expect(error2.map((e) => e.message), equals(['fe2']));
      expect(finally2, equals([2]));
    });

    test('then+finally', () async {
      var finally1 = <int>[];
      expect(
          asyncTry<int>(
            () => 123,
            then: (n) => n! * 2,
            onFinally: () => finally1.add(1),
          ),
          equals(246));
      expect(finally1, equals([1]));

      var finally2 = <int>[];
      expect(
          await asyncTry<int>(
            () => Future.value(123),
            then: (n) => n! * 2,
            onFinally: () => finally2.add(2),
          ),
          equals(246));
      expect(finally2, equals([2]));

      var finally3 = <int>[];
      expect(
          await asyncTry<int>(
            () => _asFuture(() => 123, delayMs: 50),
            then: (n) => n! * 2,
            onFinally: () => finally3.add(3),
          ),
          equals(246));
      expect(finally3, equals([3]));

      var finally4 = <int>[];
      expect(
          await asyncTry<int>(
            () => _asFuture(() => 123, delayMs: 50),
            then: (n) => _asFuture(() => n! * 2, delayMs: 50),
            onFinally: () => _asFuture(() => finally4.add(4), delayMs: 50),
          ),
          equals(246));
      expect(finally4, equals([4]));
    });

    test('error+catch+finally', () async {
      var error1 = <StateError>[];
      var finally1 = <int>[];
      expect(
          asyncTry<int>(
            () => throw StateError('e1'),
            onError: (e) {
              error1.add(e);
              return -1;
            },
            onFinally: () => finally1.add(1),
          ),
          equals(-1));
      expect(error1.map((e) => e.message), equals(['e1']));
      expect(finally1, equals([1]));

      var error2 = <StateError>[];
      var finally2 = <int>[];
      expect(
          await asyncTry<int>(
            () => Future.microtask(() => throw StateError('e2')),
            onError: (e) {
              error2.add(e);
              return -2;
            },
            onFinally: () => finally2.add(2),
          ),
          equals(-2));
      expect(error2.map((e) => e.message), equals(['e2']));
      expect(finally2, equals([2]));
    });

    test('error+catch+then+finally', () async {
      var error1 = <StateError>[];
      var finally1 = <int>[];
      expect(
          asyncTry<int>(
            () => throw StateError('e1'),
            then: (n) => n! * 2,
            onError: (e) => error1.add(e),
            onFinally: () => finally1.add(1),
          ),
          isNull);
      expect(error1.map((e) => e.message), equals(['e1']));
      expect(finally1, equals([1]));

      var error2 = <StateError>[];
      var finally2 = <int>[];
      expect(
          await asyncTry<int>(
            () => _asFuture(() => throw StateError('e2'), delayMs: 50),
            then: (n) => n! * 2,
            onError: (e) => error2.add(e),
            onFinally: () => finally2.add(2),
          ),
          isNull);
      expect(error2.map((e) => e.message), equals(['e2']));
      expect(finally2, equals([2]));
    });

    test('then+error+catch+finally', () async {
      var error1 = <StateError>[];
      var finally1 = <int>[];
      expect(
          asyncTry<int>(
            () => 123,
            then: (n) => throw StateError('e1'),
            onError: (e) => error1.add(e),
            onFinally: () => finally1.add(1),
          ),
          isNull);
      expect(error1.map((e) => e.message), equals(['e1']));
      expect(finally1, equals([1]));

      var error2 = <StateError>[];
      var finally2 = <int>[];
      expect(
          await asyncTry<int>(
            () => Future.value(123),
            then: (n) => throw StateError('e2'),
            onError: (e) => error2.add(e),
            onFinally: () => finally2.add(2),
          ),
          isNull);
      expect(error2.map((e) => e.message), equals(['e2']));
      expect(finally2, equals([2]));
    });

    test('error+catch+finally', () async {
      var error1 = <StateError>[];
      var finally1 = <int>[];
      expect(
          asyncTry<int>(
            () => throw StateError('e1'),
            onError: (e) => error1.add(e),
            onFinally: () => finally1.add(1),
          ),
          isNull);
      expect(error1.map((e) => e.message), equals(['e1']));
      expect(finally1, equals([1]));

      var error2 = <StateError>[];
      var finally2 = <int>[];
      expect(
          await asyncTry<int>(
            () => _asFuture(() => throw StateError('e2')),
            onError: (e) => error2.add(e),
            onFinally: () => finally2.add(2),
          ),
          isNull);
      expect(error2.map((e) => e.message), equals(['e2']));
      expect(finally2, equals([2]));
    });

    test('error+finally', () async {
      var finally1 = <int>[];
      await expectLater(
          () => asyncTry<int>(
                () => throw StateError('e1'),
                onFinally: () => finally1.add(1),
              ),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', equals('e1'))));
      expect(finally1, equals([1]));

      var finally2 = <int>[];

      await expectLater(
          () => asyncTry<int>(
                () => _asFuture(() => throw StateError('e2')),
                onFinally: () => _asFuture(() => finally2.add(2)),
              ),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', equals('e2'))));

      expect(finally2, equals([2]));
    });

    test('error+catch+rethrow+finally', () async {
      var error1 = <StateError>[];
      var finally1 = <int>[];
      expect(
          () => asyncTry<int>(
                () => throw StateError('e1'),
                onError: (e) {
                  error1.add(e);
                  throw e;
                },
                onFinally: () => finally1.add(1),
              ),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', equals('e1'))));

      expect(error1.map((e) => e.message), equals(['e1']));
      expect(finally1, equals([1]));

      var error2 = <StateError>[];
      var finally2 = <int>[];

      await expectLater(
          () => asyncTry<int>(
                () => _asFuture(() => throw StateError('e2')),
                onError: (e) {
                  error2.add(e);
                  throw e;
                },
                onFinally: () => _asFuture(() => finally2.add(2)),
              ),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', equals('e2'))));

      expect(error2.map((e) => e.message), equals(['e2']));
      expect(finally2, equals([2]));

      var error3 = <StateError>[];
      var finally3 = <int>[];

      await expectLater(
          () => asyncTry<int>(
                () => _asFuture(() => throw StateError('e3')),
                onError: (e) => _asFuture(() {
                  error3.add(e);
                  throw e;
                }),
                onFinally: () => _asFuture(() => finally3.add(2)),
              ),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', equals('e3'))));

      expect(error3.map((e) => e.message), equals(['e3']));
      expect(finally3, equals([2]));
    });

    test('error+catch+rethrow+finally+error2', () async {
      var error1 = <StateError>[];

      var finally1 = <int>[];
      expect(
          () => asyncTry<int>(
                () => throw StateError('e1'),
                onError: (e) {
                  error1.add(e);
                  throw e;
                },
                // ignore: void_checks
                onFinally: () {
                  finally1.add(1);
                  throw StateError('fe1');
                },
              ),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', equals('fe1'))));

      expect(error1.map((e) => e.message), equals(['e1']));
      expect(finally1, equals([1]));

      var error2 = <StateError>[];
      var finally2 = <int>[];

      await expectLater(
          () => asyncTry<int>(
                () => _asFuture<int>(() => throw StateError('e2')),
                onError: (e) {
                  error2.add(e);
                  throw e;
                },
                // ignore: void_checks
                onFinally: () => _asFuture(() {
                  finally2.add(2);
                  throw StateError('fe2');
                }),
              ),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', equals('fe2'))));

      expect(error2.map((e) => e.message), equals(['e2']));
      expect(finally2, equals([2]));
    });
  });
}

Future<T> _asFuture<T>(FutureOr<T> Function() f, {int delayMs = 1}) =>
    Future.delayed(Duration(milliseconds: delayMs), f);

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

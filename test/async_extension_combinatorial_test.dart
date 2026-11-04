import 'package:async_extension/async_extension.dart';
import 'package:test/test.dart';

/// Builds a [FutureOr] that is either a sync value or an async [Future].
FutureOr<T> _v<T>(T value, {required bool async}) =>
    async ? Future<T>.value(value) : value;

/// Lets all pending microtasks and zero-duration timers run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

Matcher _stateError(String message) =>
    isA<StateError>().having((e) => e.message, 'message', equals(message));

void main() {
  group('FutureOr helpers: sync/async combinations', () {
    for (var asyncA in [false, true]) {
      for (var asyncB in [false, true]) {
        final desc =
            'a: ${asyncA ? 'async' : 'sync'}, '
            'b: ${asyncB ? 'async' : 'sync'}';

        test('resolveBoth ($desc)', () async {
          var r = _v(
            3,
            async: asyncA,
          ).resolveBoth(_v(4, async: asyncB), (a, b) => a * 10 + b);
          expect(r is Future, equals(asyncA || asyncB));
          expect(await r, equals(34));
        });

        test('resolveOther ($desc)', () async {
          var r = _v(3, async: asyncA).resolveOther<String, String>(
            _v('x', async: asyncB),
            (a, b) => '$b$a',
          );
          expect(r is Future, equals(asyncA || asyncB));
          expect(await r, equals('x3'));
        });

        test('int operators ($desc)', () async {
          FutureOr<int> a() => _v(7, async: asyncA);
          FutureOr<int> b() => _v(2, async: asyncB);

          expect(await (a() + b()), equals(9));
          expect(await (a() - b()), equals(5));
          expect(await (a() * b()), equals(14));
          expect(await (a() / b()), equals(3.5));
          expect(await (a() ~/ b()), equals(3));
        });

        test('double operators ($desc)', () async {
          FutureOr<double> a() => _v(7.0, async: asyncA);
          FutureOr<double> b() => _v(2.0, async: asyncB);

          expect(await (a() + b()), equals(9.0));
          expect(await (a() - b()), equals(5.0));
          expect(await (a() * b()), equals(14.0));
          expect(await (a() / b()), equals(3.5));
          expect(await (a() ~/ b()), equals(3));
        });

        test('resolveBoth error propagation ($desc)', () async {
          FutureOr<int> failing() => asyncB
              ? Future<int>.error(StateError('b'))
              : throw StateError('b');

          // A sync error is thrown synchronously when building `other`,
          // so only the async case reaches `resolveBoth`:
          if (asyncB) {
            await expectLater(
              Future.sync(
                () => _v(1, async: asyncA).resolveBoth(failing(), (a, b) => a),
              ),
              throwsA(_stateError('b')),
            );
          } else {
            expect(failing, throwsA(_stateError('b')));
          }
        });

        test('resolver throwing ($desc)', () async {
          FutureOr<int> call() => _v(1, async: asyncA).resolveBoth(
            _v(2, async: asyncB),
            (a, b) => throw StateError('resolver'),
          );

          if (asyncA || asyncB) {
            var r = call();
            expect(r, isA<Future>());
            await expectLater(r, throwsA(_stateError('resolver')));
          } else {
            expect(call, throwsA(_stateError('resolver')));
          }
        });
      }
    }

    for (var async in [false, true]) {
      final mode = async ? 'async' : 'sync';

      test('resolveMapped / resolveWith / resolveWithValue ($mode)', () async {
        var calls = <String>[];
        var r1 = _v(2, async: async).resolveMapped((v) => v * 5);
        var r2 = _v(2, async: async).resolveWith(() {
          calls.add('with');
          return 'done';
        });
        var r3 = _v(2, async: async).resolveWithValue('value');

        expect(r1 is Future, equals(async));
        expect(r2 is Future, equals(async));
        expect(r3 is Future, equals(async));

        expect(await r1, equals(10));
        expect(await r2, equals('done'));
        expect(await r3, equals('value'));
        expect(calls, equals(['with']));
      });

      test('resolveMapped with a mapper returning a Future ($mode)', () async {
        var r = _v(2, async: async).resolveMapped((v) => Future.value(v + 1));
        expect(r, isA<Future>());
        expect(await r, equals(3));
      });

      test('mapper throwing ($mode)', () async {
        FutureOr<int> call() =>
            _v(2, async: async).resolveMapped((v) => throw StateError('m'));

        if (async) {
          await expectLater(call(), throwsA(_stateError('m')));
        } else {
          expect(call, throwsA(_stateError('m')));
        }
      });

      test('onResolve ($mode)', () async {
        var got = <int>[];
        var r = _v(5, async: async).onResolve<void>(got.add);
        if (async) {
          expect(got, isEmpty);
          await r;
        } else {
          expect(r, isNull);
        }
        expect(got, equals([5]));
      });

      test('then with onError on a failing Future ($mode)', () async {
        FutureOr<int> f = async ? Future<int>.error(StateError('x')) : 1;
        var r = f.then((v) => v + 1, onError: (Object e) => -1);
        expect(await r, equals(async ? -1 : 2));
      });

      test('resolve with null values and defaultValue ($mode)', () async {
        FutureOr<int?> n = _v<int?>(null, async: async);
        expect(await n.resolve(defaultValue: 9), equals(9));

        FutureOr<int?> v = _v<int?>(3, async: async);
        expect(await v.resolve(defaultValue: 9), equals(3));

        // No validate and no default: returns `this` (identity).
        FutureOr<int?> same = _v<int?>(null, async: async);
        expect(identical(same.resolve(), same), isTrue);
      });

      test(
        'resolve / validate with sync and async validators ($mode)',
        () async {
          for (var asyncValidator in [false, true]) {
            FutureOr<bool> isEven(int v) => _v(v.isEven, async: asyncValidator);

            var even = _v(4, async: async);
            var odd = _v(3, async: async);

            expect(
              await even.resolve(validate: isEven, defaultValue: 0),
              equals(4),
            );
            expect(
              await odd.resolve(validate: isEven, defaultValue: 0),
              equals(0),
            );
            expect(await odd.validate(isEven), isNull);
            expect(await odd.validate(isEven, defaultValue: -2), equals(-2));
            expect(await even.validate(isEven), equals(4));

            // The result is sync only when both the value and the validator
            // are sync:
            var r = _v(4, async: async).validate(isEven);
            expect(r is Future, equals(async || asyncValidator));
          }
        },
      );

      test(
        'whenAsync with bool, lazy and invalid conditions ($mode)',
        () async {
          var evaluated = 0;
          bool lazy() {
            evaluated++;
            return true;
          }

          expect(await _v(1, async: async).whenAsync(true), equals(1));
          expect(await _v(1, async: async).whenAsync(false), isNull);
          expect(await _v(1, async: async).whenAsync(null), isNull);
          expect(await _v(1, async: async).whenAsync('yes'), isNull);

          var r = _v(1, async: async).whenAsync(lazy);
          // For a Future the lazy condition is only evaluated after resolution:
          expect(evaluated, equals(async ? 0 : 1));
          expect(await r, equals(1));
          expect(evaluated, equals(1));
        },
      );

      test('orElseAsync / orElseGeAsync ($mode)', () async {
        FutureOr<int?> n = _v<int?>(null, async: async);
        FutureOr<int?> v = _v<int?>(5, async: async);

        expect(await n.orElseAsync(7), equals(7));
        expect(await v.orElseAsync(7), equals(5));

        var getterCalls = 0;
        FutureOr<int> getter() {
          getterCalls++;
          return Future.value(8);
        }

        expect(await n.orElseGeAsync(getter), equals(8));
        expect(await v.orElseGeAsync(getter), equals(5));
        expect(getterCalls, equals(1));
      });

      test('asFuture / isResolved ($mode)', () async {
        var f = _v(1, async: async);
        expect(f.isResolved, equals(!async));
        expect(f.asFuture, isA<Future<int>>());
        expect(await f.asFuture, equals(1));
        if (async) {
          expect(identical(f.asFuture, f), isTrue);
        }
      });
    }

    test('nested FutureOr values are flattened by Future.value', () async {
      FutureOr<FutureOr<int>> nested = Future.value(Future.value(1));
      // `Future.value` flattens a `Future` argument:
      expect(await nested, equals(1));

      FutureOr<FutureOr<int>> nestedSync = Future.value(1);
      expect(await nestedSync.resolveMapped((v) => v), equals(1));
    });

    test('ObjectExtension.when', () {
      expect(5.when(true), equals(5));
      expect(5.when(false), isNull);
      expect(5.when(() => true), equals(5));
      expect(5.when(() => false), isNull);
      expect(5.when(1), isNull);
    });
  });

  group('tryCall / tryCallThen: sync/async and error combinations', () {
    for (var asyncFn in [false, true]) {
      for (var fails in [false, true]) {
        for (var syncError in [false, true]) {
          if (!fails && syncError) continue;

          final desc =
              'fn: ${asyncFn ? 'async' : 'sync'}, '
              'fails: $fails${fails ? ' (${syncError ? 'thrown' : 'failed future'})' : ''}';

          FutureOr<int> fn() {
            if (fails) {
              if (syncError) throw StateError('fn');
              return Future<int>.error(StateError('fn'));
            }
            return _v(10, async: asyncFn);
          }

          test('tryCall with onError ($desc)', () async {
            var errors = <Object>[];
            var r = fn.tryCall(
              onError: (e, s) {
                errors.add(e);
                return -1;
              },
            );
            expect(await r, equals(fails ? -1 : 10));
            expect(errors, fails ? [_stateError('fn')] : isEmpty);

            // A sync error is handled synchronously:
            if (fails && syncError) expect(r, equals(-1));
          });

          test('tryCall without onError ($desc)', () async {
            if (fails) {
              await expectLater(
                Future.sync(() => fn.tryCall()),
                throwsA(_stateError('fn')),
              );
            } else {
              expect(await fn.tryCall(), equals(10));
            }
          });

          test('tryCallThen with onError ($desc)', () async {
            var r = fn.tryCallThen<String>(
              (v) => 'v$v',
              onError: (e, s) => 'error',
            );
            expect(await r, equals(fails ? 'error' : 'v10'));
          });

          test('tryCallThen with throwing onValue ($desc)', () async {
            var errors = <Object>[];
            var r = fn.tryCallThen<String>(
              (v) => throw StateError('onValue'),
              onError: (e, s) {
                errors.add(e);
                return 'error';
              },
            );
            expect(await r, equals('error'));
            expect(errors, [_stateError(fails ? 'fn' : 'onValue')]);
          });

          test('tryCallThen with async failing onValue ($desc)', () async {
            var r = fn.tryCallThen<String>(
              (v) => Future<String>.error(StateError('onValue')),
              onError: (e, s) => 'error',
            );
            expect(await r, equals('error'));
          });

          test('Future of function: tryCall ($desc)', () async {
            FutureOr<FutureOr<int> Function()> futureFn = Future.value(fn);
            expect(
              await futureFn.tryCall(onError: (e, s) => -1),
              equals(fails ? -1 : 10),
            );
            expect(
              await futureFn.tryCallThen((v) => v + 1, onError: (e, s) => -1),
              equals(fails ? -1 : 11),
            );
          });
        }
      }
    }

    test('Args1 / Args2 propagate arguments in all modes', () async {
      for (var async in [false, true]) {
        FutureOr<int> f1(int a) => _v(a * 2, async: async);
        FutureOr<int> f2(int a, int b) => _v(a + b, async: async);

        expect(await f1.tryCall(4), equals(8));
        expect(await f1.tryCallThen(4, (v) => v + 1), equals(9));
        expect(await f2.tryCall(4, 5), equals(9));
        expect(await f2.tryCallThen(4, 5, (v) => v * 2), equals(18));

        expect(await f1.asFutureOr.tryCall(4), equals(8));
        expect(await f2.asFutureOr.tryCallThen(1, 2, (v) => v), equals(3));
      }
    });

    test('Args1 / Args2 tryCallThen: onError handles onValue errors in '
        'all modes', () async {
      for (var async in [false, true]) {
        FutureOr<int> f1(int a) => _v(a * 2, async: async);
        FutureOr<int> f2(int a, int b) => _v(a + b, async: async);

        expect(
          await f1.tryCallThen<int>(4, (v) => v + 1, onError: (e, s) => -1),
          equals(9),
        );
        expect(
          await f2.tryCallThen<int>(4, 5, (v) => v * 2, onError: (e, s) => -1),
          equals(18),
        );

        var errors = <Object>[];
        int onError(Object e, StackTrace s) {
          errors.add(e);
          return -1;
        }

        expect(
          await f1.tryCallThen<int>(
            4,
            (v) => throw StateError('onValue1'),
            onError: onError,
          ),
          equals(-1),
        );
        expect(
          await f2.tryCallThen<int>(
            4,
            5,
            (v) => Future<int>.error(StateError('onValue2')),
            onError: onError,
          ),
          equals(-1),
        );
        expect(errors, [_stateError('onValue1'), _stateError('onValue2')]);
      }
    });
  });

  group('Iterable<FutureOr> helpers: mixed and failing elements', () {
    List<FutureOr<int>> mixed() => [1, Future.value(2), 3, Future.value(4)];

    test('mixed elements keep their order', () async {
      expect(await mixed().resolveAll(), equals([1, 2, 3, 4]));
      expect(
        await mixed().resolveAllMapped((e) => e * 10),
        equals([10, 20, 30, 40]),
      );
      expect(
        await mixed().resolveAllValidated((e) => e.isEven, defaultValue: 0),
        equals([0, 2, 0, 4]),
      );
      expect(
        await mixed().resolveAllJoined((l) => l.join(',')),
        equals('1,2,3,4'),
      );
      expect(await mixed().resolveAllReduced((a, b) => a + b), equals(10));
      expect(await mixed().resolveAllThen((l) => l.length), equals(4));
      expect(await mixed().resolveAllWith(() => 'ok'), equals('ok'));
      expect(await mixed().resolveAllWithValue('v'), equals('v'));
      expect(await mixed().waitFutures(), equals([2, 4]));
      expect(await mixed().waitFuturesAndReturnValue('w'), equals('w'));
      expect(mixed().selectResolved(), equals([1, 3]));
      expect(mixed().selectFutures().length, equals(2));
      expect(mixed().isAllResolved, isFalse);
      expect(mixed().isAllFuture, isFalse);
    });

    test('all sync elements resolve synchronously', () {
      List<FutureOr<int>> l = [1, 2, 3];
      expect(l.resolveAll(), equals([1, 2, 3]));
      expect(l.resolveAllMapped((e) => e + 1), equals([2, 3, 4]));
      expect(l.resolveAllJoined((l) => l.length), equals(3));
      expect(l.resolveAllReduced((a, b) => a * b), equals(6));
      expect(l.waitFutures(), equals(<int>[]));
      expect(l.waitFuturesAndReturnValue(1), equals(1));
      expect(l.isAllResolved, isTrue);
    });

    test('a failing element fails the whole resolution', () async {
      List<FutureOr<int>> l() => [1, Future<int>.error(StateError('e')), 3];

      await expectLater(l().resolveAll(), throwsA(_stateError('e')));
      await expectLater(
        l().resolveAllMapped((e) => e),
        throwsA(_stateError('e')),
      );
      await expectLater(
        Future.sync(() => l().resolveAllJoined((l) => l)),
        throwsA(_stateError('e')),
      );
      await expectLater(
        Future.sync(() => l().resolveAllWith(() => 0)),
        throwsA(_stateError('e')),
      );
    });

    test('a throwing mapper/joiner/reducer propagates', () async {
      for (var async in [false, true]) {
        List<FutureOr<int>> l = [_v(1, async: async), _v(2, async: async)];
        await expectLater(
          Future.sync(
            () => l.resolveAllMapped<int>((e) => throw StateError('m')),
          ),
          throwsA(_stateError('m')),
        );
        await expectLater(
          Future.sync(
            () => l.resolveAllJoined<int>((e) => throw StateError('j')),
          ),
          throwsA(_stateError('j')),
        );
        await expectLater(
          Future.sync(
            () => l.resolveAllReduced((a, b) => throw StateError('r')),
          ),
          throwsA(_stateError('r')),
        );
      }
    });

    test('empty iterables', () async {
      List<FutureOr<int>> e = [];
      expect(e.resolveAll(), equals(<int>[]));
      expect(e.resolveAllMapped((v) => v), equals(<int>[]));
      expect(e.resolveAllJoined((l) => l.length), equals(0));
      expect(e.resolveAllWith(() => 1), equals(1));
      // Reducing an empty iterable throws synchronously (as `Iterable.reduce`):
      expect(() => e.resolveAllReduced((a, b) => a), throwsStateError);

      var futures = <Future<int>>[];
      expect(await futures.resolveAll(), isEmpty);
      expect(await futures.resolveAllJoined((l) => l.length), equals(0));
      expect(await futures.waitFuturesAndReturnValue('x'), equals('x'));
      // The `Iterable<Future>` version also throws synchronously:
      expect(() => futures.resolveAllReduced((a, b) => a), throwsStateError);
    });

    test('nullable elements: resolveAllNotNull / resolveAllNullable', () async {
      List<FutureOr<int?>> l = [
        1,
        null,
        Future<int?>.value(null),
        Future<int?>.value(4),
      ];

      expect(await l.resolveAllNotNull(), equals([1, 4]));
      expect(await l.resolveAllNullable(), equals([1, null, null, 4]));
      // Futures are not considered resolved, even if they will be null:
      expect(l.whereNotNullSync().length, equals(3));
      expect(l.whereNotNullResolved().toList(), equals([1]));

      List<FutureOr<int?>> syncOnly = [1, null, 3];
      expect(syncOnly.resolveAllNotNull(), equals([1, 3]));
      expect(syncOnly.resolveAllNullable(), equals([1, null, 3]));

      List<FutureOr<int?>> empty = [];
      expect(empty.resolveAllNotNull(), isEmpty);
      expect(empty.resolveAllNullable(), isEmpty);
    });

    test('nullable Futures: waitFuturesNullable / asFuturesNullable', () async {
      List<FutureOr<int>?> l = [1, null, Future.value(3)];
      expect(await l.waitFuturesNullable(), equals([3]));
      expect(l.selectFuturesNullable().length, equals(1));

      List<FutureOr<int>?> noFutures = [1, null];
      expect(noFutures.waitFuturesNullable(), isEmpty);
    });

    test('lazy iterables are evaluated once', () async {
      var evaluated = 0;
      Iterable<FutureOr<int>> lazy = [1, 2, 3].map((e) {
        evaluated++;
        return e.isEven ? Future.value(e) : e;
      });

      expect(await lazy.resolveAll(), equals([1, 2, 3]));
      expect(evaluated, equals(3));
    });
  });

  group('Map helpers: sync/async combinations', () {
    for (var asyncKeys in [false, true]) {
      for (var asyncValues in [false, true]) {
        final desc =
            'keys: ${asyncKeys ? 'async' : 'sync'}, '
            'values: ${asyncValues ? 'async' : 'sync'}';

        test('resolveAllEntries ($desc)', () async {
          var m = <FutureOr<String>, FutureOr<int>>{
            _v('a', async: asyncKeys): _v(1, async: asyncValues),
            _v('b', async: asyncKeys): _v(2, async: asyncValues),
          };
          var r = m.resolveAllEntries();
          expect(await r, equals({'a': 1, 'b': 2}));
        });

        test('Iterable<MapEntry>.resolveAllEntries ($desc)', () async {
          var entries = [
            MapEntry<FutureOr<String>, FutureOr<int>>(
              _v('a', async: asyncKeys),
              _v(1, async: asyncValues),
            ),
            MapEntry<FutureOr<String>, FutureOr<int>>(
              _v('b', async: asyncKeys),
              _v(2, async: asyncValues),
            ),
          ];
          var r = await entries.resolveAllEntries();
          expect(
            r.map((e) => '${e.key}=${e.value}').toList(),
            equals(['a=1', 'b=2']),
          );
        });
      }
    }

    test('resolveAllValuesNullable keeps null values and keys order', () async {
      var m = <String, FutureOr<int?>>{
        'z': Future<int?>.value(null),
        'a': 1,
        'm': Future<int?>.value(3),
      };
      var r = await m.resolveAllValuesNullable();
      expect(r, equals({'z': null, 'a': 1, 'm': 3}));
      expect(r.keys.toList(), equals(['z', 'a', 'm']));
    });

    test('resolveAllValues with a failing value', () async {
      var m = <String, FutureOr<int>>{
        'a': 1,
        'b': Future<int>.error(StateError('v')),
      };
      await expectLater(
        Future.sync(() => m.resolveAllValues()),
        throwsA(_stateError('v')),
      );
    });

    test('resolveAllKeys with async keys', () async {
      var m = <FutureOr<int>, String>{Future.value(2): 'b', 1: 'a'};
      var r = await m.resolveAllKeys();
      expect(r, equals({2: 'b', 1: 'a'}));
    });
  });

  group('FutureOr<Iterable> helpers', () {
    for (var async in [false, true]) {
      final mode = async ? 'async' : 'sync';

      test('non-null iterable ($mode)', () async {
        FutureOr<Iterable<int>> itr() =>
            _v<Iterable<int>>([3, 1, 3], async: async);

        expect(await itr().toListAsync(), equals([3, 1, 3]));
        expect(await itr().toSetAsync(), equals({3, 1}));
        expect(await itr().asListAsync, equals([3, 1, 3]));
        expect(await itr().lengthAsync, equals(3));
        expect(await itr().isEmptyAsync, isFalse);
        expect(await itr().isNotEmptyAsync, isTrue);
        expect(await itr().firstAsync, equals(3));
        expect(await itr().firstOrNullAsync, equals(3));
        expect(await itr().lastAsync, equals(3));
        expect(await itr().lastOrNullAsync, equals(3));
      });

      test('empty iterable ($mode)', () async {
        FutureOr<Iterable<int>> itr() =>
            _v<Iterable<int>>(<int>[], async: async);

        expect(await itr().isEmptyAsync, isTrue);
        expect(await itr().firstOrNullAsync, isNull);
        expect(await itr().lastOrNullAsync, isNull);
        await expectLater(
          Future.sync(() => itr().firstAsync),
          throwsStateError,
        );
      });

      test('nullable iterable ($mode)', () async {
        FutureOr<Iterable<int>?> nul() =>
            _v<Iterable<int>?>(null, async: async);
        FutureOr<Iterable<int>?> some() =>
            _v<Iterable<int>?>([1, 2], async: async);

        expect(await nul().toListOrNullAsync(), isNull);
        expect(await nul().toSetOrNullAsync(), isNull);
        expect(await nul().asListOrNullAsync, isNull);
        expect(await nul().isEmptyOrNullAsync, isTrue);
        expect(await nul().isNotEmptyAsync, isFalse);
        expect(await nul().firstOrNullAsync, isNull);
        expect(await nul().lastOrNullAsync, isNull);

        expect(await some().toListOrNullAsync(), equals([1, 2]));
        expect(await some().toSetOrNullAsync(), equals({1, 2}));
        expect(await some().asListOrNullAsync, equals([1, 2]));
        expect(await some().isEmptyOrNullAsync, isFalse);
        expect(await some().isNotEmptyAsync, isTrue);
        expect(await some().firstOrNullAsync, equals(1));
        expect(await some().lastOrNullAsync, equals(2));
      });
    }
  });

  group('forEachAsync / AsyncLoop / AsyncSequenceLoop', () {
    test(
      'forEachAsync switches from sync to async and stays sequential',
      () async {
        var log = <String>[];
        var completers = <int, Completer<int>>{};

        FutureOr<int> processor(int e) {
          log.add('start $e');
          if (e >= 2) {
            var c = completers[e] = Completer<int>();
            return c.future;
          }
          return e * 10;
        }

        var r = [0, 1, 2, 3].forEachAsync(processor);
        expect(r, isA<Future>());
        expect(log, equals(['start 0', 'start 1', 'start 2']));

        // Element 3 is only processed after element 2 completes:
        await _settle();
        expect(log, equals(['start 0', 'start 1', 'start 2']));

        completers[2]!.complete(20);
        await _settle();
        expect(log, equals(['start 0', 'start 1', 'start 2', 'start 3']));

        completers[3]!.complete(30);
        expect(await r, equals([0, 10, 20, 30]));
      },
    );

    test('forEachAsync all sync returns a List synchronously', () {
      var r = [1, 2, 3].forEachAsync((e) => e + 1);
      expect(r, equals([2, 3, 4]));
      expect(<int>[].forEachAsync((e) => e), equals([]));
    });

    test('forEachAsync processor errors (sync and async)', () async {
      expect(
        () => [1, 2].forEachAsync<int>((e) => throw StateError('p$e')),
        throwsA(_stateError('p1')),
      );

      await expectLater(
        Future.sync(
          () => [1, 2, 3].forEachAsync<int>(
            (e) => e == 2 ? Future<int>.error(StateError('p2')) : e,
          ),
        ),
        throwsA(_stateError('p2')),
      );

      // After switching to async, a sync throw fails the Future:
      await expectLater(
        Future.sync(
          () => [1, 2, 3].forEachAsync<int>(
            (e) => e == 1 ? Future.value(e) : throw StateError('p$e'),
          ),
        ),
        throwsA(_stateError('p2')),
      );
    });

    test('AsyncLoop mixing sync and async bodies, stopping early', () async {
      var visited = <int>[];
      var loop = AsyncLoop<int>(0, (i) => i < 10, (i) => i + 1, (i) {
        visited.add(i);
        if (i == 5) return Future.value(false);
        return i.isOdd ? Future.value(true) : true;
      });

      expect(await loop.run(), equals(5));
      expect(visited, equals([0, 1, 2, 3, 4, 5]));
    });

    test('AsyncLoop.forEach over a non-List iterable', () async {
      var seen = <int>[];
      var loop = AsyncLoop.forEach<int>({3, 4, 5}, (e) {
        seen.add(e);
        return Future.value(e != 4);
      });
      await loop.run();
      expect(seen, equals([3, 4]));
    });

    test(
      'AsyncSequenceLoop: sync stop, async completion, empty range',
      () async {
        expect(AsyncSequenceLoop(0, 5, (i) => i < 2).run(), equals(2));
        expect(
          await AsyncSequenceLoop(0, 5, (i) => Future.value(true)).run(),
          equals(5),
        );
        expect(AsyncSequenceLoop(5, 5, (i) => true).run(), equals(5));
      },
    );

    test('AsyncLoop body error propagates', () async {
      var loop = AsyncLoop<int>(
        0,
        (i) => i < 3,
        (i) => i + 1,
        (i) => i == 1 ? Future<bool>.error(StateError('l')) : true,
      );
      await expectLater(Future.sync(loop.run), throwsA(_stateError('l')));
    });
  });

  group('Expando putIfAbsentAsync', () {
    test('Expando<FutureOr> caches the resolved value', () async {
      var expando = Expando<FutureOr<int>>();
      var key = Object();
      var calls = 0;

      FutureOr<int> compute() {
        calls++;
        return Future.value(42);
      }

      var r1 = expando.putIfAbsentAsync(key, compute);
      var r2 = expando.putIfAbsentAsync(key, compute);
      expect(identical(r1, r2), isTrue);
      expect(await r1, equals(42));

      // After resolution the expando holds the plain value:
      expect(expando[key], equals(42));
      expect(expando.putIfAbsentAsync(key, compute), equals(42));
      expect(calls, equals(1));

      // A null key is never cached:
      expect(await expando.putIfAbsentAsync(null, compute), equals(42));
      expect(calls, equals(2));
    });

    test(
      'Expando<FutureOr> keeps a failed Future (current behaviour)',
      () async {
        var expando = Expando<FutureOr<int>>();
        var key = Object();
        var calls = 0;

        FutureOr<int> compute() {
          calls++;
          return Future<int>.error(StateError('x'));
        }

        await expectLater(
          Future.sync(() => expando.putIfAbsentAsync(key, compute)),
          throwsA(_stateError('x')),
        );
        // The failed Future stays cached: no recomputation.
        await expectLater(
          Future.sync(() => expando.putIfAbsentAsync(key, compute)),
          throwsA(_stateError('x')),
        );
        expect(calls, equals(1));
      },
    );

    test('Expando<Future> stores sync values as Futures', () async {
      var expando = Expando<Future<int>>();
      var key = Object();
      var r1 = expando.putIfAbsentAsync(key, () => 1);
      var r2 = expando.putIfAbsentAsync(key, () => 2);
      expect(identical(r1, r2), isTrue);
      expect(await r2, equals(1));
      expect(await expando.putIfAbsentAsync(null, () => 3), equals(3));
    });
  });

  group('Completer safe completion', () {
    test('completeSafe / completeErrorSafe only complete once', () async {
      var c = Completer<int>();
      expect(c.completeSafe(1), isTrue);
      expect(c.completeSafe(2), isFalse);
      expect(c.completeErrorSafe(StateError('x')), isFalse);
      expect(await c.future, equals(1));

      var c2 = Completer<int>();
      expect(c2.completeErrorSafe(StateError('y')), isTrue);
      expect(c2.completeSafe(3), isFalse);
      await expectLater(c2.future, throwsA(_stateError('y')));
    });
  });

  group('asyncRetry edge cases', () {
    test('sync success returns synchronously, without retrying', () {
      var calls = 0;
      var r = asyncRetry<int>(() {
        calls++;
        return 1;
      });
      expect(r, equals(1));
      expect(calls, equals(1));
    });

    test('negative maxRetries is treated as zero', () async {
      var calls = 0;
      var r = asyncRetry<int>(
        () {
          calls++;
          throw StateError('x');
        },
        maxRetries: -5,
        defaultValue: 7,
      );
      // No retry: the default value is returned synchronously.
      expect(r, equals(7));
      expect(calls, equals(1));
    });

    test('sync failure exhaustion with throwOnRetryExhaustion throws sync', () {
      expect(
        () => asyncRetry<int>(
          () => throw StateError('x'),
          maxRetries: 0,
          throwOnRetryExhaustion: true,
        ),
        throwsA(_stateError('x')),
      );
    });

    test('retries count and computeDelay arguments', () async {
      var attempts = 0;
      var onErrorRetries = <int>[];
      var delayRetries = <int>[];

      var r = await asyncRetry<int>(
        () {
          attempts++;
          if (attempts < 4) throw StateError('a$attempts');
          return attempts;
        },
        maxRetries: 5,
        computeDelay: (retry) {
          delayRetries.add(retry);
          return Duration.zero;
        },
        onError: (e, s, retries) {
          onErrorRetries.add(retries);
          return null;
        },
      );

      expect(r, equals(4));
      expect(onErrorRetries, equals([0, 1, 2]));
      expect(delayRetries, equals([0, 1, 2]));
    });

    test('computeDelay returning null falls back to retryDelay', () async {
      var attempts = 0;
      var r = await asyncRetry<int>(
        () {
          attempts++;
          if (attempts < 3) throw StateError('x');
          return attempts;
        },
        retryDelay: Duration.zero,
        computeDelay: (retry) => null,
      );
      expect(r, equals(3));
    });

    test('onError returning true retries beyond maxRetries', () async {
      var attempts = 0;
      var r = await asyncRetry<int>(
        () {
          attempts++;
          if (attempts < 6) return Future<int>.error(StateError('x'));
          return attempts;
        },
        maxRetries: 1,
        retryDelay: Duration.zero,
        onError: (e, s, retries) => true,
      );
      expect(r, equals(6));
      expect(attempts, equals(6));
    });

    test('onError returning false stops immediately', () async {
      var attempts = 0;
      var r = await asyncRetry<int>(
        () {
          attempts++;
          return Future<int>.error(StateError('x'));
        },
        maxRetries: 10,
        defaultValue: -1,
        retryDelay: Duration.zero,
        onError: (e, s, retries) => false,
      );
      expect(r, equals(-1));
      expect(attempts, equals(1));
    });

    test('the last error and its stack trace are rethrown', () async {
      var attempts = 0;
      StackTrace? lastStack;
      Object? error;
      StackTrace? stack;

      try {
        await asyncRetry<int>(
          () {
            attempts++;
            try {
              throw StateError('a$attempts');
            } catch (_, s) {
              lastStack = s;
              rethrow;
            }
          },
          maxRetries: 2,
          retryDelay: Duration.zero,
          throwOnRetryExhaustion: true,
        );
      } catch (e, s) {
        error = e;
        stack = s;
      }

      expect(attempts, equals(3));
      expect(error, _stateError('a3'));
      expect(stack.toString(), equals(lastStack.toString()));
    });

    test('mixed sync throw, async failure, then success', () async {
      var attempts = 0;
      var r = await asyncRetry<String>(() {
        attempts++;
        switch (attempts) {
          case 1:
            throw StateError('sync');
          case 2:
            return Future<String>.error(StateError('async'));
          default:
            return Future.value('ok');
        }
      }, retryDelay: Duration.zero);
      expect(r, equals('ok'));
      expect(attempts, equals(3));
    });

    test('a null result is a success (not retried)', () async {
      var attempts = 0;
      var r = await asyncRetry<int>(() {
        attempts++;
        return Future<int?>.value(null);
      }, defaultValue: 5);
      expect(r, isNull);
      expect(attempts, equals(1));
    });

    test('retry extensions forward arguments', () async {
      var calls = <List<Object?>>[];

      FutureOr<int> f3(int a, int b, int c) {
        calls.add([a, b, c]);
        if (calls.length < 2) throw StateError('x');
        return a + b + c;
      }

      expect(await f3.retry(1, 2, 3, retryDelay: Duration.zero), equals(6));
      expect(
        calls,
        equals([
          [1, 2, 3],
          [1, 2, 3],
        ]),
      );

      int named({required int a, int b = 0}) => a * 10 + b;
      expect(await named.retryWith<int>(named: {#a: 4, #b: 2}), equals(42));

      FutureOr<int> f0() => throw StateError('always');
      expect(
        await f0.retry(
          maxRetries: 1,
          retryDelay: Duration.zero,
          defaultValue: 9,
        ),
        equals(9),
      );
    });
  });

  group('ComputeOnce: many concurrent resolvers', () {
    test('all concurrent resolvers share a single computation', () async {
      var calls = 0;
      var completer = Completer<int>();
      var co = ComputeOnce<int>(() {
        calls++;
        return completer.future;
      }, resolve: false);

      var futures = <Future<int>>[
        for (var i = 0; i < 50; ++i) Future.value(co.resolve()),
        for (var i = 0; i < 50; ++i) co.resolveAsync(),
      ];

      expect(co.isResolving, isTrue);
      expect(co.isResolved, isFalse);

      completer.complete(7);
      var results = await Future.wait(futures);

      expect(calls, equals(1));
      expect(results, everyElement(equals(7)));
      expect(co.isResolved, isTrue);
      expect(co.isResolving, isFalse);
      // Once resolved, `resolve` is synchronous:
      expect(co.resolve(), equals(7));
    });

    test('concurrent resolvers with different error handling', () async {
      var calls = 0;
      var completer = Completer<int?>();
      var co = ComputeOnce<int?>(() {
        calls++;
        return completer.future;
      }, resolve: false);

      var throwing = [for (var i = 0; i < 20; ++i) co.resolveAsync()];
      var withValue = [
        for (var i = 0; i < 20; ++i)
          co.resolveAsync(throwError: false, onErrorValue: -1),
      ];
      var withHandler = [
        for (var i = 0; i < 20; ++i)
          Future.value(co.resolve(throwError: false, onError: (e, s) => i)),
      ];
      var nullDefault = co.resolveAsync(throwError: false);

      // Let the computation start (`resolveAsync` runs it in a `Future`),
      // so the completer's future has a listener when it fails:
      await _settle();
      expect(calls, equals(1));

      completer.completeError(StateError('boom'));

      for (var f in throwing) {
        await expectLater(f, throwsA(_stateError('boom')));
      }
      expect(await Future.wait(withValue), everyElement(equals(-1)));
      expect(
        await Future.wait(withHandler),
        equals(List.generate(20, (i) => i)),
      );
      expect(await nullDefault, isNull);
      expect(calls, equals(1));

      // The error is cached:
      expect(co.hasError, isTrue);
      expect(co.error?.error, _stateError('boom'));
      expect(() => co.resolve(), throwsA(_stateError('boom')));
      expect(co.resolve(throwError: false, onErrorValue: 3), equals(3));
      expect(await co.resolveAsync(throwError: false, onErrorValue: 4), 4);
      expect(calls, equals(1));
    });

    test('posCompute runs once for many concurrent resolvers', () async {
      var posCalls = 0;
      var completer = Completer<int>();
      var co = ComputeOnce<int>(
        () => completer.future,
        posCompute: (v, e, s) {
          posCalls++;
          return v! + 1;
        },
        resolve: false,
      );

      var futures = [for (var i = 0; i < 30; ++i) co.resolveAsync()];
      completer.complete(1);
      expect(await Future.wait(futures), everyElement(equals(2)));
      expect(posCalls, equals(1));
      expect(co.value, equals(2));
    });

    test(
      'then / whenComplete / whenResolved with concurrent callers',
      () async {
        var completer = Completer<int>();
        var co = ComputeOnce<int>(() => completer.future, resolve: false);

        var completes = 0;
        var a = co.then((v) => v * 2);
        var b = co.whenComplete(() => completes++);
        var c = co.whenResolved((v, e, s) => e == null ? 'ok:$v' : 'error');

        completer.complete(5);
        expect(await a, equals(10));
        expect(await b, equals(5));
        expect(await c, equals('ok:5'));
        expect(completes, equals(1));

        var failing = ComputeOnce<int>(
          () => Future.error(StateError('f')),
          resolve: false,
        );
        expect(
          await failing.whenResolved((v, e, s) => e is StateError ? 'e' : '?'),
          equals('e'),
        );
      },
    );

    test('toString reflects the state', () async {
      var completer = Completer<int>();
      var co = ComputeOnce<int>(() => completer.future, resolve: false);
      expect(co.toString(), startsWith('ComputeOnce<int>@'));
      var f = co.resolveAsync();
      expect(co.toString(), equals('ComputeOnce<int>[resolving...]'));
      completer.complete(1);
      await f;
      expect(co.toString(), equals('ComputeOnce<int><1>'));
    });

    test('resolveAsync on a cached error without fallback for a non-nullable '
        'type returns a failed Future', () async {
      var co = ComputeOnce<int>(() => throw StateError('x'), resolve: false);
      expect(() => co.resolve(), throwsA(_stateError('x')));
      expect(co.hasError, isTrue);

      // `resolve` reports the missing `onErrorValue` with a StateError:
      expect(() => co.resolve(throwError: false), throwsA(isA<StateError>()));

      // `resolveAsync` always returns a Future:
      Future<int>? f;
      expect(() => f = co.resolveAsync(throwError: false), returnsNormally);
      await expectLater(f, throwsA(isA<StateError>()));
    });
  });

  group('ComputeOnceCache: many concurrent resolvers', () {
    test('concurrent gets for the same key share one computation', () async {
      var cache = ComputeOnceCache<String, int>();
      var calls = 0;
      var completer = Completer<int>();

      FutureOr<int> call() {
        calls++;
        return completer.future;
      }

      var computers = [for (var i = 0; i < 100; ++i) cache.get('k', call)];
      expect(computers.toSet().length, equals(1));
      expect(cache.callsLength, equals(1));

      var futures = computers.map((c) => c.resolveAsync()).toList();
      completer.complete(9);
      expect(await Future.wait(futures), everyElement(equals(9)));
      expect(calls, equals(1));

      // With zero retention the entry is evicted after resolution:
      await _settle();
      expect(cache.callsLength, equals(0));

      // A new `get` computes again:
      var again = cache.get('k', () => 10);
      expect(await again.resolveAsync(), equals(10));
    });

    test('independent keys compute independently', () async {
      var cache = ComputeOnceCache<int, int>();
      var calls = <int, int>{};
      var completers = {for (var k = 0; k < 10; ++k) k: Completer<int>()};

      var futures = <Future<int>>[];
      for (var round = 0; round < 5; ++round) {
        for (var k = 0; k < 10; ++k) {
          futures.add(
            cache.get(k, () {
              calls[k] = (calls[k] ?? 0) + 1;
              return completers[k]!.future;
            }).resolveAsync(),
          );
        }
      }

      expect(cache.callsLength, equals(10));

      // Complete in reverse order:
      for (var k = 9; k >= 0; --k) {
        completers[k]!.complete(k * 100);
      }

      var results = await Future.wait(futures);
      expect(
        results,
        equals([
          for (var round = 0; round < 5; ++round)
            for (var k = 0; k < 10; ++k) k * 100,
        ]),
      );
      expect(calls.values, everyElement(equals(1)));
    });

    test('a failed computation is evicted, so the next get retries', () async {
      var cache = ComputeOnceCache<String, int>();
      var attempts = 0;

      FutureOr<int> call() {
        attempts++;
        if (attempts == 1) return Future<int>.error(StateError('first'));
        return attempts;
      }

      var concurrent = [for (var i = 0; i < 10; ++i) cache.get('k', call)];
      for (var c in concurrent) {
        await expectLater(c.resolveAsync(), throwsA(_stateError('first')));
      }
      await _settle();
      expect(cache.callsLength, equals(0));

      expect(await cache.get('k', call).resolveAsync(), equals(2));
      expect(attempts, equals(2));
    });

    test('get with resolve: false still starts the computation '
        '(current behaviour)', () async {
      var cache = ComputeOnceCache<String, int>();
      var calls = 0;
      var computer = cache.get('k', () {
        calls++;
        return 1;
      }, resolve: false);

      // The cache listens to the resolution (to evict the entry), which
      // triggers `resolveAsync`:
      expect(computer.isResolving, isTrue);
      await _settle();
      expect(calls, equals(1));
      expect(computer.isResolved, isTrue);
    });

    test('remove while in-flight does not evict a newer entry', () async {
      var cache = ComputeOnceCache<String, int>();
      var c1 = Completer<int>();
      var c2 = Completer<int>();

      var first = cache.get('k', () => c1.future);
      expect(cache.remove('k'), same(first));

      var second = cache.get('k', () => c2.future);
      expect(identical(first, second), isFalse);

      // The old computation resolving must not evict the new one:
      c1.complete(1);
      expect(await first.resolveAsync(), equals(1));
      await _settle();
      expect(cache.calls()['k'], same(second));

      c2.complete(2);
      expect(await second.resolveAsync(), equals(2));
      await _settle();
      expect(cache.callsLength, equals(0));
    });
  });

  group('ComputeOnceCachedIDs: many concurrent overlapping requests', () {
    test('overlapping in-flight requests share computations', () async {
      var cache = ComputeOnceCachedIDs<int, String>();
      var requested = <List<int>>[];
      var completers = <Completer<List<String>>>[];

      FutureOr<List<String>> call(List<int> ids) {
        requested.add(ids);
        var c = Completer<List<String>>();
        completers.add(c);
        return c.future.then((_) => ids.map((id) => 'v$id').toList());
      }

      var r1 = cache.computeIDs([3, 1, 2], call);
      var r2 = cache.computeIDs([2, 3, 4], call);
      var r3 = cache.computeIDs([5, 4, 3], call);
      var r4 = cache.computeIDs([1, 2, 3, 4, 5], call);

      // Computations start asynchronously (`resolve: true`):
      expect(requested, isEmpty);
      await _settle();

      expect(
        requested,
        equals([
          [1, 2, 3],
          [4],
          [5],
        ]),
      );

      for (var c in completers.reversed) {
        c.complete(const []);
      }

      expect(await r1, equals([(3, 'v3'), (1, 'v1'), (2, 'v2')]));
      expect(await r2, equals([(2, 'v2'), (3, 'v3'), (4, 'v4')]));
      expect(await r3, equals([(5, 'v5'), (4, 'v4'), (3, 'v3')]));
      expect(
        await r4,
        equals([(1, 'v1'), (2, 'v2'), (3, 'v3'), (4, 'v4'), (5, 'v5')]),
      );

      await _settle();
      expect(cache.callsLength, equals(0));
    });

    test('a failing batch fails every request that depends on it', () async {
      var cache = ComputeOnceCachedIDs<int, int>();
      var gate = Completer<void>();

      FutureOr<List<int>> call(List<int> ids) => gate.future.then((_) {
        if (ids.contains(2)) throw StateError('ids:$ids');
        return ids.map((e) => e * 10).toList();
      });

      var a = cache.computeIDs([1, 2], call);
      var b = cache.computeIDs([2, 3], call);
      var c = cache.computeIDs([4], call);

      gate.complete();

      await expectLater(
        Future.sync(() => a),
        throwsA(_stateError('ids:[1, 2]')),
      );
      await expectLater(
        Future.sync(() => b),
        throwsA(_stateError('ids:[1, 2]')),
      );
      expect(await c, equals([(4, 40)]));
    });
  });
}

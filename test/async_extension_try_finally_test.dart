import 'package:async_extension/async_extension.dart';
import 'package:test/test.dart';

/// How the `tryBlock` of [asyncTry] behaves.
enum _Body { syncValue, asyncValue, syncThrow, asyncThrow }

/// How `onFinally` behaves.
enum _Finally { ok, asyncOk, syncThrow, asyncThrow }

/// The observed outcome of an [asyncTry] call, normalizing sync/async returns
/// and sync/async errors.
class _Outcome {
  final Object? value;
  final Object? error;

  /// `true` if [asyncTry] threw synchronously (instead of returning a value
  /// or a [Future]).
  final bool threwSync;

  /// `true` if [asyncTry] returned a [Future].
  final bool returnedFuture;

  _Outcome(this.value, this.error, this.threwSync, this.returnedFuture);

  @override
  String toString() =>
      '_Outcome{value: $value, error: $error, threwSync: $threwSync, '
      'returnedFuture: $returnedFuture}';
}

Future<_Outcome> _run(FutureOr<int?> Function() f) async {
  FutureOr<int?> r;
  try {
    r = f();
  } catch (e) {
    return _Outcome(null, e, true, false);
  }

  if (r is Future<int?>) {
    try {
      return _Outcome(await r, null, false, true);
    } catch (e) {
      return _Outcome(null, e, false, true);
    }
  } else {
    return _Outcome(r, null, false, false);
  }
}

class _Scenario {
  final _Body body;
  final bool withThen;
  final bool withOnError;
  final _Finally fin;

  _Scenario(this.body, this.withThen, this.withOnError, this.fin);

  final calls = <String>[];
  final onErrorReceived = <Object>[];

  FutureOr<int?> tryBlock() {
    calls.add('try');
    switch (body) {
      case _Body.syncValue:
        return 10;
      case _Body.asyncValue:
        return Future.value(10);
      case _Body.syncThrow:
        throw StateError('body');
      case _Body.asyncThrow:
        return Future<int?>.error(StateError('body'));
    }
  }

  FutureOr<int?> then(int? r) {
    calls.add('then');
    return r! * 2;
  }

  int onError(Object e) {
    calls.add('onError');
    onErrorReceived.add(e);
    return -1;
  }

  FutureOr<void> onFinally() {
    calls.add('finally');
    switch (fin) {
      case _Finally.ok:
        return null;
      case _Finally.asyncOk:
        return Future.value();
      case _Finally.syncThrow:
        throw StateError('finally');
      case _Finally.asyncThrow:
        return Future<void>.error(StateError('finally'));
    }
  }

  FutureOr<int?> call() => asyncTry<int>(
    tryBlock,
    then: withThen ? then : null,
    onError: withOnError ? onError : null,
    onFinally: onFinally,
  );

  bool get bodyFails => body == _Body.syncThrow || body == _Body.asyncThrow;

  bool get finallyFails =>
      fin == _Finally.syncThrow || fin == _Finally.asyncThrow;

  @override
  String toString() =>
      'body: ${body.name}, then: $withThen, onError: $withOnError, '
      'onFinally: ${fin.name}';
}

void _throwFinally() => throw StateError('finally');

Matcher _stateError(String message) =>
    isA<StateError>().having((e) => e.message, 'message', equals(message));

void main() {
  group('Dart try/catch/finally reference semantics', () {
    // These tests document the language semantics `asyncTry` mirrors.

    int? dartTry({required bool bodyThrows, required bool withCatch}) {
      try {
        if (bodyThrows) throw StateError('body');
        return 10;
      } on StateError catch (_) {
        if (!withCatch) rethrow;
        return -1;
      } finally {
        _throwFinally();
      }
    }

    test('a throwing finally replaces a returned value', () {
      expect(
        () => dartTry(bodyThrows: false, withCatch: true),
        throwsA(_stateError('finally')),
      );
    });

    test('a throwing finally replaces a caught error result', () {
      expect(
        () => dartTry(bodyThrows: true, withCatch: true),
        throwsA(_stateError('finally')),
      );
    });

    test('a throwing finally replaces an uncaught error', () {
      expect(
        () => dartTry(bodyThrows: true, withCatch: false),
        throwsA(_stateError('finally')),
      );
    });

    test('an error thrown in finally is not seen by the catch clause', () {
      var caught = <Object>[];
      expect(() {
        try {
          return 10;
        } catch (e) {
          caught.add(e);
          return -1;
        } finally {
          _throwFinally();
        }
      }, throwsA(_stateError('finally')));
      expect(caught, isEmpty);
    });
  });

  group('asyncTry: onFinally full matrix', () {
    for (var body in _Body.values) {
      for (var withThen in [false, true]) {
        for (var withOnError in [false, true]) {
          for (var fin in _Finally.values) {
            final desc = _Scenario(body, withThen, withOnError, fin).toString();

            test(desc, () async {
              var scenario = _Scenario(body, withThen, withOnError, fin);
              var outcome = await _run(scenario.call);

              // `onFinally` is always called exactly once:
              expect(
                scenario.calls.where((c) => c == 'finally').length,
                equals(1),
                reason: 'calls: ${scenario.calls}',
              );
              // ... and always last:
              expect(scenario.calls.last, equals('finally'));

              // `then` is called only when the body succeeds:
              expect(
                scenario.calls.contains('then'),
                equals(withThen && !scenario.bodyFails),
              );

              // `onError` only ever sees the body's error, never the
              // `onFinally` error (as a Dart `catch` never sees the
              // `finally` error):
              for (var e in scenario.onErrorReceived) {
                expect(e, _stateError('body'));
              }
              expect(
                scenario.onErrorReceived.length,
                equals(withOnError && scenario.bodyFails ? 1 : 0),
              );

              if (scenario.finallyFails) {
                // A throwing `onFinally` always replaces the result:
                expect(
                  outcome.error,
                  _stateError('finally'),
                  reason: outcome.toString(),
                );
              } else if (scenario.bodyFails) {
                if (withOnError) {
                  expect(outcome.error, isNull, reason: outcome.toString());
                  expect(outcome.value, equals(-1));
                } else {
                  expect(outcome.error, _stateError('body'));
                }
              } else {
                expect(outcome.error, isNull, reason: outcome.toString());
                expect(outcome.value, equals(withThen ? 20 : 10));
              }

              // Sync inputs with a sync `onFinally` stay synchronous:
              var allSync =
                  (body == _Body.syncValue || body == _Body.syncThrow) &&
                  (fin == _Finally.ok || fin == _Finally.syncThrow);
              if (allSync) {
                expect(outcome.returnedFuture, isFalse);
              }
            });
          }
        }
      }
    }
  });

  group('asyncTry: onFinally throwing with throwing handlers', () {
    test('then throws sync and onFinally throws sync', () async {
      var errors = <Object>[];
      var outcome = await _run(
        () => asyncTry<int>(
          () => 1,
          then: (_) => throw StateError('then'),
          onError: (Object e) {
            errors.add(e);
            return -1;
          },
          onFinally: () => throw StateError('finally'),
        ),
      );
      expect(outcome.threwSync, isTrue);
      expect(outcome.error, _stateError('finally'));
      expect(errors, [_stateError('then')]);
    });

    test('then fails async and onFinally throws sync', () async {
      var errors = <Object>[];
      var outcome = await _run(
        () => asyncTry<int>(
          () => Future.value(1),
          then: (_) => Future<int?>.error(StateError('then')),
          onError: (Object e) {
            errors.add(e);
            return -1;
          },
          onFinally: () => throw StateError('finally'),
        ),
      );
      expect(outcome.returnedFuture, isTrue);
      expect(outcome.error, _stateError('finally'));
      expect(errors, [_stateError('then')]);
    });

    test('onError rethrows and onFinally throws sync', () async {
      var outcome = await _run(
        () => asyncTry<int>(
          () => throw StateError('body'),
          onError: (Object e) => throw e,
          onFinally: () => throw StateError('finally'),
        ),
      );
      expect(outcome.error, _stateError('finally'));
    });

    test('async onError and onFinally throws sync', () async {
      var outcome = await _run(
        () => asyncTry<int>(
          () => throw StateError('body'),
          onError: (Object e) => Future.value(-1),
          onFinally: () => throw StateError('finally'),
        ),
      );
      expect(outcome.returnedFuture, isTrue);
      expect(outcome.error, _stateError('finally'));
    });

    test('onFinally error keeps its stack trace', () async {
      StackTrace? finallyStack;
      Object? error;
      StackTrace? stack;
      try {
        asyncTry<int>(
          () => 1,
          then: (r) => r,
          onError: (Object e) => -1,
          onFinally: () {
            try {
              throw StateError('finally');
            } catch (_, s) {
              finallyStack = s;
              rethrow;
            }
          },
        );
      } catch (e, s) {
        error = e;
        stack = s;
      }
      expect(error, _stateError('finally'));
      expect(stack.toString(), equals(finallyStack.toString()));
    });
  });

  group('asyncTry: without onFinally', () {
    for (var body in _Body.values) {
      for (var withThen in [false, true]) {
        for (var withOnError in [false, true]) {
          test(
            'body: ${body.name}, then: $withThen, onError: $withOnError',
            () async {
              var scenario = _Scenario(
                body,
                withThen,
                withOnError,
                _Finally.ok,
              );
              var outcome = await _run(
                () => asyncTry<int>(
                  scenario.tryBlock,
                  then: withThen ? scenario.then : null,
                  onError: withOnError ? scenario.onError : null,
                ),
              );

              if (scenario.bodyFails) {
                if (withOnError) {
                  expect(outcome.value, equals(-1));
                } else {
                  expect(outcome.error, _stateError('body'));
                }
              } else {
                expect(outcome.value, equals(withThen ? 20 : 10));
              }

              if (body == _Body.syncValue) {
                expect(outcome.returnedFuture, isFalse);
              } else if (body == _Body.syncThrow) {
                // Sync errors are either handled synchronously by `onError`
                // or rethrown synchronously.
                expect(outcome.returnedFuture, isFalse);
                expect(outcome.threwSync, equals(!withOnError));
              } else {
                expect(outcome.returnedFuture, isTrue);
              }
            },
          );
        }
      }
    }
  });
}

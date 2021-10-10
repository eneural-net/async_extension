import 'package:async_extension/async_extension.dart';

// All the `asyncTry` below are similar,
// returning the value `246` and printing `Finally`.
void main() async {
  var r1 = asyncTry<int>(
    // A normal `sync` block, returning a value:
    () => 123,
    then: (n) => n! * 2,
    onFinally: () => print('Finally 1'),
  );

  print(r1);

  var r2 = await asyncTry<int>(
    // An `async` block, returning a `Future`:
    () async => 123,
    then: (n) => n! * 2,
    onFinally: () => print('Finally 2'),
  );

  print(r2);

  var r3 = await asyncTry<int>(
    // An `async` block, returning a delayed `Future`:
    () => Future.delayed(Duration(milliseconds: 100), () => 123),
    // `then` also can be `async`:
    then: (n) => Future.delayed(Duration(milliseconds: 100), () => n! * 2),
    // `onFinally` also can be `async`:
    onFinally: () => Future.delayed(
        Duration(milliseconds: 100),
        () => print(
            'Finally 3')), // `asyncTry` only returns after `onFinally` is executed.
  );

  print(r3);

  var errors = [];

  var r4 = await asyncTry<int>(
    // Force an error in the main block:
    () => throw StateError('Force error'),
    // Handle errors:
    onError: (e) {
      errors.add(e); // Catches the error.
      return -246; // Returns value `-246` on error.
    },
    // `asyncTry` only returns after `onFinally` is executed:
    onFinally: () => Future.microtask(() => print('Finally 4')),
  );

  print(r4);

  print('Caught errors: $errors');
}

// ---------------------------------------------
// OUTPUT:
// ---------------------------------------------
// Finally 1
// 246
// Finally 2
// 246
// Finally 3
// 246
// Finally 4
// -246
// Caught errors: [Bad state: Force error]
//

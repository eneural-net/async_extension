import 'package:async_extension/async_extension.dart';

/// A generic computation that can be sync or async.
abstract class Computation {
  FutureOr<int> compute(int a, int b);
}

/// A sync computation: returns an [int] (won't create [Future] instances).
class ComputationSync extends Computation {
  @override
  int compute(int a, int b) {
    return a + b;
  }
}

/// A async computation: returns a [Future].
class ComputationAsync extends Computation {
  @override
  Future<int> compute(int a, int b) {
    return Future.delayed(Duration(milliseconds: 10), () => a + b);
  }
}

/// Using sync and async [Computation] without declare an `async` method:
///
/// - Note that when a method is declared as `async` a [Future] is always
///   created and scheduled. With `async_extension` and `resolve*` methods
///   you can avoid creating of Future
FutureOr<int> doComputation() {
  var compute1 = ComputationSync();
  var compute2 = ComputationAsync();

  var c1 = compute1.compute(100, 10);
  var c2 = compute2.compute(200, 20);

  // Resolve and map without generate a `Future`:
  var n1 = c1.resolveMapped((n) => n * 10);

  // Resolve and map with a `Future`:
  var n2 = c2.resolveMapped((n) => n * 10);

  // Resolved (n1 is an `int`):
  print('Resolved: ${n1.isResolved} > n1: $n1');

  // NOT resolved (n1 is a `Future<int>`):
  print('Resolved: ${n2.isResolved} > n2: $n2');

  n1.onResolve((n) => print('onResolve n1: $n'));
  n2.onResolve((n) => print('onResolve n2: $n'));

  // All computations:
  var computations = [n1, n2];

  // Reduce all computations (sum all):
  return computations.resolveAllReduced((a, b) => a + b);
}

void main() async {
  // Call `doComputation` that can return an `int` or a  `Future<int>`:
  var computation = doComputation();

  computation.onResolve((result) {
    print('Result by onResolve: $result');
  });

  var result = await computation;

  print('Result by await: $result');
}

// -----------------------
// OUTPUT:
// -----------------------
// Resolved: true > n1: 1100
// Resolved: false > n2: Instance of 'Future<int>'
// onResolve n1: 1100
// onResolve n2: 2200
// Result by onResolve: 3300
// Result by await: 3300
//

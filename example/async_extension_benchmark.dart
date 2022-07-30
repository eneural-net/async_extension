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
  Future<int> compute(int a, int b) async {
    return a + b;
  }
}

/// A benchmark result.
class Benchmark {
  String type;
  Computation computation;
  int sum;
  int iterations;
  Duration time;

  Benchmark(this.type, this.computation, this.sum, this.iterations, this.time);

  double get speed => iterations / (time.inMilliseconds / 1000);

  @override
  String toString() {
    return 'Benchmark[$type:${computation.runtimeType}]{ sum: $sum, iterations: $iterations, time: ${time.inMilliseconds}ms , speed: $speed iter./s }';
  }
}

/// Benchmark using a normal Dart `async` method:
Future<Benchmark> doBenchmarkAwait(
    Computation computation, int iterations) async {
  var init = DateTime.now();

  var results = <Future<int>>[];

  for (var i = 0; i < iterations; ++i) {
    var result = computation.compute(i, i);
    results.add(result.asFuture);
  }

  var sum =
      (await Future.wait(results)).reduce((value, element) => value + element);

  var end = DateTime.now();
  var time = Duration(
      milliseconds: end.millisecondsSinceEpoch - init.millisecondsSinceEpoch);

  return Benchmark('await', computation, sum, iterations, time);
}

/// Benchmark using a method optimized with `async_extension`:
FutureOr<Benchmark> doBenchmarkOptimized(
    Computation computation, int iterations) {
  var init = DateTime.now();

  var results = <FutureOr<int>>[];

  for (var i = 0; i < iterations; ++i) {
    var result = computation.compute(i, i);
    results.add(result);
  }

  var sum = results.resolveAllReduced((value, element) => value + element);

  return sum.resolveMapped((val) {
    var end = DateTime.now();
    var time = Duration(
        milliseconds: end.millisecondsSinceEpoch - init.millisecondsSinceEpoch);

    return Benchmark('optimized', computation, val, iterations, time);
  });
}

void main() async {
  var iterations = 1000000;

  // Run 10 sessions of benchmark to allow VM warm up:
  for (var session = 0; session < 10; ++session) {
    var benchmarkAwaitSync =
        await doBenchmarkAwait(ComputationSync(), iterations);
    var benchmarkAwaitAsync =
        await doBenchmarkAwait(ComputationAsync(), iterations);

    var benchmarkOptimizedSync =
        await doBenchmarkOptimized(ComputationSync(), iterations);
    var benchmarkOptimizedAsync =
        await doBenchmarkOptimized(ComputationAsync(), iterations);

    print('----------------------------------------------------');
    print('session[$session]> $benchmarkAwaitSync');
    print('session[$session]> $benchmarkAwaitAsync');
    print('session[$session]> $benchmarkOptimizedSync');
    print('session[$session]> $benchmarkOptimizedAsync');
  }
}

//-------------------------------------------------
// OUTPUT
//-------------------------------------------------
// session[9]> Benchmark[await:ComputationSync]{ sum: 999999000000, iterations: 1000000, time: 778ms , speed: 1285347.0437017994 iter./s }
// session[9]> Benchmark[await:ComputationAsync]{ sum: 999999000000, iterations: 1000000, time: 899ms , speed: 1112347.0522803115 iter./s }
// session[9]> Benchmark[optimized:ComputationSync]{ sum: 999999000000, iterations: 1000000, time: 28ms , speed: 35714285.71428572 iter./s }
// session[9]> Benchmark[optimized:ComputationAsync]{ sum: 999999000000, iterations: 1000000, time: 810ms , speed: 1234567.9012345679 iter./s }
//

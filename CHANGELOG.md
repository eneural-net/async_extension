## 1.0.5

- The package now exports `dart:async`.
- New extensions:
  - resolveWithValue
  - resolveAllWithValue
  - resolveAllThen
  - allAsList
- Optimized some resolutions
  - Now ensures that iterables won't be iterated more than once.
  - Ensures that `List` and `Set` won't be converted to `List` when not needed.

## 1.0.4

- Added `AsyncLoop` and `AsyncSequenceLoop`. 

## 1.0.3

- Added `FutureOr.then`.

## 1.0.2

- Added `resolveBoth` for `FutureOr` and `Future`.
- Add `Future` and `FutureOr` arithmetic operators.
- Added Benchmarks:
  - `async_extension_benchmark.dart`
  - `async_extension_benchmark2.dart`

## 1.0.1

- Adjusted `pubspec.yaml` description.
- Added `FOSSA` scan and badges.

## 1.0.0

- Initial version.

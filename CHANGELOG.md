## 1.2.16

- `async_extension`:
  - Added export of `src/async_extension_compute_once.dart` to library.
  - New `ComputeOnce`.

- Dependencies:
  - Updated `test` dependency from ^1.26.0 to ^1.26.3.
  - Updated `coverage` dependency from ^1.13.1 to ^1.15.0.

- Update GitHub Actions to use checkout@v6 and codecov-action@v5.

## 1.2.15

- New `FunctionArgs0Extension`, `FunctionArgs1Extension`, `FunctionArgs2Extension`:
  - Added `tryCall`, `tryCallThen` and `asFutureOr`.

- test: ^1.26.0
- dependency_validator: ^4.1.3
- coverage: ^1.13.1

## 1.2.14

- Added `Function` extension: `retry` and `retryWith`.

## 1.2.13

- Added `asyncRetry`.

- Improved `asyncTry` documentation.

- lints: ^4.0.0
- test: ^1.25.13
- dependency_validator: ^4.1.2
- coverage: ^1.11.1

## 1.2.12

- New `IterableMapEntryFutureValueExtension`:
  - Added `resolveAllValues`.

- New `IterableMapEntryFutureKeyExtension`:
  - Added `resolveAllKeys`.

- New `IterableMapEntryFutureExtension`:
  - Added `resolveAllEntries`.

## 1.2.11

- New `IterableAsyncExtension`:
  - Added `forEachAsync`.

## 1.2.10

- New `CompleterExtension`:
  - Added `completeSafe`, `completeErrorSafe`.

## 1.2.9

- `onErrorReturn`: added optional parameter `onError`.
- `nullOnError`: added optional parameters `onError` and `onErrorOrNull`.

## 1.2.8

- New `AsyncExtensionErrorLogger` and `defaultAsyncExtensionErrorLogger`:

- New `FutureOnErrorExtension`:
  - `logError`
  - `onErrorReturn`
  - `nullOnError`

- `FutureNonNullOnErrorExtension`:
  - `onComplete`

- `FutureNullableOnErrorExtension`:
  - `onComplete`
  - `onCompleteNotNull`

- lints: ^3.0.0

## 1.2.7

- `IterableFutureOrNullableExtension`:
  - `whereFutureNullable`, `selectFuturesNullable`: return `Future<T?>` for consistency with "Nullable" suffix.
  - `waitFuturesNullable`: return `FutureOr<List<T?>>` for consistency with "Nullable" suffix.

## 1.2.6

- New `extension IterableFutureOrNullableExtension<T> on Iterable<FutureOr<T>?>`:
  - `whereFutureNullable`, `selectFuturesNullable`, `asFuturesNullable` and `waitFuturesNullable`.

- test: ^1.25.2
- dependency_validator: ^3.2.3
- coverage: ^1.7.2

## 1.2.5

- New `ExpandoFutureExtension` and `ExpandoFutureOrExtension`:
  - `putIfAbsentAsync`

## 1.2.4

- New `FutureOrIterableNullableExtension` and `FutureIterableNullableExtension`.

## 1.2.3

- New `FutureNullableExtension` and `FutureOrNullableExtension`:
  - `orElseAsync` and `orElseGeAsync`.

## 1.2.2

- `FutureOrIterableExtension` and `FutureIterableExtension`.
  - Use suffix `Async` to avoid extension overwrite issues. 

## 1.2.1

- New `FutureOrIterableExtension` and `FutureIterableExtension`.
- test: ^1.24.6

## 1.2.0

- sdk: '>=3.0.0 <4.0.0'
- lints: ^2.1.1
- test: ^1.24.4

## 1.1.1

- Optimize:
  - `resolveMapped`, `resolveAllValuesNullable`.
  - `resolveAllValues`, `resolveAllValuesNullable`, `resolveAllKeys`, `resolveAllEntries`.

- sdk: '>=2.18.0 <4.0.0'
- test: ^1.24.3

## 1.1.0

- Fix GitHub CI badge.
- sdk: '>=2.18.0 <3.0.0'
- lints: ^2.0.1
- test: ^1.23.0
- coverage: ^1.6.3 

## 1.0.12

- `asyncTry`:
  - Fix issue when `onError` returns a `Future` with a type different from the main function.

## 1.0.11

- `AsyncLoop`:
  - Added `AsyncLoop.forEach`.
  - Optimize `_runBody` to avoid recursion.
- `asyncTry`:
  - Fix behavior when an error is rethrown inside an `onError` block.
  - Fix behavior when an error is thrown inside an `onFinally` block.
  - Ensures the same behavior of standard Dart `try/catch` blocks.

## 1.0.10

- `FutureExtension` and `FutureOrExtension`:
  - Renamed `type` getter to `genericType` to avoid issues with nullable variables.
- Update GitHub CI.
- lints: ^2.0.0
- test: ^1.17.12
- dependency_validator: ^3.2.2
- coverage: ^1.0.4

## 1.0.9

- `whereNotNull` renamed to `whereNotNullSync` to avoid conflict with package `collection`.

## 1.0.8

- Added `asyncTry`:
  - Executes a `block` in a `try`, `then`, `catch` and `finally` execution chain.
- Using standard Dart coverage.
- coverage: ^1.0.3

## 1.0.7

- New extension methods:
  - `resolveOther`
  - `resolveAllNullable`
- New `Map` extension methods:
  - `resolveAllKeys`
  - `resolveAllEntries`
  - `resolveAllValues`
  - `resolveAllValuesNullable`

## 1.0.6

- New extension methods for nullable types:
  - `whereNotNull`
  - `whereNotNullResolved`
  - `resolveAllNotNull`
- Fixed `isResolved` detection for when `T` is `Object` or `dynamic`.

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

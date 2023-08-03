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

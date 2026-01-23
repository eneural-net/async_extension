## 1.2.20

- `ComputeOnce`:
  - Renamed `ComputeOnceCall` to `ComputeCall`.
  - Added `PosComputeCall` callback invoked after computation completes, receiving success or error results.
  - Added `posCompute` field to invoke post-computation callback.
  - Updated `resolve` and `resolveAsync` to apply `posCompute` on success or error.

- `TimedComputeOnce`:
  - Added support for `posCompute` callback.

- Added `ComputeOnceCache`:
  - Caches `TimedComputeOnce` instances by key.
  - Supports retention duration for cached entries with automatic eviction.
  - Provides `get` method to retrieve or create cached computations.

- Added `ComputeOnceCachedIDs`:
  - Extends `ComputeOnceCache` for batched computations by ID sets.
  - Supports ID ordering, hashing, and deduplication.
  - Shares in-flight computations for overlapping ID sets.
  - Provides `getByIDs` to get computations for subsets of IDs.
  - Provides `computeIDs` to compute and merge results for requested IDs, preserving order.

- Added `ComputeIDs`:
  - Represents an ordered, comparable, and hashable set of IDs.
  - Supports binary search, intersection, equality, and hashing.

- Added extensions:
  - `IterableComputeOnceExtension` for resolving multiple `ComputeOnce` instances.
  - `MapComputeIDsExtension` for resolving maps of `TimedComputeOnce` keyed by `ComputeIDs`.
  - `ListIdValuePairExtension` for binary searching `(ID, value)` pairs sorted by ID.

- Typedefs:
  - `ComputeCallIDs` for batched ID computations.
  - `ComputeIDCompare` and `ComputeIDHash` for ID comparison and hashing.

## 1.2.19

- `FunctionArgs0Extension`, `FunctionArgs1Extension`, `FunctionArgs2Extension`:
  - `tryCall`: updated to catch errors from synchronous or asynchronous results and apply `onError` via `Future.catchError` if the result is a `Future`.
  
- `ComputeOnce<V>`:
  - Constructor:
    - Added static helper `_resolveCall` to widen callbacks returning `Future<Never>` to `FutureOr<V>`.
    - Wrap `_call` with `_resolveCall` to fix `Future<Never>` callbacks.
  - Added `isResolving` getter to indicate if computation is in progress.
  - Enhanced `resolve` method:
    - Added parameters `throwError`, `onError`, and `onErrorValue` to control error handling behavior.
    - Supports returning fallback values or invoking error handlers instead of always throwing.
    - Calls `onCompute` callback on completion with value or error.
  - Enhanced `resolveAsync` method:
    - Added parameters `throwError`, `onError`, and `onErrorValue` for asynchronous error handling.
    - Calls `onCompute` callback on completion.
  - Added `onCompute` callback method invoked once computation completes.
  - Added `className` getter and improved `toString` to reflect current state (resolving, resolved with value, or error).
  
- Added `TimedComputeOnce<V>` subclass:
  - Records the timestamp when computation resolves (success or failure).
  - Provides `resolvedAt` timestamp and `elapsedTime` since resolution.
  - Overrides `onCompute` to set resolution time.
  - Overrides `className` for identification.

## 1.2.18

- `FutureExtension`:
  - Added method `whenResolved` to invoke a callback on future resolution (success or error) and map the outcome to a new result without automatically rethrowing errors.

- `ComputeOnce`:
  - Added method `whenComplete` to register a callback executed when resolution completes, regardless of success or failure.
  - Added method `whenResolved` to invoke a callback on resolution (success or error) and map the outcome to a new result, delegating to `resolveAsync` and `Future.whenResolved`.

## 1.2.17

- `ComputeOnce`:
  - Added typedef `ComputeOnceCall<V>` for the computation callback signature.
  - Changed `_call` field type to nullable `ComputeOnceCall<V>?` and clear it after computation completes to release references and prevent re-invocation.

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

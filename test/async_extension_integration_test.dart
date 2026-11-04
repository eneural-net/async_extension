import 'package:async_extension/async_extension.dart';
import 'package:test/test.dart';

/// A fake backend whose responses are controlled by the test.
class _Backend {
  final calls = <String>[];

  /// Number of initial failures for each key.
  final Map<String, int> failuresByKey;

  /// Keys answered synchronously (e.g. from a local cache).
  final Set<String> syncKeys;

  _Backend({this.failuresByKey = const {}, this.syncKeys = const {}});

  int openConnections = 0;
  int maxOpenConnections = 0;

  FutureOr<String> fetch(String key) {
    calls.add(key);
    var remainingFailures = failuresByKey[key] ?? 0;
    if (remainingFailures > 0) {
      failuresByKey[key] = remainingFailures - 1;
      return Future.error(StateError('unavailable: $key'));
    }
    if (syncKeys.contains(key)) return 'value:$key';
    return Future.value('value:$key');
  }

  void open() {
    openConnections++;
    if (openConnections > maxOpenConnections) {
      maxOpenConnections = openConnections;
    }
  }

  FutureOr<void> close() {
    openConnections--;
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('Integration: cached + retried + guarded fetch', () {
    FutureOr<String?> guardedFetch(_Backend backend, String key) {
      backend.open();
      return asyncTry<String>(
        () => asyncRetry<String>(
          () => backend.fetch(key),
          maxRetries: 3,
          retryDelay: Duration.zero,
          throwOnRetryExhaustion: true,
        ),
        then: (v) => v!.toUpperCase(),
        onError: (Object e) => 'fallback:$key',
        onFinally: backend.close,
      );
    }

    test('concurrent requests coalesce, retry and always release', () async {
      var backend = _Backend(failuresByKey: {'a': 2, 'b': 10});
      var cache = ComputeOnceCache<String, String?>();

      Future<String?> request(String key) =>
          cache.get(key, () => guardedFetch(backend, key)).resolveAsync();

      var results = await Future.wait([
        for (var i = 0; i < 20; ++i) request('a'),
        for (var i = 0; i < 20; ++i) request('b'),
        for (var i = 0; i < 20; ++i) request('c'),
      ]);

      expect(results.sublist(0, 20), everyElement(equals('VALUE:A')));
      // 'b' exhausts its retries, so `onError` provides a fallback:
      expect(results.sublist(20, 40), everyElement(equals('fallback:b')));
      expect(results.sublist(40), everyElement(equals('VALUE:C')));

      // One computation per key; 'a' failed twice, 'b' 4 times (1 + 3 retries):
      expect(backend.calls.where((k) => k == 'a').length, equals(3));
      expect(backend.calls.where((k) => k == 'b').length, equals(4));
      expect(backend.calls.where((k) => k == 'c').length, equals(1));

      // Every opened connection was closed:
      expect(backend.openConnections, equals(0));
      expect(backend.maxOpenConnections, equals(3));

      await _settle();
      expect(cache.callsLength, equals(0));
    });

    test('sync cache hits stay synchronous through the pipeline', () {
      var backend = _Backend(syncKeys: {'x'});
      var r = guardedFetch(backend, 'x');
      expect(r, equals('VALUE:X'));
      expect(backend.openConnections, equals(0));
    });

    test(
      'a failing cleanup propagates through cache and retry layers',
      () async {
        var backend = _Backend();
        var cache = ComputeOnceCache<String, String?>();
        var attempts = 0;

        FutureOr<String?> fetchWithBrokenCleanup() => asyncTry<String>(
          () => backend.fetch('k'),
          then: (v) => v,
          onError: (Object e) => 'fallback',
          onFinally: () {
            attempts++;
            throw StateError('cleanup failed');
          },
        );

        var futures = [
          for (var i = 0; i < 5; ++i)
            cache.get('k', fetchWithBrokenCleanup).resolveAsync(),
        ];

        for (var f in futures) {
          await expectLater(
            f,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                'cleanup failed',
              ),
            ),
          );
        }
        expect(attempts, equals(1));
      },
    );
  });

  group('Integration: batched loader', () {
    test('overlapping batches, merged results and sequential '
        'post-processing', () async {
      var batches = <List<int>>[];
      var loader = ComputeOnceCachedIDs<int, String>();

      Future<List<String>> loadUsers(List<int> ids) async {
        batches.add(ids);
        await _settle();
        return ids.map((id) => 'user$id').toList();
      }

      // Several screens request overlapping users at the same time:
      var screenA = loader.computeIDs([1, 2, 3], loadUsers);
      var screenB = loader.computeIDs([3, 4], loadUsers);
      var screenC = loader.computeIDs([4, 1, 5], loadUsers);

      var all = await [screenA, screenB, screenC].resolveAll();

      expect(
        batches,
        equals([
          [1, 2, 3],
          [4],
          [5],
        ]),
      );

      // Post-process each screen sequentially, mixing sync and async steps:
      var log = <String>[];
      var rendered = await all.forEachAsync((screen) {
        var names = screen.map((p) => p.$2).toList();
        log.add('render ${names.length}');
        return names.length > 2
            ? Future.value(names.join('|'))
            : names.join('|');
      });

      expect(
        rendered,
        equals(['user1|user2|user3', 'user3|user4', 'user4|user1|user5']),
      );
      expect(log, equals(['render 3', 'render 2', 'render 3']));
    });

    test('profile assembly from a map of mixed FutureOr sources', () async {
      var backend = _Backend(syncKeys: {'name'});

      var profile = <String, FutureOr<String>>{
        'name': backend.fetch('name'),
        'avatar': backend.fetch('avatar'),
        'bio': backend.fetch('bio'),
      };

      var resolved = await profile.resolveAllValues();
      expect(resolved.keys.toList(), equals(['name', 'avatar', 'bio']));
      expect(resolved['name'], equals('value:name'));

      var summary = await resolved.values
          .map((v) => v.length)
          .toList()
          .resolveAllReduced((a, b) => a + b);
      // 'value:name' (10) + 'value:avatar' (12) + 'value:bio' (9):
      expect(summary, equals(31));
    });
  });

  group('Integration: paginated loop', () {
    test(
      'AsyncLoop pages until an empty page, with sync and async pages',
      () async {
        var pages = <int, List<int>>{
          0: [1, 2],
          1: [3],
          2: [4, 5, 6],
          3: [],
        };

        var collected = <int>[];
        var requestedPages = <int>[];

        FutureOr<List<int>> fetchPage(int page) {
          requestedPages.add(page);
          var items = pages[page] ?? const <int>[];
          // Even pages come from a sync cache, odd pages from the network:
          return page.isEven ? items : Future.value(items);
        }

        var loop = AsyncLoop<int>(0, (i) => true, (i) => i + 1, (page) {
          return fetchPage(page).resolveMapped((items) {
            collected.addAll(items);
            return items.isNotEmpty;
          });
        });

        var lastPage = await loop.run();

        expect(lastPage, equals(3));
        expect(requestedPages, equals([0, 1, 2, 3]));
        expect(collected, equals([1, 2, 3, 4, 5, 6]));
      },
    );

    test(
      'a failing page aborts the loop and is retried by the caller',
      () async {
        var failures = 1;
        var collected = <int>[];

        FutureOr<int> runLoop() {
          collected.clear();
          return AsyncSequenceLoop(0, 4, (i) {
            if (i == 2 && failures-- > 0) {
              return Future<bool>.error(StateError('page $i'));
            }
            collected.add(i);
            return Future.value(true);
          }).run();
        }

        var r = await asyncRetry<int>(runLoop, retryDelay: Duration.zero);
        expect(r, equals(4));
        expect(collected, equals([0, 1, 2, 3]));
      },
    );
  });

  group('Integration: ComputeOnce around a retried computation', () {
    test('exhausted retries are cached and shared by concurrent '
        'resolvers', () async {
      var attempts = 0;
      var co = ComputeOnce<int?>(
        () => asyncRetry<int>(
          () {
            attempts++;
            return Future<int>.error(StateError('down'));
          },
          maxRetries: 2,
          retryDelay: Duration.zero,
          throwOnRetryExhaustion: true,
        ),
        resolve: false,
      );

      var results = await Future.wait([
        for (var i = 0; i < 10; ++i)
          co.resolveAsync(throwError: false, onErrorValue: -1),
      ]);

      expect(results, everyElement(equals(-1)));
      expect(attempts, equals(3));
      expect(co.hasError, isTrue);

      // Later callers get the cached error without recomputing:
      expect(() => co.resolve(), throwsStateError);
      expect(attempts, equals(3));
    });
  });
}

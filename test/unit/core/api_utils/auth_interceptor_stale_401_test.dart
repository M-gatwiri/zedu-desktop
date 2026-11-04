import 'dart:async';

import '../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';

class _MockStorage extends Mock implements SecureStorageService {}

/// Answers every request with a 401, but only once [release] completes.
class _SlowUnauthorizedAdapter implements HttpClientAdapter {
  final release = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await release.future;
    return ResponseBody.fromString('{}', 401);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'a late 401 for a request sent with an old token does not end the new session',
    () async {
      final storage = _MockStorage();
      var current = 'old-token';
      when(() => storage.getAccessToken()).thenAnswer((_) async => current);
      when(() => storage.deleteAccessToken()).thenAnswer((_) async {
        current = '';
      });

      var unauthorizedCalls = 0;
      final adapter = _SlowUnauthorizedAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          AuthInterceptor(storage: storage)
            ..onUnauthorized = () => unauthorizedCalls++,
        );

      // A request leaves the app carrying the old session's token...
      final request = dio.get<dynamic>('/chat/history');
      await pumpEventQueue();

      // ...the user signs out and signs in again (new token stored)...
      current = 'new-token';

      // ...and then the old request's 401 arrives.
      adapter.release.complete();
      await expectLater(request, throwsA(isA<DioException>()));

      expect(
        current,
        'new-token',
        reason: "the new session's token must survive the old request's 401",
      );
      expect(
        unauthorizedCalls,
        0,
        reason: 'the new session must stay signed in',
      );
    },
  );

  test('a 401 for the current token still clears it and signs out', () async {
    final storage = _MockStorage();
    var current = 'token';
    when(() => storage.getAccessToken()).thenAnswer((_) async => current);
    when(() => storage.deleteAccessToken()).thenAnswer((_) async {
      current = '';
    });

    var unauthorizedCalls = 0;
    final adapter = _SlowUnauthorizedAdapter()..release.complete();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(storage: storage)
          ..onUnauthorized = () => unauthorizedCalls++,
      );

    await expectLater(
      dio.get<dynamic>('/chat/history'),
      throwsA(isA<DioException>()),
    );

    expect(current, '');
    expect(unauthorizedCalls, 1);
  });

  test('a 401 for a request sent without a token still signs out', () async {
    final storage = _MockStorage();
    when(() => storage.getAccessToken()).thenAnswer((_) async => null);
    when(() => storage.deleteAccessToken()).thenAnswer((_) async {});

    var unauthorizedCalls = 0;
    final adapter = _SlowUnauthorizedAdapter()..release.complete();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(storage: storage)
          ..onUnauthorized = () => unauthorizedCalls++,
      );

    await expectLater(
      dio.get<dynamic>('/chat/history'),
      throwsA(isA<DioException>()),
    );

    verify(() => storage.deleteAccessToken()).called(1);
    expect(unauthorizedCalls, 1);
  });
}

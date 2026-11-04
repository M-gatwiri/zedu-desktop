import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

class _ThrowingReadStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => throw Exception('keychain locked');
}

class _ThrowingDeleteStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'token';

  @override
  Future<void> deleteAccessToken() async => throw Exception('keychain locked');
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"ok":true}',
    status,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

void main() {
  test('a request still completes when reading the token throws', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test/'))
      ..httpClientAdapter = _StatusAdapter(200);
    dio.interceptors.add(AuthInterceptor(storage: _ThrowingReadStorage()));

    final response = await dio
        .get<dynamic>('a')
        .timeout(const Duration(seconds: 2));

    expect(response.statusCode, 200);
    expect(response.requestOptions.headers['Authorization'], isNull);
  });

  test(
    'a 401 still reaches the caller and signs out when deleting the token throws',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test/'))
        ..httpClientAdapter = _StatusAdapter(401);
      var signedOut = 0;
      dio.interceptors.add(
        AuthInterceptor(storage: _ThrowingDeleteStorage())
          ..onUnauthorized = () => signedOut++,
      );

      final error = await dio
          .get<dynamic>('a')
          .then<Object>((r) => r, onError: (Object e) => e)
          .timeout(const Duration(seconds: 2));

      expect(error, isA<DioException>());
      expect((error as DioException).response?.statusCode, 401);
      expect(signedOut, 1);
    },
  );
}

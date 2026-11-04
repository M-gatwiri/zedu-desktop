import 'package:zedu/core/core.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required SecureStorageService storage}) : _storage = storage;

  final SecureStorageService _storage;
  VoidCallback? onUnauthorized;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (error) {
      // Secure storage can throw (for example from corrupted stored data).
      // Send the request without a token so the call still completes and the
      // normal 401 handling takes over, instead of hanging forever.
      AppLogger.w(
        'Could not read the access token: $error',
        tag: 'AuthInterceptor',
      );
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !await _isForOldToken(err)) {
      try {
        await _storage.deleteAccessToken();
      } catch (error) {
        AppLogger.w(
          'Could not delete the access token: $error',
          tag: 'AuthInterceptor',
        );
      }
      onUnauthorized?.call();
    }
    handler.next(err);
  }

  /// A request that left with an old session's token can get its 401 after the
  /// user signed in again. That answer says nothing about the new session, so
  /// it must not delete the new token or sign the user out.
  Future<bool> _isForOldToken(DioException err) async {
    final sent = err.requestOptions.headers['Authorization'];
    if (sent is! String) return false;
    try {
      final current = await _storage.getAccessToken();
      if (current == null || current.isEmpty) return false;
      return sent != 'Bearer $current';
    } catch (_) {
      return false;
    }
  }
}

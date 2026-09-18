import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_token_storage.dart';
import 'api_exception.dart';

/// Thin wrapper around [Dio] that injects the bearer token, unwraps the
/// `{success, message, data, meta}` envelope every endpoint returns
/// (`App\Http\Responses\ApiResponse` on the backend), and converts every
/// failure — transport or API-level — into a single [ApiException] type.
class ApiClient {
  ApiClient({required this._tokenStorage, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: const {'Accept': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  /// Set by the DI wiring (auth feature) so a 401 anywhere can trigger a
  /// global session teardown without this layer depending on auth code.
  void Function()? onUnauthorized;

  /// Returns the raw envelope map so callers needing pagination can read
  /// both `data` and `meta`.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(() => _dio.get<Object?>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? data}) =>
      _send(() => _dio.post<Object?>(path, data: data));

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
  }) => _send(() => _dio.patch<Object?>(path, data: data));

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) =>
      _send(() => _dio.put<Object?>(path, data: data));

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => _dio.delete<Object?>(path));

  /// Downloads a raw (non-JSON-envelope) file response — used for
  /// attachments, which the backend streams straight from disk rather than
  /// wrapping in `ApiResponse`.
  Future<List<int>> downloadBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );

      return response.data ?? const [];
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> _send(
    Future<Response<Object?>> Function() call,
  ) async {
    try {
      final response = await call();
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const ApiException('Réponse invalide du serveur.');
      }
      if (body['success'] != true) {
        throw ApiException(
          body['message'] as String? ?? 'Une erreur est survenue.',
          statusCode: response.statusCode,
          errors: _parseErrors(body['errors']),
        );
      }

      return body;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  ApiException _mapDioError(DioException error) {
    final response = error.response;
    if (response != null) {
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return ApiException(
          body['message'] as String? ?? 'Une erreur est survenue.',
          statusCode: response.statusCode,
          errors: _parseErrors(body['errors']),
        );
      }

      return ApiException(
        'Erreur serveur (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Le serveur met trop de temps à répondre.');
      case DioExceptionType.connectionError:
        return const ApiException('Aucune connexion disponible.');
      default:
        return const ApiException('Une erreur réseau est survenue.');
    }
  }

  Map<String, List<String>>? _parseErrors(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    return raw.map((key, value) {
      final messages = value is List
          ? value.map((e) => e.toString()).toList()
          : <String>[value.toString()];

      return MapEntry(key as String, messages);
    });
  }
}

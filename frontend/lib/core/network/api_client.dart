import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:mine_wadhwani/core/constants/api_constants.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mine_wadhwani/core/constants/app_constants.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';

class ApiClient {
  /// Bumped when the server rejects our login token (401); the app then logs out.
  static final ValueNotifier<int> sessionExpired = ValueNotifier(0);

  late final Dio _dio;
  final SharedPreferences _sharedPreferences;

  ApiClient({required SharedPreferences sharedPreferences})
      : _sharedPreferences = sharedPreferences {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _sharedPreferences.getString(AppConstants.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Backend writes AI content (handover, actions) in this language.
          options.headers['Accept-Language'] = AppLanguage.current.value;
          handler.next(options);
        },
        onError: (error, handler) {
          final req = error.requestOptions;
          if (error.response?.statusCode == 401 &&
              req.headers['Authorization'] != null &&
              !req.path.startsWith('/api/v1/auth/')) {
            sessionExpired.value++;
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.delete(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Sends a multipart/form-data POST request (used for file uploads).
  Future<Response> multipartPost(
    String path, {
    required FormData data,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ServerException _handleError(DioException error) {
    final response = error.response;
    if (response != null && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      return ServerException(
        message: data['message'] as String? ?? 'Something went wrong',
        statusCode: response.statusCode,
      );
    }
    return ServerException(
      message: error.message ?? 'Network error occurred',
      statusCode: error.response?.statusCode,
    );
  }
}

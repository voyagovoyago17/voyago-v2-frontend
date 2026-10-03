import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/config/app_environment.dart';
import 'api_exceptions.dart';
import 'endpoints.dart';

typedef OnAuthExpiredCallback = void Function();

class DioClient {
  static DioClient? _instance;
  late final Dio _dio;
  OnAuthExpiredCallback? onAuthExpired;

  DioClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Endpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120), // Multi-day AI generation can take 20-60s
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 1. Inject Authorization Token
          final token = await SecureStorageService.instance.getSessionToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // 2. Inject Multi-Tenant Header
          final tenantId = await SecureStorageService.instance.getTenantId();
          if (tenantId.isNotEmpty) {
            options.headers['x-tenant-id'] = tenantId;
          }

          if (kDebugMode) {
            debugPrint('🌐 [DIO REQ] ${options.method} -> ${options.baseUrl}${options.path}');
            if (options.data != null) {
              debugPrint('📦 [DIO PAYLOAD] ${options.data}');
            }
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('✅ [DIO RES] ${response.statusCode} <- ${response.requestOptions.path}');
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          if (kDebugMode) {
            debugPrint('❌ [DIO ERR] ${error.response?.statusCode} <- ${error.requestOptions.path}: ${error.message ?? error.error}');
          }

          // Handle 401 Session Expiration
          if (error.response?.statusCode == 401) {
            final isAuthRoute = error.requestOptions.path.contains('/api/auth/email/login') ||
                error.requestOptions.path.contains('/api/auth/email/signup');
            if (!isAuthRoute) {
              onAuthExpired?.call();
            }
          }

          // Fallback automatique pour Android en local : bascule transparente entre 10.0.2.2 et 127.0.0.1
          final isConnErr = error.type == DioExceptionType.connectionError ||
              (error.message != null && error.message!.contains('Connection refused'));
          if (isConnErr && !kIsWeb && defaultTargetPlatform == TargetPlatform.android && !AppConfig.isProduction) {
            final currentBase = _dio.options.baseUrl;
            final isLocalHost = currentBase.contains('127.0.0.1') || currentBase.contains('localhost');
            final isEmulatorIp = currentBase.contains('10.0.2.2');
            final hasAlreadyRetried = error.requestOptions.extra['retried_fallback'] == true;

            if (!hasAlreadyRetried && (isLocalHost || isEmulatorIp)) {
              final newBase = isLocalHost
                  ? currentBase.replaceAll(RegExp(r'127\.0\.0\.1|localhost'), '10.0.2.2')
                  : currentBase.replaceAll('10.0.2.2', '127.0.0.1');
              if (kDebugMode) {
                debugPrint('🔄 [DIO FALLBACK] Connexion échouée sur $currentBase -> bascule automatique sur $newBase');
              }
              updateBaseUrl(newBase);

              final retryOptions = Options(
                method: error.requestOptions.method,
                headers: error.requestOptions.headers,
                extra: {...error.requestOptions.extra, 'retried_fallback': true},
              );
              try {
                final response = await _dio.request(
                  error.requestOptions.path,
                  data: error.requestOptions.data,
                  queryParameters: error.requestOptions.queryParameters,
                  options: retryOptions,
                );
                return handler.resolve(response);
              } catch (_) {
                // Si la bascule échoue également, on renvoie l'erreur normale
              }
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  static DioClient get instance {
    _instance ??= DioClient._();
    return _instance!;
  }

  Dio get rawDio => _dio;

  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  // --- HTTP VERBS WRAPPERS ---

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
}

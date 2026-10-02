import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final dynamic details;

  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  @override
  String toString() => message;

  factory ApiException.fromDioException(DioException dioError) {
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message: 'Délai d’attente dépassé. Vérifiez votre connexion internet.',
          statusCode: dioError.response?.statusCode,
        );

      case DioExceptionType.badResponse:
        final response = dioError.response;
        final statusCode = response?.statusCode;
        final data = response?.data;

        String extractedMessage = 'Une erreur est survenue sur le serveur.';

        if (data is Map<String, dynamic>) {
          if (data['message'] != null) {
            if (data['message'] is List) {
              extractedMessage = (data['message'] as List).join('\n');
            } else {
              extractedMessage = data['message'].toString();
            }
          } else if (data['error'] != null) {
            extractedMessage = data['error'].toString();
          }
        } else if (data is String && data.isNotEmpty) {
          extractedMessage = data;
        }

        switch (statusCode) {
          case 400:
            return ValidationException(
              message: extractedMessage,
              statusCode: 400,
              details: data,
            );
          case 401:
            return AuthExpiredException(
              message: extractedMessage.contains('Invalid') || extractedMessage.contains('incorrect')
                  ? extractedMessage
                  : 'Session expirée ou non autorisée. Veuillez vous reconnecter.',
              statusCode: 401,
            );
          case 403:
            return ForbiddenException(
              message: extractedMessage.isNotEmpty ? extractedMessage : 'Accès refusé.',
              statusCode: 403,
            );
          case 404:
            return NotFoundException(
              message: extractedMessage.isNotEmpty ? extractedMessage : 'Ressource introuvable.',
              statusCode: 404,
            );
          case 409:
            return ConflictException(
              message: extractedMessage.toLowerCase().contains('already') ||
                      extractedMessage.toLowerCase().contains('existe')
                  ? 'Cette adresse email est déjà associée à un compte Voyagooo.'
                  : extractedMessage,
              statusCode: 409,
            );
          case 500:
          case 502:
          case 503:
          default:
            return ServerException(
              message: extractedMessage.isNotEmpty ? extractedMessage : 'Erreur interne du serveur (500).',
              statusCode: statusCode,
            );
        }

      case DioExceptionType.connectionError:
        return NetworkException(
          message: 'Impossible de joindre le serveur Voyagooo. Vérifiez que le backend est bien démarré sur le port 3333.',
        );

      case DioExceptionType.cancel:
        return ApiException(message: 'La requête a été annulée.');

      case DioExceptionType.unknown:
      default:
        return ApiException(
          message: dioError.message?.isNotEmpty == true
              ? dioError.message!
              : dioError.error != null
                  // Cause réelle (connexion coupée, réponse illisible...) plutôt qu'un message vide
                  ? 'Une erreur inattendue est survenue (${dioError.error}).'
                  : 'Une erreur inattendue est survenue.',
        );
    }
  }
}

class NetworkException extends ApiException {
  NetworkException({required super.message, super.statusCode})
      : super(code: 'NETWORK_ERROR');
}

class AuthExpiredException extends ApiException {
  AuthExpiredException({required super.message, super.statusCode})
      : super(code: 'AUTH_EXPIRED');
}

class ForbiddenException extends ApiException {
  ForbiddenException({required super.message, super.statusCode})
      : super(code: 'FORBIDDEN');
}

class NotFoundException extends ApiException {
  NotFoundException({required super.message, super.statusCode})
      : super(code: 'NOT_FOUND');
}

class ConflictException extends ApiException {
  ConflictException({required super.message, super.statusCode})
      : super(code: 'CONFLICT');
}

class ValidationException extends ApiException {
  ValidationException({required super.message, super.statusCode, super.details})
      : super(code: 'VALIDATION_ERROR');
}

class ServerException extends ApiException {
  ServerException({required super.message, super.statusCode})
      : super(code: 'SERVER_ERROR');
}

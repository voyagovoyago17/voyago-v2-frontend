import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
          message: 'La connexion est trop lente. Vérifie ton réseau et réessaie.',
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

        // Message lisible par le voyageur (jamais de texte technique ou en anglais)
        extractedMessage = _friendlyMessage(extractedMessage, statusCode);

        switch (statusCode) {
          case 400:
            return ValidationException(
              message: extractedMessage,
              statusCode: 400,
              details: data,
            );
          case 401:
            return AuthExpiredException(
              message: _isLoginError(extractedMessage)
                  ? extractedMessage
                  : 'Ta session a expiré. Reconnecte-toi pour continuer.',
              statusCode: 401,
            );
          case 403:
            return ForbiddenException(
              message: extractedMessage.isNotEmpty ? extractedMessage : 'Accès refusé.',
              statusCode: 403,
              details: data,
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
              message: extractedMessage.isNotEmpty
                  ? extractedMessage
                  : 'Le service est momentanément indisponible. Réessaie dans un instant.',
              statusCode: statusCode,
            );
        }

      case DioExceptionType.connectionError:
        // Le détail technique reste dans la console de développement
        debugPrint('Serveur injoignable : ${dioError.requestOptions.uri} (${dioError.error})');
        return NetworkException(
          message: 'Connexion impossible pour le moment. Vérifie ta connexion internet et réessaie.',
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

/// Messages connus du serveur (en anglais) traduits pour le voyageur.
const Map<String, String> _knownMessages = {
  'invalid email or password': 'E-mail ou mot de passe incorrect. Vérifie tes identifiants et réessaie.',
  'this account uses a different login method':
      'Ce compte a été créé avec Google. Utilise « Continuer avec Google » pour te connecter.',
  'email already registered': 'Cette adresse e-mail est déjà associée à un compte Voyagooo.',
  'internal server error': 'Le service est momentanément indisponible. Réessaie dans un instant.',
  'too many requests': 'Trop de tentatives. Patiente un instant avant de réessayer.',
  'unauthorized': 'Ta session a expiré. Reconnecte-toi pour continuer.',
  'forbidden': 'Tu n’as pas accès à cette action.',
};

bool _isLoginError(String message) =>
    message.startsWith('E-mail ou mot de passe incorrect') || message.startsWith('Ce compte a été créé avec Google');

/// Ressemble à un message technique en anglais (validation, exception brute...) ?
final RegExp _technicalPattern = RegExp(
  r'\b(must|should|invalid|error|exception|cannot|failed|not found|unauthorized|forbidden|undefined|null|bad request|is not|property)\b',
  caseSensitive: false,
);

/// Transforme un message serveur en message clair, en français, pour le voyageur.
/// Les messages déjà rédigés en français par le serveur sont conservés tels quels.
String _friendlyMessage(String raw, int? statusCode) {
  final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final translated = <String>[];
  for (final line in lines) {
    final known = _knownMessages[line.toLowerCase().replaceAll(RegExp(r'[.!]+$'), '')];
    if (known != null) {
      translated.add(known);
    } else if (_validationMessage(line) case final validation?) {
      translated.add(validation);
    } else if (!_technicalPattern.hasMatch(line)) {
      translated.add(line);
    }
  }
  if (translated.isNotEmpty) return translated.toSet().join('\n');
  return switch (statusCode) {
    400 || 422 => 'Certaines informations sont invalides. Vérifie le formulaire et réessaie.',
    401 => 'Ta session a expiré. Reconnecte-toi pour continuer.',
    403 => 'Tu n’as pas accès à cette action.',
    404 => 'Élément introuvable. Il a peut-être été supprimé.',
    429 => 'Trop de tentatives. Patiente un instant avant de réessayer.',
    _ => 'Le service est momentanément indisponible. Réessaie dans un instant.',
  };
}

/// Erreurs de validation des formulaires (class-validator) les plus courantes.
String? _validationMessage(String line) {
  final l = line.toLowerCase();
  if (l.startsWith('email must be an email') || l.startsWith('email should not be empty')) {
    return 'Adresse e-mail invalide.';
  }
  final minLength = RegExp(r'^(\w+) must be longer than or equal to (\d+) characters').firstMatch(l);
  if (minLength != null) {
    final field = minLength.group(1) == 'password' || minLength.group(1) == 'new_password' ? 'Le mot de passe' : 'Ce champ';
    return '$field doit contenir au moins ${minLength.group(2)} caractères.';
  }
  if (RegExp(r'^(password|new_password) should not be empty').hasMatch(l)) return 'Saisis ton mot de passe.';
  return null;
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
  ForbiddenException({required super.message, super.statusCode, super.details})
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

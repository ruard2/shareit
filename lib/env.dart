import 'package:flutter/foundation.dart' show kIsWeb;

class Env {
  /// De basis-URL van de backend API.
  ///
  /// • Build met --dart-define=API_BASE=https://jouw-url.com  → die URL wordt gebruikt.
  /// • Op web zonder --dart-define                            → zelfde origin als de pagina
  ///   (werkt automatisch bij ngrok, localhost, enz.)
  /// • Natief (Android/iOS) zonder --dart-define              → http://localhost:8001
  static String get apiBase {
    const configured = String.fromEnvironment('API_BASE', defaultValue: '');
    if (configured.isNotEmpty) return configured;

    if (kIsWeb) {
      // Gebruik dezelfde origin als de pagina — werkt met ngrok, localhost, alles.
      final uri = Uri.base;
      final port = (uri.hasPort && uri.port != 80 && uri.port != 443)
          ? ':${uri.port}'
          : '';
      return '${uri.scheme}://${uri.host}$port';
    }

    return 'http://localhost:8001';
  }
}

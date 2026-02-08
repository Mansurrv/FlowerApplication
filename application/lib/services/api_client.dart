import 'package:http/http.dart' as http;

class ApiClient {
  static const String primaryBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://flowerapplication.onrender.com',
  );
  static const Duration requestTimeout = Duration(seconds: 10);

  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) {
    return _withFallback(
      (uri) => http.get(uri, headers: headers),
      path,
      queryParameters: queryParameters,
    );
  }

  static Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, String>? queryParameters,
  }) {
    return _withFallback(
      (uri) => http.post(uri, headers: headers, body: body),
      path,
      queryParameters: queryParameters,
    );
  }

  static Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, String>? queryParameters,
  }) {
    return _withFallback(
      (uri) => http.put(uri, headers: headers, body: body),
      path,
      queryParameters: queryParameters,
    );
  }

  static Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, String>? queryParameters,
  }) {
    return _withFallback(
      (uri) => http.patch(uri, headers: headers, body: body),
      path,
      queryParameters: queryParameters,
    );
  }

  static Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, String>? queryParameters,
  }) {
    return _withFallback(
      (uri) => http.delete(uri, headers: headers, body: body),
      path,
      queryParameters: queryParameters,
    );
  }

  static Uri _buildUri(
    String baseUrl,
    String path,
    Map<String, String>? queryParameters,
  ) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    final merged = <String, String>{
      ...uri.queryParameters,
      ...queryParameters,
    };
    return uri.replace(queryParameters: merged);
  }

  static Future<http.Response> _withFallback(
    Future<http.Response> Function(Uri) send,
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final primaryUri = _buildUri(primaryBaseUrl, path, queryParameters);
    return await send(primaryUri).timeout(requestTimeout);
  }
}

import 'package:http/http.dart' as http;

class ApiClient {
  static const String primaryBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://golangbackendflowerapplication.onrender.com',
  );
  static const Duration defaultRequestTimeout = Duration(seconds: 30);

  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Duration? timeout,
  }) {
    return _send(
      (uri) => http.get(uri, headers: headers),
      path,
      timeout: timeout,
      queryParameters: queryParameters,
    );
  }

  static Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, String>? queryParameters,
    Duration? timeout,
  }) {
    return _send(
      (uri) => http.post(uri, headers: headers, body: body),
      path,
      timeout: timeout,
      queryParameters: queryParameters,
    );
  }

  static Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, String>? queryParameters,
    Duration? timeout,
  }) {
    return _send(
      (uri) => http.put(uri, headers: headers, body: body),
      path,
      timeout: timeout,
      queryParameters: queryParameters,
    );
  }

  static Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, String>? queryParameters,
    Duration? timeout,
  }) {
    return _send(
      (uri) => http.patch(uri, headers: headers, body: body),
      path,
      timeout: timeout,
      queryParameters: queryParameters,
    );
  }

  static Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, String>? queryParameters,
    Duration? timeout,
  }) {
    return _send(
      (uri) => http.delete(uri, headers: headers, body: body),
      path,
      timeout: timeout,
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
    final merged = <String, String>{...uri.queryParameters, ...queryParameters};
    return uri.replace(queryParameters: merged);
  }

  static Future<http.Response> _send(
    Future<http.Response> Function(Uri) send,
    String path, {
    Map<String, String>? queryParameters,
    Duration? timeout,
  }) async {
    final primaryUri = _buildUri(primaryBaseUrl, path, queryParameters);
    final effectiveTimeout = timeout ?? defaultRequestTimeout;
    return await send(primaryUri).timeout(effectiveTimeout);
  }
}

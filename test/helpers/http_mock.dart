import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Lightweight router for [MockClient] that handles JSON GET/POST/PUT/PATCH/DELETE
/// **and** the multipart `Client.send` path used by [http.MultipartRequest].
///
/// Tests register handlers per `METHOD path` (path *without* the `/api` prefix
/// is normalized for callers). Multi-handlers are queued — each match consumes
/// one entry. Unknown routes throw, surfacing missing-mock bugs early.
class FakeHttpRouter {
  final Map<String, _RouteState> _routes = {};
  final List<RecordedRequest> requests = [];
  int _autoIncrement = 0;

  /// Register a handler. Returns a unique token used for ordering when needed.
  String when(
    String method,
    String pathOrUrl, {
    required _HandlerFn handler,
  }) {
    final key = _normalizeKey(method, pathOrUrl);
    final entry = _routes.putIfAbsent(key, _RouteState.new);
    entry.handlers.add(handler);
    return '${key}#${_autoIncrement++}';
  }

  /// Convenience: respond with [statusCode] + [body] for the next call.
  void respond(
    String method,
    String pathOrUrl, {
    int statusCode = 200,
    Object? body,
    Map<String, String> headers = const {'content-type': 'application/json'},
  }) {
    when(
      method,
      pathOrUrl,
      handler: (request) async {
        final encoded = body == null
            ? ''
            : body is String
                ? body
                : jsonEncode(body);
        // Use bytes constructor so UTF-8 text (e.g. Arabic) survives intact.
        return http.Response.bytes(
          utf8.encode(encoded),
          statusCode,
          headers: headers,
          request: request,
        );
      },
    );
  }

  /// Build the [MockClient] that drives http.runWithClient.
  http.Client buildClient() {
    return MockClient.streaming((request, bodyStream) async {
      final bodyBytes = await bodyStream
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      final recorded = RecordedRequest(
        method: request.method,
        url: request.url,
        headers: request.headers,
        bodyBytes: bodyBytes,
      );
      requests.add(recorded);

      final key = _normalizeKey(request.method, request.url.path);
      final state = _routes[key];
      if (state == null || state.handlers.isEmpty) {
        throw StateError('FakeHttpRouter: no handler for $key');
      }
      // Single-element handlers stay "sticky" so a test can match multiple
      // calls with one registration. Multi-element handlers are FIFO.
      final handler =
          state.handlers.length == 1 ? state.handlers.first : state.handlers.removeAt(0);
      final response = await handler(request);
      return http.StreamedResponse(
        Stream<List<int>>.value(response.bodyBytes),
        response.statusCode,
        contentLength: response.bodyBytes.length,
        request: request,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
      );
    });
  }

  String _normalizeKey(String method, String pathOrUrl) {
    final path = pathOrUrl.startsWith('http')
        ? Uri.parse(pathOrUrl).path
        : pathOrUrl;
    final normalised = path.startsWith('/') ? path : '/$path';
    return '${method.toUpperCase()} $normalised';
  }
}

typedef _HandlerFn = Future<http.Response> Function(http.BaseRequest request);

class _RouteState {
  final List<_HandlerFn> handlers = [];
}

class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyBytes,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final List<int> bodyBytes;

  String get body => utf8.decode(bodyBytes);
  dynamic decodedJson() => bodyBytes.isEmpty ? null : jsonDecode(body);
}

/// Runs [callback] with all `package:http` calls (including multipart) routed
/// through a [FakeHttpRouter]. Configure routes inside [setup].
Future<T> withMockedHttp<T>({
  required void Function(FakeHttpRouter router) setup,
  required Future<T> Function(FakeHttpRouter router) callback,
}) async {
  final router = FakeHttpRouter();
  setup(router);
  return http.runWithClient(() => callback(router), router.buildClient);
}

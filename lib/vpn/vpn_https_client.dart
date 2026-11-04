import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Bounded HTTPS downloads. Redirects never forward configuration credentials
/// to an unrelated origin.
class VpnHttpsClient {
  const VpnHttpsClient();

  static const maxBytes = 524288;

  static Uri validate(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) {
      throw const FormatException('Configuration URLs must use HTTPS.');
    }
    return uri;
  }

  Future<String> get(
    Uri url, {
    Duration timeout = const Duration(seconds: 12),
    HttpClient? client,
  }) async {
    validate(url.toString());
    final http = client ?? (HttpClient()..connectionTimeout = timeout);
    try {
      return await _download(http, url).timeout(timeout);
    } finally {
      // Also cancel the underlying request when Future.timeout fires.
      http.close(force: true);
    }
  }

  Future<String> _download(HttpClient client, Uri initial) async {
    var current = initial;
    for (var redirects = 0; redirects <= 3; redirects++) {
      final request = await client.getUrl(current);
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, text/plain',
      );
      final response = await request.close();
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        final next = location == null ? null : current.resolve(location);
        if (redirects == 3 || next == null || !canRedirect(current, next)) {
          throw const FormatException('Unsafe configuration redirect.');
        }
        await response.drain<void>();
        current = next;
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw FormatException(
          'Configuration returned HTTP ${response.statusCode}.',
        );
      }
      if (response.contentLength > maxBytes) {
        throw const FormatException('Configuration response is too large.');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) {
          throw const FormatException('Configuration response is too large.');
        }
      }
      return utf8.decode(bytes);
    }
    throw const FormatException('Too many configuration redirects.');
  }

  static bool canRedirect(Uri from, Uri to) {
    if (!to.isScheme('https') ||
        to.host.isEmpty ||
        from.userInfo.isNotEmpty ||
        to.userInfo.isNotEmpty) {
      return false;
    }
    if (from.origin == to.origin) return true;
    return from.isScheme('https') &&
        from.port == 443 &&
        to.port == 443 &&
        from.host == 'short.do' &&
        !from.hasQuery &&
        !from.hasFragment &&
        to.host == 'vpn.universeapps.org' &&
        !to.hasQuery &&
        !to.hasFragment &&
        to.pathSegments.length == 4 &&
        to.path.startsWith('/api/v1/configs/') &&
        to.pathSegments.last.isNotEmpty;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'dovren_promo_config.dart';

class DovrenPromoService extends ChangeNotifier {
  static const _endpointMask = '022030edd59495ce837303bf';
  static const _endpointData =
      'WEZGQEAKSksDXEpAF1IKEVBGVUZDVhAFX1xGVV1ESwcLWBZ1T0MCC11ATlJeXQxJ'
      'VlAFVgJRUFdUBQ1QXA1TBl0LBgtSVlACVgpQVgIIBgZLR1hDFlEME0pWWWxAQQ0L'
      'X0ZbX11DSw4XWlc=';
  static final _configUri = _decodeConfigUri();
  static const _retryInterval = Duration(hours: 12);

  DovrenPromoConfig? _config;
  Timer? _refreshTimer;
  HttpClient? _request;
  DateTime? _nextRefresh;
  bool _active = false;
  bool _disposed = false;

  DovrenPromoConfig? get config => _config;

  static Uri _decodeConfigUri() {
    final mask = utf8.encode(_endpointMask);
    final data = base64Decode(_endpointData);
    for (var index = 0; index < data.length; index++) {
      data[index] ^= mask[index % mask.length];
    }
    return Uri.parse(utf8.decode(data));
  }

  void setActive(bool active) {
    if (_disposed || active == _active) return;
    _active = active;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (active) {
      _scheduleRefresh();
    } else {
      _request?.close(force: true);
      _request = null;
    }
  }

  void _scheduleRefresh() {
    if (!_active || _disposed || _request != null) return;
    _refreshTimer?.cancel();
    final remaining = _nextRefresh?.difference(DateTime.now()) ?? Duration.zero;
    if (remaining <= Duration.zero) {
      unawaited(_fetch());
    } else {
      _refreshTimer = Timer(remaining, _fetch);
    }
  }

  Future<DovrenPromoConfig> _loadConfig(HttpClient client) async {
    final request = await client.getUrl(_configUri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw const FormatException('Promotion configuration request failed.');
    }
    final text = await response.transform(utf8.decoder).join();
    return DovrenPromoConfig.fromJson(jsonDecode(text));
  }

  Future<void> _fetch() async {
    if (!_active || _disposed || _request != null) return;
    final client = HttpClient();
    _request = client;
    try {
      final config = await _loadConfig(
        client,
      ).timeout(const Duration(seconds: 5));
      if (!_active || _disposed || !identical(_request, client)) return;
      _config = config;
      notifyListeners();
    } catch (_) {
      // The first failure stays disabled; later failures keep the last snapshot.
    } finally {
      client.close(force: true);
      if (!_disposed && identical(_request, client)) {
        _request = null;
        _nextRefresh = DateTime.now().add(
          _config?.refreshInterval ?? _retryInterval,
        );
        _scheduleRefresh();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    _refreshTimer?.cancel();
    _request?.close(force: true);
    _request = null;
    super.dispose();
  }
}

import 'dart:convert';

import 'vpn_country.dart';
import 'vpn_https_client.dart';
import 'vpn_profile_codec.dart';

class ImportedVpnProfile {
  const ImportedVpnProfile(
    this.config,
    this.label,
    this.source, {
    this.countryCode = '',
  });

  final String config;
  final String label;
  final String source;
  final String countryCode;
}

class VpnProfileImporter {
  VpnProfileImporter({Future<String> Function(Uri)? fetch})
    : _fetch = fetch ?? const VpnHttpsClient().get;

  final Future<String> Function(Uri) _fetch;
  static const _codec = VpnProfileCodec();

  Future<ImportedVpnProfile> import(String input) async {
    final raw = input.trim();
    final uri = Uri.tryParse(raw);
    if (uri != null && (uri.isScheme('https') || uri.isScheme('http'))) {
      final url = VpnHttpsClient.validate(raw);
      if (url.host == 'gist.github.com' ||
          (url.host == 'api.github.com' &&
              url.pathSegments.firstOrNull == 'gists')) {
        return _gist(url);
      }
      return _decode(await _fetch(url), url.host);
    }
    return _decode(raw, '');
  }

  Future<ImportedVpnProfile> _gist(Uri url) async {
    final parts = url.pathSegments.where((part) => part.isNotEmpty).toList();
    if (url.userInfo.isNotEmpty ||
        parts.length < 2 ||
        parts.length > 3 ||
        !RegExp(r'^[a-fA-F0-9]+$').hasMatch(parts[1]) ||
        (parts.length == 3 && !RegExp(r'^[a-fA-F0-9]+$').hasMatch(parts[2]))) {
      throw const FormatException('Enter a valid configuration link.');
    }
    final path = '/gists/${parts[1]}${parts.length == 3 ? '/${parts[2]}' : ''}';
    final data = jsonDecode(await _fetch(Uri.https('api.github.com', path)));
    final files = data is Map ? data['files'] : null;
    if (files is! Map || files.isEmpty || files.length > 20) {
      throw const FormatException('No usable configuration files were found.');
    }
    final profiles = <ImportedVpnProfile>[];
    for (final file in files.values) {
      if (file is! Map) continue;
      final name = file['filename'];
      final selected = url.fragment;
      if (selected.isNotEmpty &&
          name is String &&
          selected !=
              'file-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}' &&
          selected != name) {
        continue;
      }
      var content = file['content'];
      if (file['truncated'] == true || content is! String) {
        final rawUrl = file['raw_url'];
        final target = rawUrl is String
            ? VpnHttpsClient.validate(rawUrl)
            : null;
        if (target == null ||
            target.host != 'gist.githubusercontent.com' ||
            target.userInfo.isNotEmpty) {
          continue;
        }
        content = await _fetch(target);
      }
      try {
        profiles.add(_decode(content, 'gist.github.com'));
      } on FormatException {
        // A Gist may also contain a README. Only actual profiles are candidates.
      }
    }
    if (profiles.length != 1) {
      throw FormatException(
        profiles.isEmpty
            ? 'No supported VLESS configuration was found.'
            : 'This link contains multiple profiles. Use a direct profile link.',
      );
    }
    return profiles.single;
  }

  ImportedVpnProfile _decode(String input, String source) {
    var profile = input.trim();
    var metadataLabel = '';
    var countryCode = '';
    if (profile.startsWith('{')) {
      final data = jsonDecode(profile);
      if (data is Map &&
          (data.containsKey('base64Config') ||
              data.containsKey('base64Config_xray'))) {
        final metadata = _codec.decodeMetadata(data);
        profile = metadata.config;
        countryCode = normalizeVpnCountryCode(metadata.country);
        metadataLabel = metadata.city.isNotEmpty
            ? metadata.city
            : metadata.country;
      }
    }
    final config = _codec.normalize(profile);
    final decoded = jsonDecode(config) as Map<String, dynamic>;
    final outbound = (decoded['outbounds'] as List).first as Map;
    final settings = outbound['settings'] as Map;
    final server = (settings['vnext'] as List).first as Map;
    final uri = Uri.tryParse(profile);
    final fragment = uri?.isScheme('vless') == true
        ? Uri.decodeComponent(uri!.fragment).trim()
        : '';
    final label = metadataLabel.isNotEmpty
        ? metadataLabel
        : fragment.isNotEmpty
        ? fragment
        : server['address'] as String;
    return ImportedVpnProfile(
      config,
      label.substring(0, label.length.clamp(0, 100)),
      source,
      countryCode: countryCode,
    );
  }
}

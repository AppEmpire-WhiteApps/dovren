import 'vpn_country.dart';

class VpnProfile {
  const VpnProfile({
    required this.id,
    required this.label,
    required this.source,
    required this.config,
    String countryCode = '',
  }) : _countryCode = countryCode;

  final String id;
  final String label;
  // Only a host or filename, never a credential-bearing provisioning URL.
  final String source;
  final String config;
  final String _countryCode;

  String get countryCode => normalizeVpnCountryCode(_countryCode);
  String get flag => vpnCountryFlag(countryCode);
  String get countryName => vpnCountryName(countryCode);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'source': source,
    'config': config,
    if (countryCode.isNotEmpty) 'countryCode': countryCode,
  };

  factory VpnProfile.fromJson(Map<String, dynamic> value) {
    if (value['id'] is! String ||
        value['label'] is! String ||
        value['source'] is! String ||
        value['config'] is! String) {
      throw const FormatException('Invalid saved VPN profile.');
    }
    return VpnProfile(
      id: value['id'] as String,
      label: value['label'] as String,
      source: value['source'] as String,
      config: value['config'] as String,
      countryCode: value['countryCode'] is String
          ? value['countryCode'] as String
          : '',
    );
  }
}

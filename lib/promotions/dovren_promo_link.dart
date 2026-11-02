import 'package:url_launcher/url_launcher.dart';

Uri? dovrenPromotionUri(String value) {
  final trimmed = value.trim();
  if (RegExp(r'\s').hasMatch(trimmed)) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

Future<void> openDovrenPromotion(Uri? uri) async {
  if (uri == null || dovrenPromotionUri(uri.toString()) == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Refused links must not interrupt the reading workspace.
  }
}

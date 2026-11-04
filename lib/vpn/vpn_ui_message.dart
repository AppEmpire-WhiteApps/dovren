/// Shows only the controller's safe message, never raw exception/config data.
String vpnUiMessage(String? message, String fallback) {
  final text = message?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  if (text.isEmpty) return fallback;
  return text.length <= 320 ? text : '${text.substring(0, 320)}…';
}

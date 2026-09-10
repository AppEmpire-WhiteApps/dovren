import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class QuietRulesSupport {
  static const supportEmail = 'bernardsigridmv271@gmail.com';

  static Future<String> version() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }

  static Future<bool> contactSupport(String appName) => launchUrl(
        Uri(
          scheme: 'mailto',
          path: supportEmail,
          queryParameters: {'subject': '$appName support'},
        ),
        mode: LaunchMode.externalApplication,
      );

  static Future<bool> requestRating() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
      return true;
    }
    return false;
  }
}

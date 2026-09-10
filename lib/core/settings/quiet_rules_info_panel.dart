import 'package:flutter/material.dart';
import 'quiet_rules_support.dart';

class QuietRulesInfoPanel extends StatelessWidget {
  final String appName;
  final Color accent;
  final Color? textColor;
  const QuietRulesInfoPanel(
      {required this.appName, required this.accent, this.textColor, super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: QuietRulesSupport.version(),
        builder: (context, snapshot) {
          final version = snapshot.data ?? 'Loading…';
          return Column(children: [
            ListTile(
                leading: Icon(Icons.info_outline, color: accent),
                title: const Text('Version'),
                trailing: Text(version, style: TextStyle(color: textColor))),
            ListTile(
                leading: Icon(Icons.support_agent_outlined, color: accent),
                title: const Text('Support'),
                subtitle: const Text('Get help by email'),
                onTap: () => QuietRulesSupport.contactSupport(appName)),
            ListTile(
                leading: Icon(Icons.star_border_rounded, color: accent),
                title: const Text('Rate the app'),
                subtitle: const Text('Leave a review in the App Store'),
                onTap: () => QuietRulesSupport.requestRating()),
          ]);
        },
      );
}

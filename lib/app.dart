import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DovrenApp extends StatelessWidget {
  const DovrenApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ad Dovren',
      theme: DovrenTheme.light(),
      home: const DovrenLaunchGate());
}

class DovrenLaunchGate extends StatelessWidget {
  const DovrenLaunchGate({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: SharedPreferences.getInstance().then(
            (prefs) => prefs.getBool('dovren.onboarding.completed') ?? false),
        builder: (_, snapshot) => snapshot.data == true
            ? const DashboardScreen()
            : const DovrenOnboardingScreen(),
      );
}

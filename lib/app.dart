import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

class DovrenApp extends StatelessWidget {
  const DovrenApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ad Dovren',
    theme: DovrenTheme.light(),
    home: const DashboardScreen(),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/dovren_state.dart';
import '../../../promotions/dovren_promo_scheduler.dart';
import '../application/reading_workspace_controller.dart';
import 'insights_section.dart';
import 'overview_section.dart';
import 'rules_section.dart';
import 'settings_section.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DovrenState()),
      ChangeNotifierProvider(create: (_) => ReadingWorkspaceController()),
    ],
    child: Consumer2<DovrenState, ReadingWorkspaceController>(
      builder: (context, protection, workspace, _) => DovrenPromoScheduler(
        enabled: workspace.selectedArea != 3,
        child: Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: workspace.selectedArea,
              children: [
                TickerMode(
                  enabled: workspace.selectedArea == 0,
                  child: OverviewSection(
                    state: protection,
                    onOpenRules: workspace.showRuleBook,
                    onOpenInsights: workspace.showReadingInsights,
                  ),
                ),
                TickerMode(
                  enabled: workspace.selectedArea == 1,
                  child: RulesSection(state: protection),
                ),
                TickerMode(
                  enabled: workspace.selectedArea == 2,
                  child: InsightsSection(state: protection),
                ),
                TickerMode(
                  enabled: workspace.selectedArea == 3,
                  child: SettingsSection(state: protection),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: workspace.selectedArea,
            onDestinationSelected: workspace.selectArea,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield_rounded),
                label: 'Shield',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_rounded),
                label: 'Rules',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Insights',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

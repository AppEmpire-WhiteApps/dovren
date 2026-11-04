import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/dovren_state.dart';
import '../../../promotions/dovren_promo_scheduler.dart';
import '../../../vpn/vpn_controller.dart';
import '../../../vpn/vpn_remote_config.dart';
import '../../../vpn/vpn_screen.dart';
import '../../../vpn/vpn_widgets.dart';
import '../application/reading_workspace_controller.dart';
import 'insights_section.dart';
import 'overview_section.dart';
import 'rules_section.dart';
import 'settings_section.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _remote = VpnRemoteConfig.instance;
  final _vpn = VpnController.instance;
  late final _changes = Listenable.merge([_remote, _vpn]);
  bool _vpnSelected = true;

  // A blocked release must never strand a running or uncertain tunnel.
  bool get _showVpnTab => _remote.showVpn || vpnNeedsStop(_vpn);

  @override
  void initState() {
    super.initState();
    _vpnSelected = _showVpnTab;
    _changes.addListener(_updateVpnNavigation);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshRemote());
  }

  @override
  void dispose() {
    _changes.removeListener(_updateVpnNavigation);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshRemote());
  }

  Future<void> _refreshRemote() async {
    try {
      await _remote.refresh();
    } catch (_) {
      // Keep cached/offline defaults; remote settings never gate app launch.
    }
  }

  void _updateVpnNavigation() {
    if (!mounted) return;
    setState(() {
      if (!_showVpnTab) _vpnSelected = false;
    });
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DovrenState()),
      ChangeNotifierProvider(create: (_) => ReadingWorkspaceController()),
    ],
    child: Consumer2<DovrenState, ReadingWorkspaceController>(
      builder: (context, protection, workspace, _) {
        final showVpn = _showVpnTab;
        final showingVpn = showVpn && _vpnSelected;
        final navigationOffset = showVpn ? 1 : 0;
        final selectedIndex = showingVpn
            ? 0
            : workspace.selectedArea + navigationOffset;
        // Keep all five pages mounted. ReadingWorkspace retains its original
        // Shield/Rules/Insights/Settings indices, even when VPN is hidden.
        final pageIndex = showingVpn ? 0 : workspace.selectedArea + 1;
        return DovrenPromoScheduler(
          enabled: showingVpn || workspace.selectedArea != 3,
          child: Scaffold(
            body: SafeArea(
              child: IndexedStack(
                index: pageIndex,
                children: [
                  TickerMode(enabled: pageIndex == 0, child: const VpnScreen()),
                  TickerMode(
                    enabled: pageIndex == 1,
                    child: OverviewSection(
                      state: protection,
                      onOpenRules: workspace.showRuleBook,
                      onOpenInsights: workspace.showReadingInsights,
                    ),
                  ),
                  TickerMode(
                    enabled: pageIndex == 2,
                    child: RulesSection(state: protection),
                  ),
                  TickerMode(
                    enabled: pageIndex == 3,
                    child: InsightsSection(state: protection),
                  ),
                  TickerMode(
                    enabled: pageIndex == 4,
                    child: SettingsSection(state: protection),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                final selectVpn = showVpn && index == 0;
                setState(() => _vpnSelected = selectVpn);
                if (!selectVpn) {
                  workspace.selectArea(index - navigationOffset);
                }
              },
              destinations: [
                if (showVpn)
                  const NavigationDestination(
                    icon: Icon(Icons.verified_user_outlined),
                    selectedIcon: Icon(Icons.verified_user_rounded),
                    label: 'VPN',
                  ),
                const NavigationDestination(
                  icon: Icon(Icons.shield_outlined),
                  selectedIcon: Icon(Icons.shield_rounded),
                  label: 'Shield',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.tune_rounded),
                  label: 'Rules',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded),
                  label: 'Insights',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

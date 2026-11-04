import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class VpnPortalGlow extends StatefulWidget {
  const VpnPortalGlow({
    required this.child,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    super.key,
  });

  final Widget child;
  final bool enabled;
  final BorderRadius borderRadius;

  @override
  State<VpnPortalGlow> createState() => _VpnPortalGlowState();
}

class _VpnPortalGlowState extends State<VpnPortalGlow>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  bool _foreground = false;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(VpnPortalGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (!mounted) return;
    final animate =
        widget.enabled &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false &&
        !MediaQuery.disableAnimationsOf(context);
    if (_active != animate) setState(() => _active = animate);
    if (animate) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      if (_pulse.value != 0) _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    child: widget.child,
    builder: (context, child) {
      if (!_active) return child!;
      final pulse = Curves.easeInOut.transform(_pulse.value);
      return Transform.scale(
        scale: 0.985 + 0.015 * pulse,
        transformHitTests: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: DovrenTheme.sage.withValues(alpha: 0.18 + 0.34 * pulse),
                blurRadius: 8 + 14 * pulse,
                spreadRadius: 0.2 + 1.2 * pulse,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      );
    },
  );
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'dovren_fullscreen_promo.dart';
import 'dovren_promo_service.dart';
import 'dovren_promotions.dart';

class DovrenPromoScheduler extends StatefulWidget {
  const DovrenPromoScheduler({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<DovrenPromoScheduler> createState() => _DovrenPromoSchedulerState();
}

class _DovrenPromoSchedulerState extends State<DovrenPromoScheduler>
    with WidgetsBindingObserver {
  DovrenPromoService? _service;
  Timer? _initialTimer;
  Timer? _periodicTimer;
  bool _ready = false;
  bool _initialAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ready = true;
      _updateTimers();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service = DovrenPromotionsScope.maybeOf(context)?.notifier;
    _updateTimers();
  }

  @override
  void didUpdateWidget(DovrenPromoScheduler oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTimers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _updateTimers();

  void _updateTimers() {
    if (!_ready ||
        !widget.enabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        _service?.config?.canShowFullscreen != true) {
      _cancelTimers();
      return;
    }
    if (!_initialAttempted) {
      _initialTimer ??= Timer(const Duration(seconds: 2), () {
        _initialTimer = null;
        _initialAttempted = true;
        _tryShow();
        _startPeriodicTimer();
      });
    } else {
      _startPeriodicTimer();
    }
  }

  void _startPeriodicTimer() {
    _periodicTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      _tryShow();
    });
  }

  void _tryShow() {
    if (!mounted || !_ready || !widget.enabled) return;
    final config = _service?.config;
    if (config == null || !config.canShowFullscreen) return;
    unawaited(DovrenFullscreenPromo.show(context, config.fullscreen));
  }

  void _cancelTimers() {
    _initialTimer?.cancel();
    _periodicTimer?.cancel();
    _initialTimer = null;
    _periodicTimer = null;
  }

  @override
  void dispose() {
    _ready = false;
    _cancelTimers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

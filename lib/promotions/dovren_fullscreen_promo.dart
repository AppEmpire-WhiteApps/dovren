import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dovren_promo_colors.dart';
import 'dovren_promo_config.dart';
import 'dovren_promo_link.dart';
import 'dovren_promotions.dart';

class DovrenFullscreenPromo extends StatefulWidget {
  const DovrenFullscreenPromo({super.key, required this.promotion})
    : _snapshot = null;

  const DovrenFullscreenPromo._withSnapshot({
    required this.promotion,
    required _PromoSnapshot snapshot,
  }) : _snapshot = snapshot;

  final DovrenPromotion promotion;
  final _PromoSnapshot? _snapshot;

  static _DovrenFullscreenRoute? _activeRoute;

  static void _clearRoute(_DovrenFullscreenRoute route) {
    if (identical(_activeRoute, route)) {
      _activeRoute = null;
    }
  }

  static Future<void> show(
    BuildContext context,
    DovrenPromotion promotion,
  ) async {
    if (_activeRoute != null ||
        !context.mounted ||
        !promotion.active ||
        promotion.destination == null ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }

    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator == null || !_canPresentFrom(context, navigator)) {
      return;
    }

    final locale =
        DovrenPromotionsScope.maybeOf(context)?.locale ??
        Localizations.maybeLocaleOf(context) ??
        const Locale('en');
    final route = _DovrenFullscreenRoute(
      promotion: promotion,
      snapshot: _PromoSnapshot.capture(promotion, locale),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
    _activeRoute = route;
    try {
      await navigator.push<void>(route);
    } catch (_) {
      _clearRoute(route);
      rethrow;
    }
    // A pop completes push before the exit animation ends. Keep the guard
    // until route disposal, including when the navigator itself is torn down.
  }

  static bool _canPresentFrom(BuildContext context, NavigatorState root) {
    var route = ModalRoute.of(context);
    while (route != null) {
      final navigator = route.navigator;
      if (!route.isCurrent ||
          route.animation?.isCompleted == false ||
          route.secondaryAnimation?.isDismissed == false ||
          navigator == null ||
          navigator.userGestureInProgress) {
        return false;
      }
      if (identical(navigator, root)) {
        return true;
      }

      // A tab-local route can still be current underneath a root dialog.
      final parentRoute = ModalRoute.of(navigator.context);
      if (identical(parentRoute, route)) {
        return false;
      }
      route = parentRoute;
    }
    return false;
  }

  @override
  State<DovrenFullscreenPromo> createState() => _DovrenFullscreenPromoState();
}

class _DovrenFullscreenRoute extends CupertinoPageRoute<void> {
  _DovrenFullscreenRoute({
    required DovrenPromotion promotion,
    required _PromoSnapshot snapshot,
    required this.reduceMotion,
  }) : super(
         fullscreenDialog: true,
         builder: (_) => DovrenFullscreenPromo._withSnapshot(
           promotion: promotion,
           snapshot: snapshot,
         ),
       );

  final bool reduceMotion;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : super.reverseTransitionDuration;

  @override
  void dispose() {
    DovrenFullscreenPromo._clearRoute(this);
    super.dispose();
  }
}

class _PromoSnapshot {
  const _PromoSnapshot({
    required this.heading,
    required this.message,
    required this.actionText,
    required this.destination,
    required this.dismissDelay,
    required this.locale,
  });

  factory _PromoSnapshot.capture(DovrenPromotion promotion, Locale locale) {
    final copy = promotion.copyFor(locale);
    final delay = promotion.dismissDelaySeconds;
    return _PromoSnapshot(
      heading: copy.heading,
      message: copy.message,
      actionText: copy.actionText,
      destination: promotion.destination,
      dismissDelay: Duration(seconds: delay < 0 ? 0 : delay),
      locale: locale,
    );
  }

  final String heading;
  final String message;
  final String actionText;
  final Uri? destination;
  final Duration dismissDelay;
  final Locale locale;

  bool get isRussian => locale.languageCode == 'ru';
}

class _DovrenFullscreenPromoState extends State<DovrenFullscreenPromo>
    with WidgetsBindingObserver {
  final Stopwatch _visibleTime = Stopwatch();

  Timer? _countdownTimer;
  _PromoSnapshot? _snapshot;
  ModalRoute<dynamic>? _route;
  late bool _foreground;
  bool _tickerEnabled = false;
  bool _openingLink = false;
  int _remainingSeconds = 0;

  bool get _canClose => _remainingSeconds == 0;

  bool get _foregroundVisible =>
      _foreground &&
      _tickerEnabled &&
      _route?.isCurrent != false &&
      _route?.animation?.isCompleted != false &&
      _route?.secondaryAnimation?.isDismissed != false;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(_route, route)) {
      _listenToRoute(_route, listen: false);
      _route = route;
      _listenToRoute(_route, listen: true);
    }
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_snapshot == null) {
      final locale =
          DovrenPromotionsScope.maybeOf(context)?.locale ??
          Localizations.maybeLocaleOf(context) ??
          const Locale('en');
      _snapshot =
          widget._snapshot ?? _PromoSnapshot.capture(widget.promotion, locale);
      _remainingSeconds = _snapshot!.dismissDelay.inSeconds;
    }
    _syncPresentation();
  }

  void _listenToRoute(ModalRoute<dynamic>? route, {required bool listen}) {
    final animations = [route?.animation, route?.secondaryAnimation];
    for (final animation in animations) {
      if (listen) {
        animation?.addStatusListener(_onRouteStatusChanged);
      } else {
        animation?.removeStatusListener(_onRouteStatusChanged);
      }
    }
  }

  void _onRouteStatusChanged(AnimationStatus status) {
    _syncPresentation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPresentation();
  }

  void _syncPresentation() {
    final snapshot = _snapshot;
    if (!mounted || snapshot == null) {
      return;
    }

    final visible = _foregroundVisible;
    if (visible && !_canClose) {
      _visibleTime.start();
    } else {
      _visibleTime.stop();
    }

    final remainingMicros =
        snapshot.dismissDelay.inMicroseconds - _visibleTime.elapsedMicroseconds;
    const second = Duration.microsecondsPerSecond;
    final seconds = remainingMicros <= 0
        ? 0
        : (remainingMicros + second - 1) ~/ second;
    if (seconds != _remainingSeconds) {
      setState(() => _remainingSeconds = seconds);
    }

    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (visible && remainingMicros > 0) {
      // Preserve partial seconds across backgrounding or a covering route.
      final nextTick = remainingMicros - (seconds - 1) * second;
      _countdownTimer = Timer(
        Duration(microseconds: nextTick),
        _syncPresentation,
      );
    } else {
      _visibleTime.stop();
    }
  }

  void _close() {
    final route = _route;
    if (_canClose && _foregroundVisible && route != null && route.isCurrent) {
      route.navigator?.pop<void>();
    }
  }

  Future<void> _openPromotion() async {
    final destination = _snapshot?.destination;
    if (_openingLink || !_foregroundVisible || destination == null) {
      return;
    }
    setState(() => _openingLink = true);
    try {
      await openDovrenPromotion(destination);
    } finally {
      if (mounted) {
        setState(() => _openingLink = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listenToRoute(_route, listen: false);
    _countdownTimer?.cancel();
    _visibleTime.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = DovrenPromoColors();
    final snapshot = _snapshot!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: _canClose,
        child: Scaffold(
          backgroundColor: colors.background,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors.fullscreenGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final inset = constraints.maxWidth < 360 ? 20.0 : 28.0;
                  final header = _buildHeader(snapshot, colors);
                  final scrollHeader =
                      constraints.maxHeight < 300 ||
                      MediaQuery.textScalerOf(context).scale(16) > 32;
                  if (scrollHeader) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(inset, 8, inset, 24),
                      child: Column(
                        children: [
                          header,
                          const SizedBox(height: 24),
                          _buildContent(snapshot, colors, fillHeight: false),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        header,
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                sliver: SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 520,
                                      ),
                                      child: _buildContent(
                                        snapshot,
                                        colors,
                                        fillHeight: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(_PromoSnapshot snapshot, DovrenPromoColors colors) {
    final closeLabel = snapshot.isRussian ? 'Закрыть рекламу' : 'Close ad';
    final countdownLabel = snapshot.isRussian
        ? '$closeLabel через $_remainingSeconds с'
        : '$closeLabel in $_remainingSeconds seconds';
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.orangeSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              snapshot.isRussian ? 'Реклама' : 'Ad',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _canClose ? _close : null,
            style: TextButton.styleFrom(
              foregroundColor: colors.text,
              disabledForegroundColor: colors.textSecondary,
              backgroundColor: colors.surface,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.outline),
              ),
            ),
            child: Semantics(
              label: _canClose ? closeLabel : countdownLabel,
              excludeSemantics: true,
              child: _canClose
                  ? const Icon(Icons.close_rounded, size: 20)
                  : Text(
                      '$_remainingSeconds',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    _PromoSnapshot snapshot,
    DovrenPromoColors colors, {
    required bool fillHeight,
  }) {
    return Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fillHeight) const Spacer(),
        Center(
          child: ExcludeSemantics(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.sage,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.shield_rounded, color: colors.text, size: 46),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          snapshot.heading,
          softWrap: true,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.12,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          snapshot.message,
          softWrap: true,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        if (fillHeight) const Spacer(),
        FilledButton(
          onPressed: snapshot.destination == null || _openingLink
              ? null
              : _openPromotion,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            disabledBackgroundColor: colors.primary.withValues(alpha: 0.7),
            disabledForegroundColor: colors.onPrimary,
            minimumSize: const Size(48, 56),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            snapshot.actionText,
            softWrap: true,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

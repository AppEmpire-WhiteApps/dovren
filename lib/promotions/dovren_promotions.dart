import 'package:flutter/widgets.dart';

import 'dovren_promo_service.dart';

class DovrenPromotions extends StatefulWidget {
  const DovrenPromotions({super.key, required this.child});

  final Widget child;

  @override
  State<DovrenPromotions> createState() => _DovrenPromotionsState();
}

class _DovrenPromotionsState extends State<DovrenPromotions>
    with WidgetsBindingObserver {
  final _service = DovrenPromoService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateActivity();
  }

  void _updateActivity() {
    final state = WidgetsBinding.instance.lifecycleState;
    _service.setActive(state == null || state == AppLifecycleState.resumed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _updateActivity();

  @override
  void didChangeLocales(List<Locale>? locales) => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DovrenPromotionsScope(
    service: _service,
    locale: WidgetsBinding.instance.platformDispatcher.locale,
    child: widget.child,
  );
}

class DovrenPromotionsScope extends InheritedNotifier<DovrenPromoService> {
  const DovrenPromotionsScope({
    super.key,
    required DovrenPromoService service,
    required this.locale,
    required super.child,
  }) : super(notifier: service);

  final Locale locale;

  static DovrenPromotionsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DovrenPromotionsScope>();

  @override
  bool updateShouldNotify(DovrenPromotionsScope oldWidget) =>
      locale != oldWidget.locale || super.updateShouldNotify(oldWidget);
}

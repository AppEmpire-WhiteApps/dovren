import 'package:flutter/widgets.dart';

import 'dovren_promo_link.dart';

@immutable
class DovrenPromoConfig {
  const DovrenPromoConfig({
    required this.enabled,
    required this.refreshInterval,
    required this.card,
    required this.fullscreen,
  });

  factory DovrenPromoConfig.fromJson(Object? value) {
    final json = _promoObject(value);
    final hours = _promoInteger(json['config_refresh_hours'], minimum: 1);
    final interval = Duration(hours: hours);
    if (interval.inHours != hours) {
      throw const FormatException(
        'Promotion refresh interval is out of range.',
      );
    }
    return DovrenPromoConfig(
      enabled: _promoBoolean(json['promotions_enabled']),
      refreshInterval: interval,
      card: DovrenPromotion.fromJson(json['inline_card']),
      fullscreen: DovrenPromotion.fromJson(
        json['fullscreen_offer'],
        fullscreen: true,
      ),
    );
  }

  final bool enabled;
  final Duration refreshInterval;
  final DovrenPromotion card;
  final DovrenPromotion fullscreen;

  bool get canShowCard => enabled && card.active && card.destination != null;
  bool get canShowFullscreen =>
      enabled && fullscreen.active && fullscreen.destination != null;
}

@immutable
class DovrenPromotion {
  const DovrenPromotion({
    required this.active,
    required this.destination,
    required this.dismissDelaySeconds,
    required this.translations,
  });

  factory DovrenPromotion.fromJson(Object? value, {bool fullscreen = false}) {
    final json = _promoObject(value);
    final active = _promoBoolean(json['active']);
    final url = json['target_url'];
    if (url is! String) {
      throw const FormatException('Expected a promotion destination.');
    }
    final destination = dovrenPromotionUri(url);
    if (active && destination == null) {
      throw const FormatException('Expected an HTTP(S) promotion destination.');
    }
    final translations = _promoObject(json['translations']).map(
      (language, copy) => MapEntry(language, DovrenPromoCopy.fromJson(copy)),
    );
    final english = translations['en'];
    if (active &&
        (english == null ||
            english.heading.isEmpty ||
            english.message.isEmpty ||
            (fullscreen && english.actionText.isEmpty))) {
      throw const FormatException('Expected English promotion fallback text.');
    }
    return DovrenPromotion(
      active: active,
      destination: destination,
      dismissDelaySeconds: fullscreen
          ? _promoInteger(json['dismiss_delay_seconds'], minimum: 0)
          : 0,
      translations: Map.unmodifiable(translations),
    );
  }

  final bool active;
  final Uri? destination;
  final int dismissDelaySeconds;
  final Map<String, DovrenPromoCopy> translations;

  DovrenPromoCopy copyFor(Locale locale) {
    final english = translations['en'] ?? const DovrenPromoCopy();
    final localized = locale.languageCode.toLowerCase() == 'ru'
        ? translations['ru'] ?? english
        : english;
    return DovrenPromoCopy(
      heading: localized.heading.isEmpty ? english.heading : localized.heading,
      message: localized.message.isEmpty ? english.message : localized.message,
      actionText: localized.actionText.isEmpty
          ? english.actionText
          : localized.actionText,
    );
  }
}

@immutable
class DovrenPromoCopy {
  const DovrenPromoCopy({
    this.heading = '',
    this.message = '',
    this.actionText = '',
  });

  factory DovrenPromoCopy.fromJson(Object? value) {
    final json = _promoObject(value);
    return DovrenPromoCopy(
      heading: _promoText(json['heading']),
      message: _promoText(json['message']),
      actionText: _promoText(json['action_text']),
    );
  }

  final String heading;
  final String message;
  final String actionText;
}

Map<String, dynamic> _promoObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Expected a promotion configuration object.');
}

bool _promoBoolean(Object? value) {
  if (value is bool) return value;
  throw const FormatException('Expected a promotion configuration boolean.');
}

int _promoInteger(Object? value, {required int minimum}) {
  if (value is int && value >= minimum) return value;
  throw const FormatException(
    'Expected a valid promotion configuration integer.',
  );
}

String _promoText(Object? value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  throw const FormatException('Expected promotion text.');
}

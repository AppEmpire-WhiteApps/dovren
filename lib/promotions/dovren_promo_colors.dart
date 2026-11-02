import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class DovrenPromoColors {
  const DovrenPromoColors();

  Color get background => DovrenTheme.cream;
  Color get text => DovrenTheme.ink;
  Color get primary => DovrenTheme.ink;
  Color get onPrimary => DovrenTheme.cream;
  Color get sage => DovrenTheme.sage;
  Color get orange => DovrenTheme.orange;

  Color get surface =>
      Color.alphaBlend(Colors.white.withValues(alpha: 0.68), background);

  Color get textSecondary =>
      Color.lerp(DovrenTheme.ink, DovrenTheme.muted, 0.62)!;

  Color get sageSurface =>
      Color.alphaBlend(sage.withValues(alpha: 0.42), surface);

  Color get orangeSurface =>
      Color.alphaBlend(orange.withValues(alpha: 0.18), surface);

  Color get outline => text.withValues(alpha: 0.12);
  Color get shadow => text.withValues(alpha: 0.08);
  Color get shimmer => Colors.white.withValues(alpha: 0.52);

  List<Color> get cardGradient => [surface, sageSurface, orangeSurface];

  List<Color> get fullscreenGradient => [background, surface, sageSurface];
}

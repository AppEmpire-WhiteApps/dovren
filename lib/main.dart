import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'promotions/dovren_promotions.dart';

void _trackAppLaunch() {
  var launchTracked = false;
  Clarity.setOnSessionStartedCallback((_) {
    if (!launchTracked) {
      launchTracked = Clarity.sendCustomEvent('app_launch');
    }
  });
}

void main() {
  _trackAppLaunch();
  runApp(
    ClarityWidget(
      clarityConfig: ClarityConfig(projectId: 'ycmeed2que'),
      app: const DovrenPromotions(child: DovrenApp()),
    ),
  );
}

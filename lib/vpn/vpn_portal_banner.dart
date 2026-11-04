import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'vpn_portal_glow.dart';

class VpnPortalBanner extends StatelessWidget {
  const VpnPortalBanner({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => VpnPortalGlow(
    enabled: onTap != null,
    child: Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: DovrenTheme.ink,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DovrenTheme.ink,
                Color.alphaBlend(
                  DovrenTheme.ink.withValues(alpha: 0.6),
                  DovrenTheme.sage,
                ),
              ],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 146),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: DovrenTheme.sage,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AD',
                          style: TextStyle(
                            color: DovrenTheme.ink,
                            fontSize: 9,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: DovrenTheme.cream,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: DovrenTheme.ink,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get Configuration',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: DovrenTheme.cream,
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fast, secure connection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: DovrenTheme.cream,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

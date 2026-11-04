import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'vpn_controller.dart';

const vpnFault = Color(0xFF9A392B);
const vpnSageWash = Color(0xFFE5EDE2);

/// Stop remains available independently of editing, busy and remote gates.
bool vpnNeedsStop(VpnController vpn) => vpn.needsStop;

class VpnPanel extends StatelessWidget {
  const VpnPanel({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color = Colors.white,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class VpnEyebrow extends StatelessWidget {
  const VpnEyebrow(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: DovrenTheme.muted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
    ),
  );
}

class VpnShieldEmblem extends StatelessWidget {
  const VpnShieldEmblem({required this.connected, super.key});

  final bool connected;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: connected ? DovrenTheme.sage : vpnSageWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        connected ? Icons.verified_user_outlined : Icons.shield_outlined,
        size: 26,
        color: DovrenTheme.ink,
      ),
    ),
  );
}

class VpnMessage extends StatelessWidget {
  const VpnMessage(this.message, {this.isError = false, super.key});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(
        color: isError ? vpnFault : DovrenTheme.muted,
        fontSize: 13,
        height: 1.5,
      ),
    ),
  );
}

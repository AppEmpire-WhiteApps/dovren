import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'vpn_widgets.dart';

class VpnProfileCard extends StatelessWidget {
  const VpnProfileCard({
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
    this.flag = '🌐',
    this.countryName = 'Unknown location',
    super.key,
  });

  final String label;
  final String flag;
  final String countryName;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final location = countryName.trim().isEmpty
        ? 'Unknown location'
        : countryName.trim();
    final shortLabel = label.trim();
    final showLabel =
        shortLabel.isNotEmpty &&
        shortLabel.toLowerCase() != location.toLowerCase();
    return Semantics(
      selected: selected,
      child: VpnPanel(
        color: selected ? vpnSageWash : Colors.white,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? DovrenTheme.sage : DovrenTheme.cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      flag.trim().isEmpty ? '🌐' : flag,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 22, height: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DovrenTheme.ink,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (showLabel) ...[
                        const SizedBox(height: 3),
                        Text(
                          shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DovrenTheme.muted,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: DovrenTheme.ink,
                      size: 18,
                    ),
                  ),
                ],
                IconButton(
                  tooltip:
                      'Remove ${shortLabel.isEmpty ? location : shortLabel}',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: DovrenTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

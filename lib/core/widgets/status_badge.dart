import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Pill-shaped, colour-coded badge for statuses (setup status, signal
/// status, licence status, EA online/offline, BUY/SELL, ...).
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTypography.mono(fontSize: 11, color: color),
      ),
    );
  }
}

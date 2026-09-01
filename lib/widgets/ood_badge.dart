import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../utils/theme.dart';

class OodBadge extends StatelessWidget {
  final DetectionResult result;
  const OodBadge({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isOod = result.isOod;
    final color = isOod ? AppColors.error : AppColors.success;
    final icon = isOod
        ? Icons.warning_amber_rounded
        : Icons.check_circle_rounded;
    final label = isOod ? 'OUT-OF-DISTRIBUTION' : 'IN-DISTRIBUTION';
    final sub = isOod
        ? 'Image may not belong to training distribution'
        : 'Image is within training distribution';

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Mahal.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
              Text(
                result.mahalanobisDistance.toStringAsFixed(2),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '/ ${result.oodThreshold.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

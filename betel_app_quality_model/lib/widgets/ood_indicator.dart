import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/inference_result.dart';
import '../theme.dart';

/// Displays the Mahalanobis OOD score with a visual gauge.
/// Mirrors the score/threshold annotation in the notebook ONNX test cell.
///
/// Gauge colour:
///   Green  → well inside distribution (score ≪ threshold)
///   Amber  → approaching threshold   (score in [0.7, 1.0) × threshold)
///   Red    → OOD (score > threshold)
class OodIndicator extends StatelessWidget {
  final InferenceResult result;

  const OodIndicator({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final score = result.oodScore;
    final threshold = result.threshold;
    final ratio = (score / threshold).clamp(0.0, 2.0); // normalise to threshold

    // Determine status colour
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (result.isOod) {
      statusColor = AppColors.error;
      statusText = 'OOD — Rejected';
      statusIcon = Icons.dangerous_rounded;
    } else if (ratio >= 0.7) {
      statusColor = AppColors.warning;
      statusText = 'Near Boundary';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = AppColors.success;
      statusText = 'In-Distribution';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    // Gauge fill: capped at 1.0 visually
    final gaugeFill = (ratio / 2.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: statusColor),
              const SizedBox(width: 8),
              Text(
                'OOD Detection',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Score gauge
          _Gauge(fill: gaugeFill, color: statusColor),
          const SizedBox(height: 10),

          // Score / threshold row
          Row(
            children: [
              _ScorePill(
                label: 'OOD Score',
                value: score.toStringAsFixed(1),
                color: statusColor,
              ),
              const SizedBox(width: 10),
              _ScorePill(
                label: 'Threshold (95th pct)',
                value: threshold.toStringAsFixed(1),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Explanation
          Text(
            'Mahalanobis distance measures how far the extracted features are '
            'from the training class centres. Score > threshold → OOD rejection.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  final double fill; // 0.0 – 1.0
  final Color color;

  const _Gauge({required this.fill, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      // Threshold marker at 50% of gauge width
      const thresholdX = 0.5;

      return Stack(
        children: [
          // Track
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          // Fill
          Container(
            height: 10,
            width: w * fill,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          // Threshold tick
          Positioned(
            left: w * thresholdX - 1,
            top: 0,
            child: Container(
              width: 2,
              height: 10,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
          // Threshold label
          Positioned(
            left: w * thresholdX - 24,
            top: 12,
            child: Text(
              'threshold',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ScorePill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color == AppColors.textSecondary
                    ? AppColors.textPrimary
                    : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

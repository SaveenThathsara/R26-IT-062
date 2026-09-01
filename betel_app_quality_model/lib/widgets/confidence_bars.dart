import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/inference_result.dart';
import '../theme.dart';

/// Per-class confidence bar chart.
/// Mirrors the horizontal bar chart (axes[1]) in the notebook ONNX test cell.
/// Predicted class bar uses a contrasting colour; others use muted teal.
class ConfidenceBars extends StatelessWidget {
  final InferenceResult result;

  const ConfidenceBars({super.key, required this.result});

  Color _barColor(String className, bool isPredicted) {
    if (isPredicted) {
      switch (className) {
        case 'Grade A Quality':
          return AppColors.accent;
        case 'Grade B Quality':
          return AppColors.blue;
        case 'Grade C Quality':
          return AppColors.accent3;
        case 'Grade D Quality':
          return AppColors.accent2;
        case 'Grade E Quality':
          return AppColors.error;
        default:
          return AppColors.accent;
      }
    }
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final scores = result.classScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  size: 16, color: AppColors.blue),
              const SizedBox(width: 8),
              Text(
                'Class Probabilities',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...scores.map((entry) {
            final isPred = entry.key == result.predictedClass;
            final color = _barColor(entry.key, isPred);
            final pct = entry.value * 100;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Bar(
                label: _shortLabel(entry.key),
                value: entry.value,
                pct: pct,
                color: color,
                isPredicted: isPred,
              ),
            );
          }),
        ],
      ),
    );
  }

  String _shortLabel(String name) {
    // "Grade A Quality" → "Grade A"
    final parts = name.split(' ');
    return parts.length >= 2 ? '${parts[0]} ${parts[1]}' : name;
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final double pct;
  final Color color;
  final bool isPredicted;

  const _Bar({
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
    required this.isPredicted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Label
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight:
                  isPredicted ? FontWeight.w700 : FontWeight.w400,
              color: isPredicted ? color : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Bar
        Expanded(
          child: Stack(
            children: [
              // Background track
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.border.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Fill
              LayoutBuilder(builder: (context, constraints) {
                return Container(
                  height: 18,
                  width: constraints.maxWidth * value,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isPredicted ? 0.85 : 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Percentage
        SizedBox(
          width: 46,
          child: Text(
            '${pct.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight:
                  isPredicted ? FontWeight.w700 : FontWeight.w400,
              color: isPredicted ? color : AppColors.textSecondary,
            ),
          ),
        ),
        // Predicted marker
        SizedBox(
          width: 20,
          child: isPredicted
              ? Icon(Icons.chevron_left_rounded, size: 16, color: color)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

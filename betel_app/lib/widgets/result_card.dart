import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';
import '../services/inference_service.dart';
import 'confidence_bar.dart';

class ResultCard extends StatelessWidget {
  final PredictionResult result;

  const ResultCard({super.key, required this.result});

  // ── Disease metadata matching the notebook's CLASS_NAMES ──
  static const Map<String, _DiseaseInfo> _diseaseInfo = {
    'Bacterial Leaf Disease': _DiseaseInfo(
      icon: '🦠',
      description:
          'Caused by bacterial pathogens. Look for water-soaked lesions, yellowing, and wilting. Treat with copper-based bactericides and remove infected leaves.',
      severity: 'High',
      severityColor: Color(0xFFF87171),
    ),
    'Dried Leaf': _DiseaseInfo(
      icon: '🍂',
      description:
          'Leaf desiccation due to water stress, nutrient deficiency, or environmental conditions. Improve irrigation and check soil moisture.',
      severity: 'Medium',
      severityColor: Color(0xFFFBBF24),
    ),
    'Fungal Brown Spot Disease': _DiseaseInfo(
      icon: '🔴',
      description:
          'Caused by fungal infection. Visible as brown circular spots with yellow halos. Apply fungicide and improve air circulation.',
      severity: 'High',
      severityColor: Color(0xFFF87171),
    ),
    'Healthy Leaf': _DiseaseInfo(
      icon: '✅',
      description:
          'No disease detected. The leaf appears healthy with good coloration and texture. Continue regular care and monitoring.',
      severity: 'None',
      severityColor: Color(0xFF4ADE80),
    ),
    'OOD — Rejected': _DiseaseInfo(
      icon: '🚨',
      description:
          'The image does not resemble a betel leaf based on the model\'s distribution. Please use a clear, close-up photo of a betel leaf.',
      severity: 'N/A',
      severityColor: Color(0xFF818CF8),
    ),
  };

  Color get _statusColor {
    if (result.isOod) return AppColors.purple;
    if (result.predictedClass == 'Healthy Leaf') return AppColors.success;
    if (result.confidence >= 0.75) return AppColors.error;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final info = _diseaseInfo[result.predictedClass] ??
        _diseaseInfo['OOD — Rejected']!;

    // Sort class scores descending
    final sortedScores = result.classScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Animate(
      effects: [
        FadeEffect(duration: 400.ms),
        SlideEffect(
          duration: 400.ms,
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Primary result banner ─────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _statusColor.withOpacity(0.4), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(info.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.predictedClass,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _statusColor,
                            ),
                          ),
                          if (!result.isOod)
                            Text(
                              'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Severity badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: info.severityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: info.severityColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        info.severity,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: info.severityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  info.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── OOD status row ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  result.isOod
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  size: 16,
                  color: result.isOod ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  result.isOod ? 'Out-of-Distribution' : 'In-Distribution',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: result.isOod ? AppColors.warning : AppColors.success,
                  ),
                ),
                const Spacer(),
                if (result.oodScore > 0) ...[
                  Text(
                    'OOD Score: ${result.oodScore.toStringAsFixed(1)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ ${result.oodThreshold.toStringAsFixed(1)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Per-class confidence bars ─────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Probabilities',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...sortedScores.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  return ConfidenceBar(
                    label: e.key,
                    confidence: e.value,
                    isTopPrediction: i == 0 && !result.isOod,
                    animationDelayMs: i * 80,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiseaseInfo {
  final String icon;
  final String description;
  final String severity;
  final Color severityColor;

  const _DiseaseInfo({
    required this.icon,
    required this.description,
    required this.severity,
    required this.severityColor,
  });
}

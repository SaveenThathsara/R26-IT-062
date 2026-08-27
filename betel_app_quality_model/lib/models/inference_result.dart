/// Mirrors the output of predict_with_ood() from the notebook (Cell 22).
/// 
/// Fields:
/// - predictedClass: class name or "OOD — Rejected"
/// - confidence:     softmax probability of top class (null if OOD)
/// - oodScore:       min Mahalanobis distance (lower = more in-distribution)
/// - threshold:      calibrated 95th-percentile cutoff from validation set
/// - isOod:          true when oodScore > threshold
/// - classScores:    per-class softmax probabilities {className: prob}
class InferenceResult {
  final String predictedClass;
  final double? confidence;
  final double oodScore;
  final double threshold;
  final bool isOod;
  final Map<String, double> classScores;

  const InferenceResult({
    required this.predictedClass,
    required this.confidence,
    required this.oodScore,
    required this.threshold,
    required this.isOod,
    required this.classScores,
  });

  /// Human-readable grade label (e.g. "Grade A") derived from class name.
  String get gradeLabel {
    if (isOod) return 'OOD';
    // CLASS_NAMES = ["Grade A Quality", ..., "Grade E Quality"]
    final parts = predictedClass.split(' ');
    return parts.length >= 2 ? '${parts[0]} ${parts[1]}' : predictedClass;
  }

  /// Returns a description/recommendation based on grade.
  String get gradeDescription {
    if (isOod) {
      return 'The image does not appear to be a betel leaf or is too corrupted '
          'for reliable analysis. Please try a clearer photo.';
    }
    switch (gradeLabel) {
      case 'Grade A':
        return 'Premium quality. Deep green, firm, no blemishes. '
            'Ideal for high-end markets and ceremonial use.';
      case 'Grade B':
        return 'Good quality. Minor surface marks acceptable. '
            'Suitable for standard commercial trade.';
      case 'Grade C':
        return 'Average quality. Some yellowing or light damage present. '
            'Suitable for local markets at reduced price.';
      case 'Grade D':
        return 'Below average. Notable discoloration or disease spots. '
            'Limited commercial value; consider early harvest next cycle.';
      case 'Grade E':
        return 'Poor quality. Significant damage, wilting, or disease. '
            'Not suitable for trade. Review cultivation practices.';
      default:
        return '';
    }
  }
}

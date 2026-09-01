class BoundingBox {
  final double x1, y1, x2, y2;

  const BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  double get width => x2 - x1;
  double get height => y2 - y1;
}

class Detection {
  final int classId;
  final String className;
  final double confidence;
  final BoundingBox bbox;

  const Detection({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.bbox,
  });
}

class DetectionResult {
  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final List<Detection> detections;
  final double mahalanobisDistance;
  final double oodThreshold;
  final bool isOod;

  const DetectionResult({
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.detections,
    required this.mahalanobisDistance,
    required this.oodThreshold,
    required this.isOod,
  });

  /// Final label = class with highest total confidence sum
  String? get finalLabel {
    if (detections.isEmpty) return null;
    final Map<String, double> confSum = {};
    for (final d in detections) {
      confSum[d.className] = (confSum[d.className] ?? 0) + d.confidence;
    }
    return confSum.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double? get finalConfidence {
    if (finalLabel == null) return null;
    final matching = detections
        .where((d) => d.className == finalLabel!)
        .toList();
    if (matching.isEmpty) return null;
    return matching.fold(0.0, (s, d) => s + d.confidence) / matching.length;
  }

  int get finalDetCount =>
      detections.where((d) => d.className == finalLabel).length;
}

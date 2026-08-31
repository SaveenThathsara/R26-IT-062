import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../utils/theme.dart';

class DetectionOverlay extends StatelessWidget {
  final DetectionResult result;
  const DetectionOverlay({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _BoxPainter(result: result),
        );
      },
    );
  }
}

class _BoxPainter extends CustomPainter {
  final DetectionResult result;

  static const _classColors = {
    'Green-Leafhopper': Color(0xFF4ADE80),
    'aphid': Color(0xFFF87171),
    'beetle': Color(0xFF38BDF8),
    'grasshopper': Color(0xFFFBBF24),
  };

  _BoxPainter({required this.result});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / result.imageWidth;
    final scaleY = size.height / result.imageHeight;

    for (final det in result.detections) {
      final color = _classColors[det.className] ?? AppColors.accent;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final rect = Rect.fromLTWH(
        det.bbox.x1 * scaleX,
        det.bbox.y1 * scaleY,
        det.bbox.width * scaleX,
        det.bbox.height * scaleY,
      );
      canvas.drawRect(rect, paint);

      // Corner accents
      _drawCorner(canvas, rect, color);

      // Label
      final label =
          '${det.className}  ${(det.confidence * 100).toStringAsFixed(1)}%';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final bgTop = rect.top - tp.height - 8;
      final bgRect = Rect.fromLTWH(
        rect.left,
        bgTop < 0 ? rect.top + 2 : bgTop,
        tp.width + 12,
        tp.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        Paint()..color = color.withOpacity(0.9),
      );
      tp.paint(canvas, Offset(bgRect.left + 6, bgRect.top + 3));
    }
  }

  void _drawCorner(Canvas canvas, Rect rect, Color color) {
    const len = 12.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(len, 0), p);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, len), p);
    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-len, 0), p);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, len), p);
    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), p);
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -len),
      p,
    );
    // Bottom-right
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-len, 0),
      p,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -len),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) => old.result != result;
}

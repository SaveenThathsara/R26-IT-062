import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'dart:convert';
import '../models/detection_result.dart';

class InferenceService {
  static const int _imgSize = 640;
  static const double _confThresh = 0.25;
  static const double _iouThresh = 0.45;

  OrtSession? _detSession;
  OrtSession? _featSession;

  Map<int, String> _id2name = {};
  List<String> _classes = [];
  double _oodThreshold = 0.0;
  Map<int, List<double>> _classMeans = {};
  Map<int, List<List<double>>> _classPrecisions = {};

  bool _initialized = false;

  // ─────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    OrtEnv.instance.init();

    final detBytes = await _assetBytes('assets/models/model.onnx');
    final featBytes = await _assetBytes('assets/models/feature_extractor.onnx');
    final opts = OrtSessionOptions();
    _detSession = OrtSession.fromBuffer(detBytes, opts);
    _featSession = OrtSession.fromBuffer(featBytes, opts);

    // label.json
    final lj =
        jsonDecode(await rootBundle.loadString('assets/models/label.json'))
            as Map<String, dynamic>;
    _classes = List<String>.from(lj['classes'] as List);
    _id2name = _parseId2Name(lj['id2name']);

    // ood_config.json
    final oj =
        jsonDecode(await rootBundle.loadString('assets/models/ood_config.json'))
            as Map<String, dynamic>;
    _oodThreshold = (oj['threshold'] as num).toDouble();
    _classMeans = _parseClassMeans(oj['class_means'] as Map<String, dynamic>);

    // ood_precisions.json
    final pj =
        jsonDecode(
              await rootBundle.loadString('assets/models/ood_precisions.json'),
            )
            as Map<String, dynamic>;
    _classPrecisions = _parseClassPrecisions(pj);

    _initialized = true;
  }

  Future<Uint8List> _assetBytes(String path) async {
    final d = await rootBundle.load(path);
    return d.buffer.asUint8List();
  }

  Map<int, String> _parseId2Name(dynamic raw) {
    if (raw is Map) {
      return Map.fromEntries(
        raw.entries.map(
          (e) => MapEntry(int.parse(e.key.toString()), e.value.toString()),
        ),
      );
    }
    return {for (int i = 0; i < _classes.length; i++) i: _classes[i]};
  }

  Map<int, List<double>> _parseClassMeans(Map<String, dynamic> raw) => raw.map(
    (k, v) => MapEntry(
      int.parse(k),
      (v as List).map((e) => (e as num).toDouble()).toList(),
    ),
  );

  Map<int, List<List<double>>> _parseClassPrecisions(Map<String, dynamic> raw) {
    final result = <int, List<List<double>>>{};
    for (final e in raw.entries) {
      if (!e.key.startsWith('class_')) continue;
      final id = int.parse(e.key.replaceFirst('class_', ''));
      result[id] = (e.value as List)
          .map(
            (row) => (row as List).map((v) => (v as num).toDouble()).toList(),
          )
          .toList();
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────
  // UNIVERSAL ORT OUTPUT → Float32List
  // Handles every structure the onnxruntime package can return:
  //   OrtValue, List, List<List<...>>, Map, num
  // ─────────────────────────────────────────────────────────────────
  Float32List _ortToFloat32(OrtValue? ortValue) {
    if (ortValue == null) return Float32List(0);

    // .value can be: Float32List, List, Map, or nested combinations
    final raw = ortValue.value;
    final flat = <double>[];
    _collectDoubles(raw, flat);
    return Float32List.fromList(flat);
  }

  void _collectDoubles(dynamic v, List<double> out) {
    if (v == null) return;

    if (v is double) {
      out.add(v);
      return;
    }
    if (v is num) {
      out.add(v.toDouble());
      return;
    }

    if (v is Float32List) {
      for (final x in v) out.add(x);
      return;
    }
    if (v is Float64List) {
      for (final x in v) out.add(x);
      return;
    }
    if (v is Int32List || v is Int64List) {
      for (final x in (v as TypedData).buffer.asFloat32List()) out.add(x);
      return;
    }

    if (v is List) {
      for (final item in v) _collectDoubles(item, out);
      return;
    }

    if (v is Map) {
      // Take values only — keys are irrelevant (usually output names)
      for (final item in v.values) _collectDoubles(item, out);
      return;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PRE-PROCESSING
  // ─────────────────────────────────────────────────────────────────
  Float32List _preprocess(img.Image image) {
    final r = img.copyResize(image, width: _imgSize, height: _imgSize);
    final buf = Float32List(_imgSize * _imgSize * 3);
    int idx = 0;
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < _imgSize; y++) {
        for (int x = 0; x < _imgSize; x++) {
          final p = r.getPixel(x, y);
          buf[idx++] =
              (c == 0
                  ? p.r
                  : c == 1
                  ? p.g
                  : p.b) /
              255.0;
        }
      }
    }
    return buf;
  }

  // ─────────────────────────────────────────────────────────────────
  // NMS
  // ─────────────────────────────────────────────────────────────────
  List<int> _nms(List<List<double>> boxes, List<double> scores) {
    final idx = List<int>.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final sup = List<bool>.filled(scores.length, false);
    final kept = <int>[];
    for (final i in idx) {
      if (sup[i]) continue;
      kept.add(i);
      for (final j in idx) {
        if (i == j || sup[j]) continue;
        if (_iou(boxes[i], boxes[j]) >= _iouThresh) sup[j] = true;
      }
    }
    return kept;
  }

  double _iou(List<double> a, List<double> b) {
    final xA = max(a[0], b[0]), yA = max(a[1], b[1]);
    final xB = min(a[2], b[2]), yB = min(a[3], b[3]);
    final inter = max(0.0, xB - xA) * max(0.0, yB - yA);
    if (inter == 0) return 0;
    return inter /
        ((a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter);
  }

  // ─────────────────────────────────────────────────────────────────
  // DETECTION POST-PROCESSING
  // YOLOv8 ONNX output: (1, 4+nc, num_anchors)  — already flattened
  // ─────────────────────────────────────────────────────────────────
  List<Detection> _postprocess(Float32List raw, int origH, int origW, int nc) {
    if (raw.isEmpty) return [];
    final rows = 4 + nc;
    final numAnchors = raw.length ~/ rows;
    if (numAnchors == 0) return [];

    final boxes = <List<double>>[];
    final scores = <double>[];
    final classIds = <int>[];

    for (int a = 0; a < numAnchors; a++) {
      double maxP = 0;
      int bestC = 0;
      for (int c = 0; c < nc; c++) {
        final p = raw[(4 + c) * numAnchors + a];
        if (p > maxP) {
          maxP = p;
          bestC = c;
        }
      }
      if (maxP < _confThresh) continue;

      final cx = raw[0 * numAnchors + a];
      final cy = raw[1 * numAnchors + a];
      final bw = raw[2 * numAnchors + a];
      final bh = raw[3 * numAnchors + a];

      boxes.add([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2]);
      scores.add(maxP);
      classIds.add(bestC);
    }

    if (boxes.isEmpty) return [];
    final kept = _nms(boxes, scores);

    final sx = origW / _imgSize;
    final sy = origH / _imgSize;

    return kept.map((i) {
      final b = boxes[i];
      return Detection(
        classId: classIds[i],
        className: _id2name[classIds[i]] ?? 'unknown',
        confidence: scores[i],
        bbox: BoundingBox(
          x1: b[0] * sx,
          y1: b[1] * sy,
          x2: b[2] * sx,
          y2: b[3] * sy,
        ),
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  // OOD — MAHALANOBIS
  // ─────────────────────────────────────────────────────────────────
  double _mahalanobis(
    List<double> feat,
    List<double> mu,
    List<List<double>> prec,
  ) {
    final d = List<double>.generate(feat.length, (i) => feat[i] - mu[i]);
    double val = 0;
    for (int i = 0; i < d.length; i++) {
      double inner = 0;
      for (int j = 0; j < d.length; j++) inner += prec[i][j] * d[j];
      val += d[i] * inner;
    }
    return sqrt(max(0.0, val));
  }

  double _minMaha(Float32List featRaw) {
    final feat = featRaw.map((e) => e.toDouble()).toList();
    double best = double.infinity;
    for (final e in _classMeans.entries) {
      final prec = _classPrecisions[e.key];
      if (prec == null) continue;
      final s = _mahalanobis(feat, e.value, prec);
      if (s < best) best = s;
    }
    return best == double.infinity ? 0.0 : best;
  }

  // ─────────────────────────────────────────────────────────────────
  // MAIN INFERENCE
  // ─────────────────────────────────────────────────────────────────
  Future<DetectionResult> runInference(String imagePath) async {
    await initialize();

    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Cannot decode image');

    final origH = image.height;
    final origW = image.width;
    final tensor = _preprocess(image);
    final shape = [1, 3, _imgSize, _imgSize];

    // ── Detection ─────────────────────────────────────────────────
    final detIn = OrtValueTensor.createTensorWithDataList(tensor, shape);
    final detOut = await _detSession!.runAsync(OrtRunOptions(), {
      _detSession!.inputNames[0]: detIn,
    });
    detIn.release();

    final detRaw = _ortToFloat32(detOut?[0]);
    final detections = _postprocess(detRaw, origH, origW, _classes.length);
    for (final v in detOut ?? []) v?.release();

    // ── Features ──────────────────────────────────────────────────
    final featIn = OrtValueTensor.createTensorWithDataList(tensor, shape);
    final featOut = await _featSession!.runAsync(OrtRunOptions(), {
      _featSession!.inputNames[0]: featIn,
    });
    featIn.release();

    final featRaw = _ortToFloat32(featOut?[0]);
    for (final v in featOut ?? []) v?.release();

    final maha = _minMaha(featRaw);

    return DetectionResult(
      imagePath: imagePath,
      imageWidth: origW,
      imageHeight: origH,
      detections: detections,
      mahalanobisDistance: maha,
      oodThreshold: _oodThreshold,
      isOod: maha > _oodThreshold,
    );
  }

  /// Call this ONCE to print exactly what ORT returns — paste output to me
  Future<String> debugOrtOutput(String imagePath) async {
    await initialize();

    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes)!;
    final tensor = _preprocess(image);
    final shape = [1, 3, _imgSize, _imgSize];

    final detIn = OrtValueTensor.createTensorWithDataList(tensor, shape);
    final detOut = await _detSession!.runAsync(OrtRunOptions(), {
      _detSession!.inputNames[0]: detIn,
    });
    detIn.release();

    final buffer = StringBuffer();
    buffer.writeln('=== ORT DEBUG ===');
    buffer.writeln('outputCount: ${detOut?.length}');

    for (int i = 0; i < (detOut?.length ?? 0); i++) {
      final v = detOut![i];
      buffer.writeln('--- output[$i] ---');
      buffer.writeln('  OrtValue type : ${v.runtimeType}');

      try {
        final val = v?.value;
        buffer.writeln('  .value type   : ${val.runtimeType}');

        if (val is List) {
          buffer.writeln('  List length   : ${val.length}');
          if (val.isNotEmpty) {
            buffer.writeln('  [0] type      : ${val[0].runtimeType}');
            if (val[0] is List && (val[0] as List).isNotEmpty) {
              buffer.writeln(
                '  [0][0] type   : ${(val[0] as List)[0].runtimeType}',
              );
              buffer.writeln('  [0].length    : ${(val[0] as List).length}');
            }
          }
        } else if (val is Map) {
          buffer.writeln('  Map keys      : ${val.keys.toList()}');
          for (final k in val.keys) {
            final mv = val[k];
            buffer.writeln('  [$k] type     : ${mv.runtimeType}');
            if (mv is List) {
              buffer.writeln('  [$k].length   : ${mv.length}');
              if (mv.isNotEmpty) {
                buffer.writeln('  [$k][0] type  : ${mv[0].runtimeType}');
              }
            }
          }
        } else if (val is Float32List) {
          buffer.writeln('  Float32List len: ${val.length}');
          buffer.writeln('  first 5       : ${val.take(5).toList()}');
        }
      } catch (e) {
        buffer.writeln('  ERROR reading .value: $e');
      }
      v?.release();
    }

    return buffer.toString();
  }

  void dispose() {
    _detSession?.release();
    _featSession?.release();
    OrtEnv.instance.release();
  }
}

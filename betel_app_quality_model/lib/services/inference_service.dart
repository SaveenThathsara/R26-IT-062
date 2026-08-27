import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import '../models/inference_result.dart';

/// Implements the full inference + OOD pipeline from the notebook.
///
/// Pipeline (mirrors Cell 22 / ONNX test cell):
///   1. Preprocess image  → (1, 3, 224, 224) float32 tensor
///      – resize to 224×224 with bilinear sampling
///      – normalize with ImageNet mean/std  [0.485,0.456,0.406] / [0.229,0.224,0.225]
///   2. Classification session  → logits (1, 5) → softmax probabilities
///   3. Feature extractor session → features (1, 1280)
///   4. Mahalanobis OOD scoring:
///      – compute D²(x,μ_c) = (x−μ_c)ᵀ Σ⁻¹ (x−μ_c) for each class c
///      – OOD score = min_c D²
///      – is_ood = ood_score > threshold  (95th-percentile of val IN-scores)
class InferenceService {
  static const int _imgSize = 224;
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  OrtSession? _classSession;
  OrtSession? _featSession;

  // OOD parameters loaded from betel_quality_ood_config.json
  double _oodThreshold = 0.0;
  int _numClasses = 5;
  List<String> _classNames = [];
  // class_means: (numClasses, 1280)
  late List<Float32List> _classMeans;
  // precision_matrix: (1280, 1280) — flattened row-major
  late Float32List _precMatrix;

  bool _initialized = false;

  bool get isInitialized => _initialized;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    OrtEnv.instance.init();

    // Load ONNX models from assets
    final classModelBytes =
        await _loadAsset('assets/models/betel_quality_model.onnx');
    final featModelBytes =
        await _loadAsset('assets/models/betel_quality_feature_extractor.onnx');

    final sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(2);

    _classSession =
        OrtSession.fromBuffer(classModelBytes, sessionOptions);
    _featSession =
        OrtSession.fromBuffer(featModelBytes, sessionOptions);

    // Load OOD config (class means + precision matrix + threshold)
    await _loadOodConfig();

    // Load labels
    await _loadLabels();

    _initialized = true;
  }

  Future<Uint8List> _loadAsset(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  Future<void> _loadOodConfig() async {
    final raw =
        await rootBundle.loadString('assets/models/betel_quality_ood_config.json');
    final Map<String, dynamic> cfg = json.decode(raw);

    _oodThreshold = (cfg['ood_threshold'] as num).toDouble();
    _numClasses = (cfg['num_classes'] as int);

    // class_means: List<List<double>> shape (numClasses, 1280)
    final meansRaw = cfg['class_means'] as List<dynamic>;
    _classMeans = meansRaw
        .map<Float32List>((row) => Float32List.fromList(
            (row as List<dynamic>).map<double>((v) => (v as num).toDouble()).toList()))
        .toList();

    // precision_matrix: List<List<double>> shape (1280, 1280)
    final precRaw = cfg['precision_matrix'] as List<dynamic>;
    final List<double> flat = [];
    for (final row in precRaw) {
      for (final v in (row as List<dynamic>)) {
        flat.add((v as num).toDouble());
      }
    }
    _precMatrix = Float32List.fromList(flat);
  }

  Future<void> _loadLabels() async {
    final raw =
        await rootBundle.loadString('assets/models/betel_quality_labels.json');
    final Map<String, dynamic> cfg = json.decode(raw);
    _classNames =
        (cfg['labels'] as List<dynamic>).map((e) => e.toString()).toList();
    _numClasses = _classNames.length;
  }

  // ── Preprocessing ─────────────────────────────────────────────────────────

  /// Mirrors val_transform from notebook Cell 7:
  ///   Resize(224, 224) → ToTensor → Normalize(mean, std)
  Float32List _preprocess(Uint8List imageBytes) {
    img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Failed to decode image.');

    // Resize to 224×224 using bilinear interpolation
    final resized =
        img.copyResize(decoded, width: _imgSize, height: _imgSize,
            interpolation: img.Interpolation.linear);

    // CHW float32 buffer: (3, 224, 224)
    final buffer = Float32List(3 * _imgSize * _imgSize);

    for (int y = 0; y < _imgSize; y++) {
      for (int x = 0; x < _imgSize; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final idx = y * _imgSize + x;
        buffer[0 * _imgSize * _imgSize + idx] =
            ((r - _mean[0]) / _std[0]).toDouble();
        buffer[1 * _imgSize * _imgSize + idx] =
            ((g - _mean[1]) / _std[1]).toDouble();
        buffer[2 * _imgSize * _imgSize + idx] =
            ((b - _mean[2]) / _std[2]).toDouble();
      }
    }

    return buffer;
  }

  // ── Mahalanobis distance ──────────────────────────────────────────────────

  /// Computes D²(x, μ_c) = (x−μ)ᵀ Σ⁻¹ (x−μ)  (pure Dart, matches notebook Cell 23).
  double _mahalanobisDist(
      Float32List features, Float32List mean, Float32List precision, int dim) {
    // diff = features - mean   shape (dim,)
    final diff = Float32List(dim);
    for (int i = 0; i < dim; i++) {
      diff[i] = features[i] - mean[i];
    }

    // left = diff @ precision   shape (dim,)   [matrix-vector product]
    final left = Float32List(dim);
    for (int i = 0; i < dim; i++) {
      double s = 0.0;
      for (int j = 0; j < dim; j++) {
        s += diff[j] * precision[j * dim + i];
      }
      left[i] = s;
    }

    // d2 = left · diff   (dot product)
    double d2 = 0.0;
    for (int i = 0; i < dim; i++) {
      d2 += left[i] * diff[i];
    }
    return d2;
  }

  /// Returns min Mahalanobis distance over all class means (the OOD score).
  double _oodScore(Float32List features) {
    final dim = features.length;
    double minDist = double.infinity;
    for (int c = 0; c < _numClasses; c++) {
      final d = _mahalanobisDist(features, _classMeans[c], _precMatrix, dim);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  // ── Softmax ───────────────────────────────────────────────────────────────

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  // ── Public inference API ──────────────────────────────────────────────────

  /// Full inference + OOD detection. Returns [InferenceResult].
  /// Matches predict_with_ood() from notebook Cell 22.
  Future<InferenceResult> predict(Uint8List imageBytes) async {
    if (!_initialized) await initialize();

    // 1. Preprocess
    final inputData = _preprocess(imageBytes);
    // Shape: [1, 3, 224, 224]
    final inputShape = [1, 3, _imgSize, _imgSize];

    // 2. Classification
    final classInput = OrtValueTensor.createTensorWithDataList(
        inputData, inputShape);
    final classInputs = {'input': classInput};
    final classOutputs = await _classSession!.runAsync(
        OrtRunOptions(), classInputs);
    final logitsTensor = classOutputs?.first?.value as List?;
    classInput.release();

    // Extract logits: nested list → flat list<double>
    final rawLogits = (logitsTensor is List && logitsTensor.isNotEmpty)
        ? (logitsTensor[0] as List).map<double>((v) => (v as num).toDouble()).toList()
        : List<double>.filled(_numClasses, 0.0);

    final probs = _softmax(rawLogits);
    final predIdx = probs.indexOf(probs.reduce(math.max));
    final confidence = probs[predIdx];

    // 3. Feature extraction
    final featInput = OrtValueTensor.createTensorWithDataList(
        inputData, inputShape);
    final featInputs = {'input': featInput};
    final featOutputs = await _featSession!.runAsync(
        OrtRunOptions(), featInputs);
    final featTensor = featOutputs?.first?.value as List?;
    featInput.release();

    // Extract feature vector (1, 1280) → Float32List (1280,)
    final rawFeatures = (featTensor is List && featTensor.isNotEmpty)
        ? (featTensor[0] as List).map<double>((v) => (v as num).toDouble()).toList()
        : List<double>.filled(1280, 0.0);
    final features = Float32List.fromList(rawFeatures);

    // 4. OOD scoring
    final oodScore = _oodScore(features);
    final isOod = oodScore > _oodThreshold;

    // Build class scores map
    final classScores = <String, double>{
      for (int i = 0; i < _numClasses; i++) _classNames[i]: probs[i]
    };

    return InferenceResult(
      predictedClass:
          isOod ? 'OOD — Rejected' : _classNames[predIdx],
      confidence: isOod ? null : confidence,
      oodScore: oodScore,
      threshold: _oodThreshold,
      isOod: isOod,
      classScores: classScores,
    );
  }

  void dispose() {
    _classSession?.release();
    _featSession?.release();
    OrtEnv.instance.release();
  }
}

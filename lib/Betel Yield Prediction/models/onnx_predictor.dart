import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'feature_engineering.dart';

/// Model accuracy metrics from notebook test-set evaluation (Section 5)
class ModelMetrics {
  static const double r2Train = 0.9980;
  static const double r2Val = 0.9452;
  static const double r2Test = 0.9448; // 94.48%
  static const double maeTest = 1.88;
  static const double rmseTest = 2.44;
  static const double mapeTest = 4.94;
  static const double maeVal = 1.90;
  static const double rmseVal = 2.47;
  static const double mapeVal = 4.98;
  static const double maeTrain = 0.62;
  static const double rmseTrain = 0.83;
  static const double mapeTrain = 1.61;

  // Section 14: 5-fold CV
  static const List<double> cvFoldScores = [
    0.9431,
    0.9458,
    0.9449,
    0.9443,
    0.9462,
  ];

  static double get cvMean =>
      cvFoldScores.reduce((a, b) => a + b) / cvFoldScores.length;

  // Added standard deviation to resolve the AboutScreen error
  static const double cvStdDev = 0.0011;

  // Section 13: Tolerance curve — tolerances=[1,2,3,4,5,7,10]
  static const List<int> toleranceLevels = [1, 2, 3, 4, 5, 7, 10];
  static const List<double> tolerancePercents = [
    36.2,
    64.8,
    79.3,
    87.5,
    92.1,
    96.8,
    99.1,
  ];

  // Section 13: AbsError stats
  static const double absErrorMean = 1.88;
  static const double absError90thPct = 4.21;
}

/// Yield range buckets from notebook Section 15:
/// bins=[20,30,35,40,45,50,55,68], labels=[...], right=False
class YieldBucket {
  static const List<double> bins = [20, 30, 35, 40, 45, 50, 55, 68];
  static const List<String> labels = [
    '20–29',
    '30–34',
    '35–39',
    '40–44',
    '45–49',
    '50–54',
    '55–67',
  ];

  static String? getBucket(double value) {
    for (int i = 0; i < bins.length - 1; i++) {
      if (value >= bins[i] && value < bins[i + 1]) return labels[i];
    }
    return null;
  }

  static String getBucketDisplay(double value) {
    final b = getBucket(value);
    if (b != null) return b;
    return value < 20 ? '< 20 (Very Low)' : '≥ 68 (Very High)';
  }

  static bool isInRange(double value) => value >= 20 && value < 68;
  static String getBucketDescription(String? b) {
    const d = {
      '20–29': 'Low Yield',
      '30–34': 'Below Average',
      '35–39': 'Average',
      '40–44': 'Above Average',
      '45–49': 'Good',
      '50–54': 'Very Good',
      '55–67': 'Excellent',
    };
    return d[b] ?? 'Out of Bucket Range';
  }

  static String getBucketEmoji(String? b) {
    const e = {
      '20–29': '🔴',
      '30–34': '🟠',
      '35–39': '🟡',
      '40–44': '🟢',
      '45–49': '🟢',
      '50–54': '💚',
      '55–67': '⭐',
    };
    return e[b] ?? '⚪';
  }
}

/// Regression report data (Section 5)
class RegressionReport {
  final String splitName;
  final double r2, mae, rmse, mape;
  const RegressionReport({
    required this.splitName,
    required this.r2,
    required this.mae,
    required this.rmse,
    required this.mape,
  });
  String get r2Percent => '${(r2 * 100).toStringAsFixed(2)}%';
}

class AllRegressionReports {
  static const train = RegressionReport(
    splitName: 'Train',
    r2: ModelMetrics.r2Train,
    mae: ModelMetrics.maeTrain,
    rmse: ModelMetrics.rmseTrain,
    mape: ModelMetrics.mapeTrain,
  );
  static const validation = RegressionReport(
    splitName: 'Validation',
    r2: ModelMetrics.r2Val,
    mae: ModelMetrics.maeVal,
    rmse: ModelMetrics.rmseVal,
    mape: ModelMetrics.mapeVal,
  );
  static const test = RegressionReport(
    splitName: 'Test',
    r2: ModelMetrics.r2Test,
    mae: ModelMetrics.maeTest,
    rmse: ModelMetrics.rmseTest,
    mape: ModelMetrics.mapeTest,
  );
}

/// ONNX Runtime predictor.
/// Loads model.onnx from assets and runs real XGBoost inference.
///
/// ONNX model spec (verified by inspecting model.onnx):
///   Input:  name='float_input', shape=[None, 25], dtype=float32
///   Output: name='variable',    shape=[None, 1],  dtype=float32
class OnnxPredictor {
  static OrtSession? _session;
  static bool _initialized = false;

  /// Must be called once before predict() — loads model from assets.
  static Future<void> initialize() async {
    if (_initialized) return;
    OrtEnv.instance.init();
    final rawAsset = await rootBundle.load('assets/model.onnx');
    final bytes = rawAsset.buffer.asUint8List();
    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);
    _initialized = true;
  }

  static bool get isReady => _initialized && _session != null;

  /// Run real ONNX inference.
  /// 1. Builds 25-feature vector via engineerFeatures() — same as notebook
  /// 2. Creates float32 tensor of shape [1, 25]
  /// 3. Runs sess.run(['variable'], {'float_input': tensor})
  /// 4. Returns prediction (float scalar = Leaf_Count_per_Bed)
  static Future<double> predict(Map<String, double> inputs) async {
    if (!isReady) await initialize();

    // Step 1: Engineer 25 features in feature_columns.json order
    final List<double> features = BetelFeatureEngineering.engineerFeatures(
      inputs,
    );

    // Step 2: Build float32 tensor [1, 25]
    final Float32List float32Data = Float32List.fromList(features);
    final inputTensor = OrtValueTensor.createTensorWithDataList(float32Data, [
      1,
      25,
    ]);

    // Step 3: Run inference
    final runOptions = OrtRunOptions();
    final outputs = await _session!.runAsync(
      runOptions,
      {'float_input': inputTensor},
      ['variable'],
    );

    // Step 4: Extract scalar prediction from output 'variable' [1,1]
    final outputTensor = outputs?[0];
    final outputData = outputTensor?.value as List<List<double>>;
    final prediction = outputData[0][0];

    // Cleanup
    inputTensor.release();
    runOptions.release();

    return prediction;
  }

  /// Full detailed prediction with all metadata for UI
  static Future<PredictionResult> predictDetailed(
    Map<String, double> inputs,
  ) async {
    final double pred = await predict(inputs);
    final conditions = BetelFeatureEngineering.getOptimalConditions(inputs);
    final engVals = BetelFeatureEngineering.getEngineeredValues(inputs);
    final contributions = await _getFeatureContributions(inputs, pred);
    final conditionsMet = conditions.values.where((v) => v).length;

    return PredictionResult(
      predictedLeafCount: pred,
      featureContributions: contributions,
      optimalConditions: conditions,
      conditionsMetCount: conditionsMet,
      totalConditions: 4,
      engineeredValues: engVals,
      yieldBucket: YieldBucket.getBucket(pred),
      isOutOfRange: !YieldBucket.isInRange(pred),
    );
  }

  /// Leave-one-out SHAP-style feature contributions using real ONNX model
  static Future<Map<String, double>> _getFeatureContributions(
    Map<String, double> inputs,
    double basePrediction,
  ) async {
    final contributions = <String, double>{};
    // Median values for baseline substitution
    const medians = {
      'Soil_Moisture': 60.0,
      'Rainfall': 200.0,
      'Humidity': 70.0,
      'N': 100.0,
      'P': 75.0,
      'K': 100.0,
      'Temperature': 28.0,
      'Soil_pH': 6.0,
    };
    for (final feat in BetelFeatureEngineering.baseFeatureNames) {
      final modified = Map<String, double>.from(inputs)
        ..[feat] = medians[feat]!;
      final withoutFeat = await predict(modified);
      contributions[feat] = basePrediction - withoutFeat;
    }
    return contributions;
  }

  static void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _initialized = false;
    _session = null;
  }
}

/// Full prediction result returned to UI
class PredictionResult {
  final double predictedLeafCount;
  final Map<String, double> featureContributions;
  final Map<String, bool> optimalConditions;
  final int conditionsMetCount, totalConditions;
  final Map<String, double> engineeredValues;
  final String? yieldBucket;
  final bool isOutOfRange;

  const PredictionResult({
    required this.predictedLeafCount,
    required this.featureContributions,
    required this.optimalConditions,
    required this.conditionsMetCount,
    required this.totalConditions,
    required this.engineeredValues,
    required this.yieldBucket,
    required this.isOutOfRange,
  });

  String get bucketDisplay => YieldBucket.getBucketDisplay(predictedLeafCount);
  String get bucketDescription => YieldBucket.getBucketDescription(yieldBucket);
  String get bucketEmoji => YieldBucket.getBucketEmoji(yieldBucket);
  double get r2 => ModelMetrics.r2Test;
  double get mae => ModelMetrics.maeTest;
  double get rmse => ModelMetrics.rmseTest;
  double get mape => ModelMetrics.mapeTest;
}

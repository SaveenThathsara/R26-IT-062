import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../models/onnx_predictor.dart';
import '../models/feature_engineering.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';

class ResultScreen extends StatelessWidget {
  final PredictionResult result;
  final Map<String, double> inputs;
  const ResultScreen({super.key, required this.result, required this.inputs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Prediction Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 16),
        //     child: Center(
        //       child: Container(
        //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        //         decoration: BoxDecoration(
        //           color: AppColors.accent.withOpacity(0.1),
        //           borderRadius: BorderRadius.circular(20),
        //           border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        //         ),
        //         child: Text('XGBoost · ONNX',
        //             style: GoogleFonts.jetBrainsMono(
        //                 fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
        //       ),
        //     ),
        //   ),
        // ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Main prediction + yield bucket
            FadeInDown(duration: const Duration(milliseconds: 500),
                child: _MainPredictionCard(result: result)),
            const SizedBox(height: 14),

            // 2. Yield range bucket (Section 15 — exact bins/labels)
            FadeInDown(duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 80),
                child: _YieldBucketCard(result: result)),
            const SizedBox(height: 14),

            // 7. Optimal conditions (Section 2 flags)
            FadeInDown(duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 480),
                child: _OptimalConditionsCard(result: result, inputs: inputs)),
            const SizedBox(height: 14),

            // 8. Feature contributions (SHAP-style, Section 12)
            FadeInDown(duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 560),
                child: _FeatureContributionCard(result: result)),
            const SizedBox(height: 14),

            // 9. Input summary
            FadeInDown(duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 640),
                child: _InputSummaryCard(inputs: inputs)),
            const SizedBox(height: 14),

            // 10. All 25 engineered features (Section 2 pipeline)
            FadeInDown(duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 720),
                child: _EngineeredFeaturesCard(result: result)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── 1. Main prediction card ──────────────────────────────────────────────────
class _MainPredictionCard extends StatelessWidget {
  final PredictionResult result;
  const _MainPredictionCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.bgSecondary, AppColors.bgElevated],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.12), blurRadius: 30, spreadRadius: 4)],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Predicted Leaf Count per Bed',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                child: Text(result.predictedLeafCount.toStringAsFixed(2),
                    style: GoogleFonts.jetBrainsMono(fontSize: 56, fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(' leaves',
                    style: GoogleFonts.inter(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Out-of-range warning — mirrors notebook "⚠ N samples fell outside bin range"
          if (result.isOutOfRange)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent3.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent3.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.accent3),
                  const SizedBox(width: 6),
                  Text('⚠ Value outside bucket range [20–68)',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.accent3)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _bucketColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _bucketColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result.bucketEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text('${result.bucketDescription}  (${result.bucketDisplay} leaves)',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _bucketColor)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('✔ Prediction carries ~±${result.mae.toStringAsFixed(1)} leaf margin of error',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _bucketColor {
    switch (result.yieldBucket) {
      case '20–29': return AppColors.error;
      case '30–34': return AppColors.accent3;
      case '35–39': return AppColors.accent3;
      case '40–44': return AppColors.success;
      case '45–49': return AppColors.success;
      case '50–54': return AppColors.accent;
      case '55–67': return AppColors.accent;
      default: return AppColors.textSecondary;
    }
  }
}

// ── 2. Yield Bucket Card — exact Section 15 bins ─────────────────────────────
class _YieldBucketCard extends StatelessWidget {
  final PredictionResult result;
  const _YieldBucketCard({required this.result});

  @override
  Widget build(BuildContext context) {
    // bins = [20,30,35,40,45,50,55,68], labels = 7 buckets
    const bins   = YieldBucket.bins;
    const labels = YieldBucket.labels;

    return GlowCard(
      glowColor: AppColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Yield Range Bucket',
            subtitle: 'Section 15 — bins=[20,30,35,40,45,50,55,68] right=False',
          ),
          // Show all 7 buckets as tiles, highlight the active one
          Wrap(
            spacing: 6, runSpacing: 6,
            children: List.generate(labels.length, (i) {
              final label = labels[i];
              final isActive = label == result.yieldBucket;
              final color = isActive ? AppColors.accent : AppColors.textMuted;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accent.withOpacity(0.15) : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.5), width: isActive ? 1.5 : 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 12, fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
                            color: color)),
                    if (isActive)
                      Text('← YOUR VALUE',
                          style: GoogleFonts.inter(fontSize: 8, color: AppColors.accent)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Text(result.bucketEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.bucketDescription,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text('Bucket: ${result.bucketDisplay} leaves/bed',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary)),
                  if (result.isOutOfRange)
                    Text('⚠ Outside bucket range — excluded in notebook classification report',
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent3)),
                ],
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── 3. Regression Report — Section 5 (Train/Val/Test) ────────────────────────
class _RegressionReportCard extends StatelessWidget {
  const _RegressionReportCard();

  @override
  Widget build(BuildContext context) {
    final reports = [AllRegressionReports.train, AllRegressionReports.validation, AllRegressionReports.test];
    final colors  = [AppColors.accent, AppColors.accent2, AppColors.blue];

    return GlowCard(
      glowColor: AppColors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Regression Report',
            subtitle: 'Section 5 — regression_report() on Train / Val / Test',
          ),
          // Header row
          _TableRow(cells: const ['Split', 'R²', 'MAE', 'RMSE', 'MAPE%'],
              isHeader: true, color: AppColors.accent),
          const Divider(color: AppColors.border, height: 1),
          ...List.generate(reports.length, (i) {
            final r = reports[i];
            return _TableRow(
              cells: [
                r.splitName,
                r.r2Percent,
                r.mae.toStringAsFixed(4),
                r.rmse.toStringAsFixed(4),
                '${r.mape.toStringAsFixed(2)}%',
              ],
              color: colors[i],
              isHeader: false,
            );
          }),
          const SizedBox(height: 10),
          // R² bar comparison
          ...List.generate(reports.length, (i) {
            final r = reports[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 78,
                    child: Text(r.splitName,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: r.r2,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(colors[i]),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(r.r2Percent,
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: colors[i], fontWeight: FontWeight.w700)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;
  final Color color;
  const _TableRow({required this.cells, required this.isHeader, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: cells.asMap().entries.map((e) {
          final isFirst = e.key == 0;
          return Expanded(
            flex: isFirst ? 2 : 2,
            child: Text(e.value,
                style: isHeader
                    ? GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)
                    : isFirst
                        ? GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.w600)
                        : GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textPrimary),
                textAlign: isFirst ? TextAlign.left : TextAlign.center),
          );
        }).toList(),
      ),
    );
  }
}

// ── 4. Tolerance Curve — Section 13 ──────────────────────────────────────────
// tolerances = [1,2,3,4,5,7,10], % within each tolerance
class _ToleranceCurveCard extends StatelessWidget {
  const _ToleranceCurveCard();

  @override
  Widget build(BuildContext context) {
    final tolerances = ModelMetrics.toleranceLevels;
    final percents   = ModelMetrics.tolerancePercents;
    final maxPct     = percents.last; // 99.1

    return GlowCard(
      glowColor: AppColors.accent3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Prediction Tolerance Curve',
            subtitle: 'Section 13 — % predictions within ±N leaves (Test set)',
          ),
          // Bar chart representation
          ...List.generate(tolerances.length, (i) {
            final pct = percents[i];
            final isTarget = pct >= 95.0; // notebook's 95% axhline
            final color = isTarget ? AppColors.success : AppColors.accent3;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 28,
                    child: Text('±${tolerances[i]}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textSecondary))),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct / 100.0,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 44,
                    child: Text('${pct.toStringAsFixed(1)}%',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right)),
                if (isTarget)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                  ),
              ]),
            );
          }),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.success),
              const SizedBox(width: 6),
              Text('95% threshold line — matches notebook axhline(95)',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── 5. Cross-Validation — Section 14 ─────────────────────────────────────────
// 5-fold KFold, shuffle=True, random_state=42, scoring='r2'
class _CrossValidationCard extends StatelessWidget {
  const _CrossValidationCard();

  @override
  Widget build(BuildContext context) {
    final folds  = ModelMetrics.cvFoldScores;
    final mean   = ModelMetrics.cvMean;
    final std    = ModelMetrics.cvStdDev;
    final minVal = folds.reduce((a, b) => a < b ? a : b);
    final maxVal = folds.reduce((a, b) => a > b ? a : b);

    return GlowCard(
      glowColor: AppColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: '5-Fold Cross-Validation',
            subtitle: 'Section 14 — KFold(n_splits=5, shuffle=True, random_state=42), scoring="r2"',
          ),
          // Fold scores
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(folds.length, (i) {
                final v = folds[i];
                final isMin = v == minVal;
                final isMax = v == maxVal;
                final color = isMax ? AppColors.accent : (isMin ? AppColors.accent2 : AppColors.blue);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(width: 48,
                        child: Text('Fold ${i+1}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: v,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 58,
                        child: Text('${(v * 100).toStringAsFixed(2)}%',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                            textAlign: TextAlign.right)),
                  ]),
                );
              }),
            )),
          ]),
          const SizedBox(height: 10),
          // Summary stats matching notebook print output
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CV R²: ${mean.toStringAsFixed(4)} ± ${std.toStringAsFixed(4)}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
                const SizedBox(height: 4),
                Text('Fold scores: [${folds.map((s) => s.toStringAsFixed(4)).join(", ")}]',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 6. Absolute Error Distribution — Section 13 ───────────────────────────────
class _AbsErrorCard extends StatelessWidget {
  const _AbsErrorCard();

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: AppColors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Test Absolute Error Distribution',
            subtitle: 'Section 13 — abs_err = |y_test − y_pred|',
          ),
          Row(children: [
            Expanded(child: MetricChip(
              label: 'Mean AbsErr',
              value: ModelMetrics.absErrorMean.toStringAsFixed(2),
              color: AppColors.accent3,
              subtitle: 'leaves',
            )),
            const SizedBox(width: 8),
            Expanded(child: MetricChip(
              label: '90th Pctile',
              value: ModelMetrics.absError90thPct.toStringAsFixed(2),
              color: AppColors.accent2,
              subtitle: 'leaves',
            )),
            const SizedBox(width: 8),
            Expanded(child: MetricChip(
              label: 'RMSE',
              value: ModelMetrics.rmseTest.toStringAsFixed(2),
              color: AppColors.blue,
              subtitle: 'leaves',
            )),
          ]),
          const SizedBox(height: 12),
          // Visual histogram approximation using bars
          _AbsErrorHistogram(),
        ],
      ),
    );
  }
}

class _AbsErrorHistogram extends StatelessWidget {
  // Approximate histogram based on MAE=1.88, RMSE=2.44 — normal-like distribution
  final List<_HistBin> bins = const [
    _HistBin('0–1',  0.362, AppColors.accent),
    _HistBin('1–2',  0.286, AppColors.accent),
    _HistBin('2–3',  0.145, AppColors.blue),
    _HistBin('3–4',  0.082, AppColors.blue),
    _HistBin('4–5',  0.049, AppColors.accent3),
    _HistBin('5–7',  0.052, AppColors.accent3),
    _HistBin('7–10', 0.024, AppColors.accent2),
  ];
  const _AbsErrorHistogram();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Approximate error histogram (Test set):',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ...bins.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            SizedBox(width: 36,
                child: Text(b.label, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted))),
            const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: b.fraction,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(b.color),
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${(b.fraction * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: b.color)),
          ]),
        )),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 10, height: 10, color: AppColors.accent3),
          const SizedBox(width: 4),
          Text('Mean=1.88  ', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent3)),
          Container(width: 10, height: 10, color: AppColors.accent2),
          const SizedBox(width: 4),
          Text('90th pct=4.21', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent2)),
        ]),
      ],
    );
  }
}

class _HistBin {
  final String label;
  final double fraction;
  final Color color;
  const _HistBin(this.label, this.fraction, this.color);
}

// ── 7. Optimal Conditions — Section 2 binary flags ───────────────────────────
class _OptimalConditionsCard extends StatelessWidget {
  final PredictionResult result;
  final Map<String, double> inputs;
  const _OptimalConditionsCard({required this.result, required this.inputs});

  @override
  Widget build(BuildContext context) {
    final metCount = result.conditionsMetCount;
    return GlowCard(
      glowColor: metCount >= 3 ? AppColors.success : AppColors.accent3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Optimal Range Flags',
            subtitle: 'Section 2 — binary features (int cast, right=False)',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (metCount >= 3 ? AppColors.success : AppColors.accent3).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$metCount/4 = 1',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700,
                      color: metCount >= 3 ? AppColors.success : AppColors.accent3)),
            ),
          ),
          // Each flag exactly matches the notebook condition
          _FlagRow('optimal_moisture', 'Soil_Moisture',
              '55 ≤ SM ≤ 75', inputs['Soil_Moisture']!,
              result.optimalConditions['optimal_moisture'] ?? false),
          _FlagRow('optimal_temp', 'Temperature',
              '25 ≤ Temp ≤ 32', inputs['Temperature']!,
              result.optimalConditions['optimal_temp'] ?? false),
          _FlagRow('optimal_pH', 'Soil_pH',
              '5.5 ≤ pH ≤ 7.0', inputs['Soil_pH']!,
              result.optimalConditions['optimal_pH'] ?? false),
          _FlagRow('optimal_rain', 'Rainfall',
              '150 ≤ Rain ≤ 300', inputs['Rainfall']!,
              result.optimalConditions['optimal_rain'] ?? false),
        ],
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  final String flagName, featName, condition;
  final double value;
  final bool isMet;
  const _FlagRow(this.flagName, this.featName, this.condition, this.value, this.isMet);

  @override
  Widget build(BuildContext context) {
    final color = isMet ? AppColors.success : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(flagName,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              Text(condition,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ],
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('value: ${value.toStringAsFixed(1)}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textSecondary)),
              Text('flag = ${isMet ? "1" : "0"}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── 8. Feature Contribution (SHAP-style) — Section 12 ────────────────────────
class _FeatureContributionCard extends StatelessWidget {
  final PredictionResult result;
  const _FeatureContributionCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final sorted = result.featureContributions.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final maxAbs = sorted.isEmpty ? 1.0 : sorted.first.value.abs();

    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Feature Contributions',
            subtitle: 'Section 12 — SHAP-style leave-one-out on 8 base features',
          ),
          ...sorted.map((e) {
            final isPos = e.value >= 0;
            final color = isPos ? AppColors.accent : AppColors.accent2;
            final frac  = maxAbs > 0 ? (e.value.abs() / maxAbs) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Text(BetelFeatureEngineering.featureIcons[e.key] ?? '📊',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                SizedBox(width: 110,
                    child: Text(e.key.replaceAll('_', ' '),
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: frac.toDouble(), backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 8),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 52,
                    child: Text('${isPos ? "+" : ""}${e.value.toStringAsFixed(2)}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ── 9. Input Summary ──────────────────────────────────────────────────────────
class _InputSummaryCard extends StatelessWidget {
  final Map<String, double> inputs;
  const _InputSummaryCard({required this.inputs});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Input Summary', subtitle: '8 base features (BASE_FEATURES list)'),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 3.2,
            children: BetelFeatureEngineering.baseFeatureNames.map((name) {
              final value = inputs[name] ?? 0.0;
              final icon  = BetelFeatureEngineering.featureIcons[name] ?? '📊';
              final unit  = BetelFeatureEngineering.featureUnits[name] ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Text(icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name.replaceAll('_', ' '),
                          style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis),
                      Text('${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} $unit',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  )),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── 10. All 25 Engineered Features — Section 2 pipeline ──────────────────────
class _EngineeredFeaturesCard extends StatefulWidget {
  final PredictionResult result;
  const _EngineeredFeaturesCard({required this.result});
  @override State<_EngineeredFeaturesCard> createState() => _EngineeredFeaturesCardState();
}

class _EngineeredFeaturesCardState extends State<_EngineeredFeaturesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entries   = widget.result.engineeredValues.entries.toList();
    final displayed = _expanded ? entries : entries.take(8).toList();

    return GlowCard(
      glowColor: AppColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Engineered Feature Vector',
            subtitle: 'Section 2 — engineer_features_single() → 25 values passed to ONNX',
            trailing: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Show less' : 'All 25 →',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.accent)),
            ),
          ),
          ...displayed.asMap().entries.map((e) {
            final idx   = e.key;
            final entry = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                SizedBox(width: 22,
                    child: Text('f$idx',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted))),
                const SizedBox(width: 6),
                SizedBox(width: 160,
                    child: Text(entry.key,
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis)),
                Expanded(child: Container(height: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 6))),
                Text(_fmtVal(entry.value),
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ]),
            );
          }),
          if (!_expanded && entries.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('… ${entries.length - 8} more features hidden',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }

  String _fmtVal(double v) {
    if (v == v.roundToDouble() && v.abs() < 10000) return v.toInt().toString();
    if (v.abs() > 100000) return v.toStringAsExponential(2);
    return v.toStringAsFixed(3);
  }
}

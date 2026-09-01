import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../models/feature_engineering.dart';
import '../models/onnx_predictor.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Notebook sample input (Section 17):
  // SM=60, Rain=100, Hum=70, N=135, P=45, K=100, T=29, pH=6 → 35.73 leaves (real ONNX)
  final Map<String, double> _inputs = {
    'Soil_Moisture': 60.0,
    'Rainfall':      100.0,
    'Humidity':      70.0,
    'N':             135.0,
    'P':             45.0,
    'K':             100.0,
    'Temperature':   29.0,
    'Soil_pH':       6.0,
  };

  final Map<String, String?> _errors = {};
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  bool _validateInputs() {
    _errors.clear();
    bool valid = true;
    for (final feat in BetelFeatureEngineering.baseFeatureNames) {
      final bounds = BetelFeatureEngineering.inputBounds[feat]!;
      final val = _inputs[feat]!;
      if (val < bounds['min']! || val > bounds['max']!) {
        // Mirrors notebook: "⚠  Please enter a valid number."
        _errors[feat] = '⚠ Valid range: ${bounds['min']} – ${bounds['max']} ${BetelFeatureEngineering.featureUnits[feat]}';
        valid = false;
      }
    }
    setState(() {});
    return valid;
  }

  Future<void> _predict() async {
    if (!_validateInputs()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠  Please enter valid numbers within the allowed ranges.',
            style: GoogleFonts.inter(color: AppColors.bgPrimary)),
        backgroundColor: AppColors.accent3,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _isCalculating = true);

    try {
      // Real ONNX inference — same as notebook sess.run(['variable'], {'float_input': arr})
      final result = await OnnxPredictor.predictDetailed(_inputs);
      if (!mounted) return;
      Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            ResultScreen(result: result, inputs: Map.from(_inputs)),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('ONNX inference error: $e',
            style: GoogleFonts.inter(color: AppColors.bgPrimary)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  void _resetSample() => setState(() {
    _inputs.addAll({'Soil_Moisture':60.0,'Rainfall':100.0,'Humidity':70.0,
      'N':135.0,'P':45.0,'K':100.0,'Temperature':29.0,'Soil_pH':6.0});
    _errors.clear();
  });

  void _resetOptimal() => setState(() {
    _inputs.addAll({'Soil_Moisture':65.0,'Rainfall':225.0,'Humidity':75.0,
      'N':150.0,'P':80.0,'K':120.0,'Temperature':28.5,'Soil_pH':6.25});
    _errors.clear();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: CustomScrollView(slivers: [
        // ── App bar ───────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 85,
          floating: false, pinned: true,
          backgroundColor: AppColors.bgPrimary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF0F1117), Color(0xFF1A1D27)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 8),
                  Row(children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: AppColors.accentGradient),
                        child: const Center(child: Text('🌿', style: TextStyle(fontSize: 22))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      GradientText('Betel Yield Predictor',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                      // Text('XGBoost · ONNX Runtime · R² 94.48%',
                      //     style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ]),
                  // const SizedBox(height: 12),
                  // Row(children: [
                  //   _Stat('Features', '25', AppColors.accent),
                  //   const SizedBox(width: 16),
                  //   _Stat('R² Test', '94.48%', AppColors.blue),
                  //   const SizedBox(width: 16),
                  //   _Stat('MAE', '±1.88', AppColors.purple),
                  //   const SizedBox(width: 16),
                  //   _Stat('MAPE', '4.94%', AppColors.accent2),
                  // ]),
                ]),
              )),
            ),
          ),
          title: Row(children: [
            const Text('🌿', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            // Text('Betel Yield Predictor',
            //     style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
          // actions: [
          //   PopupMenuButton<String>(
          //     icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
          //     color: AppColors.bgCard,
          //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
          //         side: const BorderSide(color: AppColors.border)),
          //     onSelected: (v) { if (v=='sample') _resetSample(); if (v=='optimal') _resetOptimal(); },
          //     itemBuilder: (_) => [
          //       PopupMenuItem(value: 'sample', child: Row(children: [
          //         const Icon(Icons.science_outlined, size: 16, color: AppColors.textSecondary),
          //         const SizedBox(width: 8),
          //         Text('Notebook sample (→35.73 leaves)',
          //             style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
          //       ])),
          //       PopupMenuItem(value: 'optimal', child: Row(children: [
          //         const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accent),
          //         const SizedBox(width: 8),
          //         Text('All optimal flags = 1',
          //             style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
          //       ])),
          //     ],
          //   ),
          //   const SizedBox(width: 8),
          // ],
        ),

        // ── Input form ────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([

            // // Info banner
            // FadeInDown(duration: const Duration(milliseconds: 400), child: Container(
            //   padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 14),
            //   decoration: BoxDecoration(
            //     color: AppColors.accent.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
            //     border: Border.all(color: AppColors.accent.withOpacity(0.2))),
            //   child: Row(children: [
            //     const Icon(Icons.memory_rounded, size: 15, color: AppColors.accent),
            //     const SizedBox(width: 8),
            //     Expanded(child: Text(
            //       'Enter 8 base features → engineer_features_single() builds 25 features → '
            //       'XGBoost ONNX model (float_input [1×25]) → Leaf_Count_per_Bed prediction.',
            //       style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
            //   ]),
            // )),

            FadeInDown(duration: const Duration(milliseconds: 400), delay: const Duration(milliseconds: 40),
                child: _SectionLabel('Soil Conditions', '🌱')),
            ..._buildFields(['Soil_Moisture', 'Soil_pH'], 80),
            const SizedBox(height: 14),

            FadeInDown(duration: const Duration(milliseconds: 400), delay: const Duration(milliseconds: 140),
                child: _SectionLabel('Weather', '🌤️')),
            ..._buildFields(['Rainfall', 'Humidity', 'Temperature'], 180),
            const SizedBox(height: 14),

            FadeInDown(duration: const Duration(milliseconds: 400), delay: const Duration(milliseconds: 240),
                child: _SectionLabel('NPK Fertilizer', '🧪')),
            ..._buildFields(['N', 'P', 'K'], 280),
            const SizedBox(height: 18),

            // Live optimal flags
            // FadeInDown(duration: const Duration(milliseconds: 400), delay: const Duration(milliseconds: 360),
            //     child: _LiveFlagsCard(inputs: _inputs)),
            // const SizedBox(height: 18),
          ])),
        ),
      ]),

      // ── Predict button ────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _isCalculating ? null : _predict,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCalculating ? AppColors.bgElevated : AppColors.accent,
              foregroundColor: AppColors.bgPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isCalculating
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.accent.withOpacity(0.7)))),
                    const SizedBox(width: 12),
                    Text('Running ONNX inference…',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ])
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.analytics_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text('Predict Leaf Count per Bed',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields(List<String> feats, int baseDelay) =>
      feats.asMap().entries.map((e) {
        final name   = e.value;
        final bounds = BetelFeatureEngineering.inputBounds[name]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FadeInLeft(
            duration: const Duration(milliseconds: 400),
            delay: Duration(milliseconds: baseDelay + e.key * 50),
            child: FeatureInputField(
              featureName:  name,
              displayName:  name.replaceAll('_', ' '),
              unit:         BetelFeatureEngineering.featureUnits[name] ?? '',
              icon:         BetelFeatureEngineering.featureIcons[name] ?? '📊',
              description:  BetelFeatureEngineering.featureDescriptions[name] ?? '',
              minValue:     bounds['min']!,
              maxValue:     bounds['max']!,
              currentValue: _inputs[name]!,
              errorText:    _errors[name],
              onChanged:    (v) => setState(() { _inputs[name] = v; _errors.remove(name); }),
            ),
          ),
        );
      }).toList();
}

// Live optimal flags widget
// class _LiveFlagsCard extends StatelessWidget {
//   final Map<String, double> inputs;
//   const _LiveFlagsCard({required this.inputs});

//   @override
//   Widget build(BuildContext context) {
//     final sm   = inputs['Soil_Moisture'] ?? 0;
//     final temp = inputs['Temperature']   ?? 0;
//     final ph   = inputs['Soil_pH']       ?? 0;
//     final rain = inputs['Rainfall']      ?? 0;

//     final flags = {
//       'optimal_moisture': sm   >= 55 && sm   <= 75,
//       'optimal_temp':     temp >= 25 && temp <= 32,
//       'optimal_pH':       ph   >= 5.5 && ph  <= 7.0,
//       'optimal_rain':     rain >= 150 && rain <= 300,
//     };
//     final metCount = flags.values.where((v) => v).length;

//     return GlowCard(
//       glowColor: metCount >= 3 ? AppColors.success : AppColors.accent3,
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         SectionHeader(
//           title: 'Live Optimal Flags',
//           subtitle: 'Section 2 — int(condition) — these are features 21–24 of the ONNX input',
//           trailing: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: (metCount >= 3 ? AppColors.success : AppColors.accent3).withOpacity(0.15),
//               borderRadius: BorderRadius.circular(8)),
//             child: Text('$metCount/4 = 1',
//                 style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700,
//                     color: metCount >= 3 ? AppColors.success : AppColors.accent3)),
//           ),
//         ),
//         Row(children: [
//           _FlagChip('optimal_moisture', flags['optimal_moisture']!, '55–75%',  21),
//           const SizedBox(width: 6),
//           _FlagChip('optimal_temp',     flags['optimal_temp']!,     '25–32°C', 22),
//         ]),
//         const SizedBox(height: 6),
//         Row(children: [
//           _FlagChip('optimal_pH',       flags['optimal_pH']!,       '5.5–7.0', 23),
//           const SizedBox(width: 6),
//           _FlagChip('optimal_rain',     flags['optimal_rain']!,     '150–300mm',24),
//         ]),
//       ]),
//     );
//   }
// }

class _FlagChip extends StatelessWidget {
  final String label;
  final bool value;
  final String range;
  final int featureIndex;
  const _FlagChip(this.label, this.value, this.range, this.featureIndex);

  @override
  Widget build(BuildContext context) {
    final color = value ? AppColors.success : AppColors.textMuted;
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Icon(value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: color, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('f$featureIndex', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppColors.textMuted)),
          Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          Text(range, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
        ])),
        Text(value ? '1' : '0',
            style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ]),
    ));
  }
}

class _SectionLabel extends StatelessWidget {
  final String label, icon;
  const _SectionLabel(this.label, this.icon);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 0.5)),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: AppColors.border)),
    ]),
  );
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text('$label: ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
    Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  ]);
}

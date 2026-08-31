import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/theme.dart';
import '../services/inference_service.dart';
import '../models/detection_result.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/result_panel.dart';
import '../widgets/ood_badge.dart';
import '../widgets/source_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  final _inferenceService = InferenceService();

  String? _imagePath;
  DetectionResult? _result;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Pre-warm
    _inferenceService.initialize().catchError((_) {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;

      setState(() {
        _imagePath = picked.path;
        _result = null;
        _errorMessage = null;
        _isLoading = true;
      });

      final result = await _inferenceService.runInference(picked.path);

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  void _reset() => setState(() {
    _imagePath = null;
    _result = null;
    _errorMessage = null;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: _buildAppBar(),
      body: _imagePath == null ? _buildWelcome() : _buildAnalysisView(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bgPrimary,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bug_report,
              size: 18,
              color: AppColors.bgPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'BetelDetect',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Text(
              'YOLOv8',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (_imagePath != null)
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
      ],
    );
  }

  // ── Welcome screen ────────────────────────────────────────────────
  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.biotech_rounded,
                  size: 56,
                  color: AppColors.bgPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Betel Insect Detector',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Detect and classify insects on betel crops\nusing YOLOv8 with OOD detection.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildClassGrid(),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: SourceButton(
                  label: 'Gallery',
                  icon: Icons.photo_library_rounded,
                  gradient: AppColors.accentGradient,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SourceButton(
                  label: 'Camera',
                  icon: Icons.camera_alt_rounded,
                  gradient: AppColors.purpleGradient,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildClassGrid() {
    const classes = [
      ('Green-Leafhopper', AppColors.success, Icons.grass),
      ('Aphid', AppColors.error, Icons.lens_blur),
      ('Beetle', AppColors.blue, Icons.circle),
      ('Grasshopper', AppColors.accent3, Icons.nature),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detectable Classes',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: classes.map((c) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: c.$2.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.$2.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.$3, size: 14, color: c.$2),
                  const SizedBox(width: 6),
                  Text(
                    c.$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.$2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFeatureRow() {
    final features = [
      ('Bounding Boxes', Icons.crop_free_rounded, AppColors.accent),
      ('Confidence', Icons.percent_rounded, AppColors.blue),
      ('OOD Detection', Icons.radar_rounded, AppColors.purple),
    ];
    return Row(
      children: features.map((f) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                Icon(f.$2, color: f.$3, size: 22),
                const SizedBox(height: 6),
                Text(
                  f.$1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Analysis view ─────────────────────────────────────────────────
  Widget _buildAnalysisView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildImageSection(),
          if (_isLoading) _buildLoadingSection(),
          if (_errorMessage != null) _buildErrorSection(),
          if (_result != null) ...[
            OodBadge(result: _result!),
            ResultPanel(result: _result!),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: SourceButton(
                    label: 'Gallery',
                    icon: Icons.photo_library_rounded,
                    gradient: AppColors.accentGradient,
                    onTap: () => _pickImage(ImageSource.gallery),
                    compact: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SourceButton(
                    label: 'Camera',
                    icon: Icons.camera_alt_rounded,
                    gradient: AppColors.purpleGradient,
                    onTap: () => _pickImage(ImageSource.camera),
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.file(
            File(_imagePath!),
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
        if (_result != null)
          Positioned.fill(child: DetectionOverlay(result: _result!)),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: AppColors.bgPrimary.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Running YOLOv8 inference…',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

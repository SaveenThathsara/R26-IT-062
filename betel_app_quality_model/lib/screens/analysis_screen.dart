import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../services/model_initializer.dart';


/// Camera + Gallery → ONNX inference → result display.
///
/// Pipeline (notebook Cell 22 / ONNX test cell):
///   1. User picks image (Camera or Gallery)
///   2. preprocess → (1, 3, 224, 224) float32 tensor
///      – resize 224×224 bilinear
///      – normalize: mean=[0.485,0.456,0.406] std=[0.229,0.224,0.225]
///   3. Classification session → logits → softmax probabilities
///   4. Feature extractor session → (1, 1280) features
///   5. Mahalanobis OOD scoring → min_c D²(x, μ_c)
///   6. is_ood = ood_score > threshold (95th pct val IN-dist)
class AnalysisScreen extends StatefulWidget {
  final bool useCamera;
  const AnalysisScreen({super.key, required this.useCamera});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _picker = ImagePicker();
  final _init = ModelInitializer.instance;

  Uint8List? _imageBytes;
  InferenceResult? _result;
  bool _analyzing = false;
  bool _initializing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> _boot() async {
    if (_init.state.value != ModelState.ready) {
      setState(() => _initializing = true);
      await _init.ensureReady();
      if (!mounted) return;
      if (_init.state.value == ModelState.error) {
        setState(() {
          _initializing = false;
          _error = 'Model failed to load:\n${_init.errorMessage}';
        });
        return;
      }
      setState(() => _initializing = false);
    }
    await _pickImage(widget.useCamera);
  }

  // ── Image picking + inference ──────────────────────────────────────────────

  Future<void> _pickImage(bool fromCamera) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (picked == null) {
        if (_imageBytes == null && mounted) Navigator.pop(context);
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _result = null;
        _analyzing = true;
        _error = null;
      });

      final result = await _init.service.predict(bytes);
      if (!mounted) return;
      setState(() {
        _result = result;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = 'Analysis failed:\n$e';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bgPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Quality Analysis',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        if (_imageBytes != null && !_analyzing && !_initializing)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _showSourceSheet,
              icon: const Icon(Icons.cameraswitch_rounded,
                  size: 16, color: AppColors.accent),
              label: Text('Retake',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return _CentredStatus(
        icon: const _Spinner(),
        title: 'Loading Model',
        subtitle: 'Initialising EfficientNetB0 + OOD detector…',
      );
    }

    if (_error != null && _imageBytes == null) {
      return _ErrorView(message: _error!, onRetry: _boot);
    }

    if (_imageBytes == null) {
      return _PickerPrompt(
        onCamera: () => _pickImage(true),
        onGallery: () => _pickImage(false),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ImagePreview(bytes: _imageBytes!),
          const SizedBox(height: 20),

          if (_analyzing)
            const _AnalyzingCard()
          else if (_error != null)
            _InlineError(
                message: _error!, onRetry: () => _pickImage(false))
          else if (_result != null) ...[
            ResultCard(result: _result!)
                .animate()
                .fadeIn(duration: 380.ms)
                .slideY(begin: 0.05, end: 0, duration: 350.ms),
            const SizedBox(height: 14),

            OodIndicator(result: _result!)
                .animate()
                .fadeIn(delay: 120.ms, duration: 380.ms),
            const SizedBox(height: 14),

            if (!_result!.isOod) ...[
              ConfidenceBars(result: _result!)
                  .animate()
                  .fadeIn(delay: 220.ms, duration: 380.ms),
              const SizedBox(height: 14),
            ],

            _DescriptionCard(result: _result!)
                .animate()
                .fadeIn(delay: 320.ms, duration: 380.ms),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_initializing || (_error != null && _imageBytes == null)) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(
            top: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PickerButton(
              icon: Icons.camera_alt_rounded,
              label: 'Camera',
              color: AppColors.accent,
              onTap: () => _pickImage(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PickerButton(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              color: AppColors.purple,
              onTap: () => _pickImage(false),
            ),
          ),
        ],
      ),
    );
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SourceSheet(
        onCamera: () {
          Navigator.pop(context);
          _pickImage(true);
        },
        onGallery: () {
          Navigator.pop(context);
          _pickImage(false);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  final Uint8List bytes;
  const _ImagePreview({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.accent.withOpacity(0.07),
              blurRadius: 24,
              spreadRadius: 1)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child:
            Image.memory(bytes, fit: BoxFit.cover, width: double.infinity),
      ),
    ).animate().scale(
          begin: const Offset(0.96, 0.96),
          duration: 320.ms,
          curve: Curves.easeOut,
        );
  }
}

class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 16),
          Text('Analysing…',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'EfficientNetB0 forward pass + Mahalanobis OOD scoring',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
            delay: 300.ms,
            duration: 1600.ms,
            color: AppColors.accent.withOpacity(0.10));
  }
}

class _DescriptionCard extends StatelessWidget {
  final InferenceResult result;
  const _DescriptionCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 15, color: AppColors.accent3),
              const SizedBox(width: 8),
              Text('Recommendation',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent3)),
            ],
          ),
          const SizedBox(height: 10),
          Text(result.gradeDescription,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6)),
        ],
      ),
    );
  }
}

class _CentredStatus extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  const _CentredStatus(
      {required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 20),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(AppColors.accent),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.10),
                  shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Something went wrong',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4))),
          TextButton(
              onPressed: onRetry,
              child: Text('Retry',
                  style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12))),
        ],
      ),
    );
  }
}

class _PickerPrompt extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _PickerPrompt({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border)),
              child: const Icon(Icons.eco_rounded,
                  color: AppColors.accent, size: 52),
            ),
            const SizedBox(height: 24),
            Text('Select a Betel Leaf',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Take a photo or choose from your gallery to begin '
              'AI quality grading.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _SourceSheet({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Image',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: _SheetTile(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        color: AppColors.accent,
                        onTap: onCamera)),
                const SizedBox(width: 12),
                Expanded(
                    child: _SheetTile(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        color: AppColors.purple,
                        onTap: onGallery)),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PickerButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

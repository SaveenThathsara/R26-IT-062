import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  const GradientText(this.text, {super.key, this.style, this.gradient = AppColors.accentGradient});
  @override
  Widget build(BuildContext context) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (b) => gradient.createShader(b),
      child: Text(text, style: style));
}

class GlowCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  const GlowCard({super.key, required this.child, this.glowColor = AppColors.accent,
      this.borderRadius = 16, this.padding});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: AppColors.cardGradient,
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: glowColor.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child);
}

class FeatureInputField extends StatefulWidget {
  final String featureName, displayName, unit, icon, description;
  final double minValue, maxValue, currentValue;
  final ValueChanged<double> onChanged;
  final String? errorText;
  const FeatureInputField({
    super.key, required this.featureName, required this.displayName,
    required this.unit, required this.icon, required this.description,
    required this.minValue, required this.maxValue, required this.currentValue,
    required this.onChanged, this.errorText,
  });
  @override State<FeatureInputField> createState() => _FeatureInputFieldState();
}

class _FeatureInputFieldState extends State<FeatureInputField> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override void initState() { super.initState(); _ctrl = TextEditingController(text: widget.currentValue.toStringAsFixed(1)); }
  @override void didUpdateWidget(FeatureInputField old) {
    super.didUpdateWidget(old);
    if (!_editing && old.currentValue != widget.currentValue) _ctrl.text = widget.currentValue.toStringAsFixed(1);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit(String v) {
    final parsed = double.tryParse(v);
    if (parsed != null) widget.onChanged(parsed.clamp(widget.minValue, widget.maxValue));
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (widget.currentValue - widget.minValue) / (widget.maxValue - widget.minValue);
    final bool hasError = widget.errorText != null;
    Color progressColor = hasError ? AppColors.error : (progress < 0.3 ? AppColors.error : (progress < 0.6 ? AppColors.accent3 : AppColors.accent));

    return GlowCard(
      glowColor: hasError ? AppColors.error : progressColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(widget.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.displayName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text(widget.description, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          SizedBox(width: 100, child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            onTap: () => setState(() => _editing = true),
            onSubmitted: _submit,
            onEditingComplete: () => _submit(_ctrl.text),
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: progressColor),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              suffixText: widget.unit,
              suffixStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: progressColor.withOpacity(0.4))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: progressColor.withOpacity(0.3))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: progressColor)),
              filled: true, fillColor: AppColors.bgSecondary,
            ),
          )),
        ]),
        // Error message — mirrors notebook "⚠  Please enter a valid number."
        if (hasError)
          Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(widget.errorText!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.error))),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: progressColor, inactiveTrackColor: AppColors.border,
            thumbColor: progressColor, overlayColor: progressColor.withOpacity(0.15),
            trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: widget.currentValue.clamp(widget.minValue, widget.maxValue),
            min: widget.minValue, max: widget.maxValue,
            onChanged: (v) { widget.onChanged(v); if (!_editing) _ctrl.text = v.toStringAsFixed(1); }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${widget.minValue.toStringAsFixed(widget.minValue == widget.minValue.roundToDouble() ? 0 : 1)} ${widget.unit}',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
            Text('${widget.maxValue.toStringAsFixed(widget.maxValue == widget.maxValue.roundToDouble() ? 0 : 1)} ${widget.unit}',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }
}

class MetricChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final String? subtitle;
  const MetricChip({super.key, required this.label, required this.value, required this.color, this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.25))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      if (subtitle != null)
        Text(subtitle!, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
    ]),
  );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(width: 3, height: 20,
          decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        if (subtitle != null)
          Text(subtitle!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      if (trailing != null) trailing!,
    ]),
  );
}

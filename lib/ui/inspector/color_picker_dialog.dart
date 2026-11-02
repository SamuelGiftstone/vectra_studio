import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_utils.dart';

/// Custom HSV + Hex + Swatch desktop color picker dialog.
class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    this.title = 'Select Color',
  });

  static Future<Color?> show(
    BuildContext context, {
    required Color initialColor,
    String title = 'Select Color',
  }) {
    return showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(
        initialColor: initialColor,
        title: title,
      ),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsv;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor.withAlpha(255));
    _hexController = TextEditingController(
      text: ColorUtils.toHex(_hsv.toColor()),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateHsv(HSVColor next) {
    setState(() {
      _hsv = next;
      _hexController.text = ColorUtils.toHex(next.toColor());
    });
  }

  void _onHexSubmitted(String value) {
    final parsed = ColorUtils.tryParseHex(value);
    if (parsed != null) {
      setState(() {
        _hsv = HSVColor.fromColor(parsed.withAlpha(255));
        _hexController.text = ColorUtils.toHex(_hsv.toColor());
      });
    } else {
      _hexController.text = ColorUtils.toHex(_hsv.toColor());
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _hsv.toColor();

    return Dialog(
      child: Container(
        width: 316,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // 2D Saturation / Value square
            SizedBox(
              height: 170,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    return GestureDetector(
                      onPanDown: (d) => _handleSvGesture(
                        d.localPosition,
                        constraints.biggest,
                      ),
                      onPanUpdate: (d) => _handleSvGesture(
                        d.localPosition,
                        constraints.biggest,
                      ),
                      child: CustomPaint(
                        painter: _SvSquarePainter(hsv: _hsv),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Hue bar
            const Text(
              'HUE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 18,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    return GestureDetector(
                      onPanDown: (d) => _handleHueGesture(
                        d.localPosition.dx,
                        constraints.maxWidth,
                      ),
                      onPanUpdate: (d) => _handleHueGesture(
                        d.localPosition.dx,
                        constraints.maxWidth,
                      ),
                      child: CustomPaint(
                        painter: _HueBarPainter(hue: _hsv.hue),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Hex preview + input
            Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 30,
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    style: AppTheme.monoStyle(fontSize: 12),
                    onSubmitted: _onHexSubmitted,
                    decoration: const InputDecoration(
                      labelText: 'HEX',
                      labelStyle: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Preset Swatches
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AppColors.defaultSwatches.map((swatch) {
                final isMatch =
                    ColorUtils.toHex(swatch) == ColorUtils.toHex(currentColor);
                return InkWell(
                  onTap: () => _updateHsv(HSVColor.fromColor(swatch)),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: swatch,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isMatch ? AppColors.textPrimary : AppColors.border,
                        width: isMatch ? 1.8 : 1.0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    _onHexSubmitted(_hexController.text);
                    Navigator.of(context).pop(_hsv.toColor());
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.mainBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSvGesture(Offset localPos, Size size) {
    final s = (localPos.dx / size.width).clamp(0.0, 1.0);
    final v = (1.0 - (localPos.dy / size.height)).clamp(0.0, 1.0);
    _updateHsv(_hsv.withSaturation(s).withValue(v));
  }

  void _handleHueGesture(double dx, double width) {
    final hue = ((dx / width).clamp(0.0, 1.0)) * 359.9;
    _updateHsv(_hsv.withHue(hue));
  }
}

class _SvSquarePainter extends CustomPainter {
  final HSVColor hsv;

  const _SvSquarePainter({required this.hsv});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pureHue = HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor();

    final satGradient = LinearGradient(
      colors: <Color>[Colors.white, pureHue],
    );
    final valGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Colors.transparent, Colors.black],
    );

    canvas.drawRect(rect, Paint()..shader = satGradient.createShader(rect));
    canvas.drawRect(rect, Paint()..shader = valGradient.createShader(rect));

    final indicator = Offset(
      hsv.saturation * size.width,
      (1.0 - hsv.value) * size.height,
    );
    canvas.drawCircle(
      indicator,
      6.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(
      indicator,
      4.5,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _SvSquarePainter oldDelegate) =>
      oldDelegate.hsv != hsv;
}

class _HueBarPainter extends CustomPainter {
  final double hue;

  const _HueBarPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const hueColors = <Color>[
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];
    final gradient = const LinearGradient(colors: hueColors);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final x = (hue / 360.0).clamp(0.0, 1.0) * size.width;
    canvas.drawCircle(
      Offset(x, size.height * 0.5),
      6.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HueBarPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

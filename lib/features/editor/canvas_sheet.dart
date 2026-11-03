import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'media.dart';

/// Canvas ratio + background. Calls [onChanged] live; pops `true` on Done.
class CanvasSheet extends StatefulWidget {
  const CanvasSheet({
    super.key,
    required this.ratio,
    required this.background,
    required this.onChanged,
  });

  final CanvasRatio ratio;
  final BackgroundMode background;
  final void Function(CanvasRatio ratio, BackgroundMode background) onChanged;

  @override
  State<CanvasSheet> createState() => _CanvasSheetState();
}

class _CanvasSheetState extends State<CanvasSheet> {
  late CanvasRatio _ratio = widget.ratio;
  late BackgroundMode _bg = widget.background;

  void _set({CanvasRatio? ratio, BackgroundMode? bg}) {
    setState(() {
      _ratio = ratio ?? _ratio;
      _bg = bg ?? _bg;
    });
    widget.onChanged(_ratio, _bg);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Canvas', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                GradientButton(
                  key: const Key('canvas-done'),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: Icons.check,
                  label: 'Done',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Ratio', style: TextStyle(color: RizColors.textDim)),
            const SizedBox(height: 8),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CanvasRatio.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final r = CanvasRatio.values[i];
                  final sel = r == _ratio;
                  final a = r.aspect ?? 0.8;
                  final w = a >= 1 ? 40.0 : 40 * a;
                  final h = a >= 1 ? 40 / a : 40.0;
                  return GestureDetector(
                    onTap: () => _set(ratio: r),
                    child: Container(
                      width: 66,
                      decoration: BoxDecoration(
                        color: sel ? RizColors.violet.withValues(alpha: 0.25) : RizColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sel ? Colors.white : RizColors.outline, width: sel ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: w,
                            height: h,
                            decoration: BoxDecoration(
                              border: Border.all(color: sel ? RizColors.cyan : RizColors.textDim, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: r == CanvasRatio.original
                                ? const Icon(Icons.crop_original, size: 16, color: RizColors.textDim)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(r.label, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Background', style: TextStyle(color: RizColors.textDim)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final b in BackgroundMode.values)
                  ChoiceChip(
                    avatar: b.argb == null
                        ? const Icon(Icons.blur_on, size: 18)
                        : CircleAvatar(backgroundColor: Color(b.argb!), radius: 8),
                    label: Text(b.label),
                    selected: b == _bg,
                    selectedColor: RizColors.violet,
                    onSelected: (_) => _set(bg: b),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Fills the space around videos and photos that don\'t match the ratio.',
              style: TextStyle(color: RizColors.textDim, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'layers.dart';

/// Result of the layer sheet: an edited layer, or `delete`.
class LayerEdit {
  const LayerEdit.update(this.layer) : delete = false;
  const LayerEdit.delete()
      : layer = null,
        delete = true;
  final Layer? layer;
  final bool delete;
}

const _positions = <String, FrameRect>{
  'Top right': FrameRect(0.58, 0.05, 0.38, 0.24),
  'Top left': FrameRect(0.04, 0.05, 0.38, 0.24),
  'Bottom right': FrameRect(0.58, 0.71, 0.38, 0.24),
  'Bottom left': FrameRect(0.04, 0.71, 0.38, 0.24),
  'Top half': FrameRect(0, 0, 1, 0.5),
  'Bottom half': FrameRect(0, 0.5, 1, 0.5),
  'Full screen': FrameRect.full,
};

class LayerSheet extends StatefulWidget {
  const LayerSheet({super.key, required this.initial, required this.hasSound});
  final Layer initial;
  final bool hasSound;

  @override
  State<LayerSheet> createState() => _LayerSheetState();
}

class _LayerSheetState extends State<LayerSheet> {
  late Layer _l = widget.initial;

  /// Scales the frame around its centre, keeping it on the canvas.
  void _resize(double scale) {
    final f = _l.frame;
    final base = widget.initial.frame;
    final w = (base.w * scale).clamp(0.15, 1.0);
    final h = (base.h * scale).clamp(0.1, 1.0);
    final cx = f.x + f.w / 2, cy = f.y + f.h / 2;
    setState(() => _l = _l.copyWith(
          frame: FrameRect(
            (cx - w / 2).clamp(0.0, 1 - w),
            (cy - h / 2).clamp(0.0, 1 - h),
            w,
            h,
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.initial.frame.w == 0
        ? 1.0
        : (_l.frame.w / widget.initial.frame.w).clamp(0.4, 2.5);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Layer', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete layer',
                  onPressed: () =>
                      Navigator.of(context).pop(const LayerEdit.delete()),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5C7A)),
                ),
                GradientButton(
                  key: const Key('layer-done'),
                  onPressed: () => Navigator.of(context).pop(LayerEdit.update(_l)),
                  icon: Icons.check,
                  label: 'Done',
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Position', style: TextStyle(color: RizColors.textDim)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _positions.entries)
                  ChoiceChip(
                    label: Text(e.key),
                    selected: _l.frame == e.value,
                    selectedColor: RizColors.violet,
                    onSelected: (_) =>
                        setState(() => _l = _l.copyWith(frame: e.value)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.photo_size_select_large, size: 18, color: RizColors.textDim),
                const SizedBox(width: 8),
                const SizedBox(width: 70, child: Text('Size')),
                Expanded(
                  child: Slider(value: scale, min: 0.4, max: 2.5, onChanged: _resize),
                ),
              ],
            ),
            if (widget.hasSound)
              Row(
                children: [
                  const Icon(Icons.volume_up, size: 18, color: RizColors.textDim),
                  const SizedBox(width: 8),
                  const SizedBox(width: 70, child: Text('Sound')),
                  Expanded(
                    child: Slider(
                      value: _l.volume,
                      onChanged: (v) => setState(() => _l = _l.copyWith(volume: v)),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${(_l.volume * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: RizColors.textDim)),
                  ),
                ],
              ),
            const Text('Tip: drag the layer on the video to move it.',
                style: TextStyle(color: RizColors.textDim, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Picks a layout template. Pops the chosen [LayoutTemplate].
class LayoutPickerSheet extends StatelessWidget {
  const LayoutPickerSheet({super.key, this.note});
  final String? note;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Layouts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(note ?? 'Pick a layout, then choose one video or photo per frame.',
                style: const TextStyle(color: RizColors.textDim)),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: LayoutTemplate.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final t = LayoutTemplate.values[i];
                  return GestureDetector(
                    key: Key('layout-${t.name}'),
                    onTap: () => Navigator.of(context).pop(t),
                    child: Column(
                      children: [
                        LayoutThumb(template: t, height: 112),
                        const SizedBox(height: 6),
                        Text(t.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small drawing of a layout's frames.
class LayoutThumb extends StatelessWidget {
  const LayoutThumb({super.key, required this.template, this.height = 100});
  final LayoutTemplate template;
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = template.square ? height : height * 9 / 16;
    const colors = [RizColors.magenta, RizColors.blue, RizColors.violet];
    return Container(
      width: w,
      height: height,
      decoration: BoxDecoration(
        color: RizColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RizColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          for (var i = 0; i < template.slotCount; i++)
            Positioned(
              left: template.slots[i].x * w + 2,
              top: template.slots[i].y * height + 2,
              width: template.slots[i].w * w - 4,
              height: template.slots[i].h * height - 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    colors[i % 3],
                    colors[i % 3].withValues(alpha: 0.5),
                  ]),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          if (template.captionY != null)
            Positioned(
              left: 0,
              right: 0,
              top: template.captionY! * height - 7,
              height: 14,
              child: const ColoredBox(
                color: Color(0xFFFFE14D),
                child: Center(
                  child: Text('Caption',
                      style: TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

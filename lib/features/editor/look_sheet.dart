import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'clip_look.dart';

/// Rotate / flip / zoom-crop / motion for one clip.
/// Calls [onChanged] live; pops `true` on Done.
class LookSheet extends StatefulWidget {
  const LookSheet({
    super.key,
    required this.initial,
    required this.onChanged,
    this.isPhoto = false,
  });

  final ClipLook initial;
  final ValueChanged<ClipLook> onChanged;
  final bool isPhoto;

  @override
  State<LookSheet> createState() => _LookSheetState();
}

class _LookSheetState extends State<LookSheet> {
  late ClipLook _l = widget.initial;

  void _set(ClipLook l) {
    setState(() => _l = l);
    widget.onChanged(l);
  }

  @override
  Widget build(BuildContext context) {
    final zoomed = _l.zoom > 1.001;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(widget.isPhoto ? 'Edit photo' : 'Edit clip',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () => _set(const ClipLook()),
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 4),
                GradientButton(
                  key: const Key('look-done'),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: Icons.check,
                  label: 'Done',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Square(
                  key: const Key('look-rotate'),
                  icon: Icons.rotate_90_degrees_cw_outlined,
                  label: 'Rotate',
                  onTap: () => _set(_l.copyWith(turns: _l.turns + 1)),
                ),
                _Square(
                  icon: Icons.flip,
                  label: 'Flip ↔',
                  active: _l.flipH,
                  onTap: () => _set(_l.copyWith(flipH: !_l.flipH)),
                ),
                _Square(
                  icon: Icons.flip,
                  quarterTurns: 1,
                  label: 'Flip ↕',
                  active: _l.flipV,
                  onTap: () => _set(_l.copyWith(flipV: !_l.flipV)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Slider(
              icon: Icons.crop,
              label: 'Zoom',
              value: _l.zoom,
              min: 1,
              max: 3,
              display: '${_l.zoom.toStringAsFixed(1)}x',
              onChanged: (v) => _set(_l.copyWith(zoom: v)),
            ),
            if (zoomed) ...[
              _Slider(
                icon: Icons.swap_horiz,
                label: 'Left ↔ right',
                value: _l.panX,
                min: -1,
                max: 1,
                onChanged: (v) => _set(_l.copyWith(panX: v)),
              ),
              _Slider(
                icon: Icons.swap_vert,
                label: 'Up ↕ down',
                value: _l.panY,
                min: -1,
                max: 1,
                onChanged: (v) => _set(_l.copyWith(panY: v)),
              ),
            ],
            if (!widget.isPhoto)
              SwitchListTile(
                key: const Key('look-stabilize'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Stabilize'),
                subtitle: const Text('Smooths shaky footage when you export',
                    style: TextStyle(color: RizColors.textDim, fontSize: 12)),
                value: _l.stabilize,
                activeThumbColor: RizColors.magenta,
                onChanged: (v) => _set(_l.copyWith(stabilize: v)),
              ),
            const SizedBox(height: 6),
            Text(
              widget.isPhoto ? 'Motion (Ken Burns)' : 'Motion',
              style: const TextStyle(color: RizColors.textDim),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in Motion.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: m == _l.motion,
                    selectedColor: RizColors.violet,
                    onSelected: (_) => _set(_l.copyWith(motion: m)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Square extends StatelessWidget {
  const _Square({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.quarterTurns = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: active ? RizColors.violet : RizColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: active ? Colors.white : RizColors.outline),
              ),
              child: RotatedBox(
                quarterTurns: quarterTurns,
                child: Icon(icon, color: Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.display,
  });

  final IconData icon;
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final String? display;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: RizColors.textDim),
        const SizedBox(width: 8),
        SizedBox(width: 88, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        if (display != null)
          SizedBox(
            width: 38,
            child: Text(display!,
                textAlign: TextAlign.end,
                style: const TextStyle(color: RizColors.textDim)),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'color_grade.dart';

/// Filter presets + adjustments. Calls [onChanged] live; pops `true` on Done.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initial, required this.onChanged});
  final ColorGrade initial;
  final ValueChanged<ColorGrade> onChanged;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ColorGrade _g = widget.initial;

  void _set(ColorGrade g) {
    setState(() => _g = g);
    widget.onChanged(g);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () => _set(const ColorGrade()),
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 4),
                GradientButton(
                  key: const Key('filter-done'),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: Icons.check,
                  label: 'Done',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: FilterPreset.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final f = FilterPreset.values[i];
                  final selected = f == _g.preset;
                  return GestureDetector(
                    onTap: () => _set(_g.copyWith(preset: f)),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? Colors.white : RizColors.outline,
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.matrix(
                                  ColorGrade(preset: f).flutterMatrix),
                              child: const _Swatch(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected ? RizColors.text : RizColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _Adjust(
              icon: Icons.wb_sunny_outlined,
              label: 'Brightness',
              value: _g.brightness,
              min: -0.3,
              max: 0.3,
              onChanged: (v) => _set(_g.copyWith(brightness: v)),
            ),
            _Adjust(
              icon: Icons.contrast,
              label: 'Contrast',
              value: _g.contrast,
              min: 0.5,
              max: 1.5,
              onChanged: (v) => _set(_g.copyWith(contrast: v)),
            ),
            _Adjust(
              icon: Icons.palette_outlined,
              label: 'Saturation',
              value: _g.saturation,
              min: 0,
              max: 2,
              onChanged: (v) => _set(_g.copyWith(saturation: v)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A colourful sample so each preset's effect is visible at a glance.
class _Swatch extends StatelessWidget {
  const _Swatch();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFB36B),
            Color(0xFFFF6B8B),
            Color(0xFF6E9BFF),
            Color(0xFF5FD3C6),
            Color(0xFFF7E27A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Align(
        alignment: Alignment(0.4, 0.5),
        child: Icon(Icons.landscape, color: Colors.white, size: 30),
      ),
    );
  }
}

class _Adjust extends StatelessWidget {
  const _Adjust({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: RizColors.textDim),
        const SizedBox(width: 8),
        SizedBox(width: 78, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

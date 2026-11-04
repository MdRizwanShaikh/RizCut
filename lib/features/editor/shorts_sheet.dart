import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'shorts.dart';

/// Options for "Make a Short". Pops [ShortOptions].
class ShortsSheet extends StatefulWidget {
  const ShortsSheet({super.key});

  @override
  State<ShortsSheet> createState() => _ShortsSheetState();
}

class _ShortsSheetState extends State<ShortsSheet> {
  Duration _length = const Duration(seconds: 30);
  ShortStyle _style = ShortStyle.highlights;
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Make a Short', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('9:16, ready for Shorts, Reels and Stories.',
              style: TextStyle(color: RizColors.textDim)),
          const SizedBox(height: 16),
          const Text('Length'),
          const SizedBox(height: 8),
          SegmentedButton<Duration>(
            segments: [
              for (final l in kShortLengths)
                ButtonSegment(value: l, label: Text('${l.inSeconds}s')),
            ],
            selected: {_length},
            onSelectionChanged: (v) => setState(() => _length = v.first),
          ),
          const SizedBox(height: 14),
          const Text('Pick'),
          const SizedBox(height: 8),
          SegmentedButton<ShortStyle>(
            segments: [
              for (final st in ShortStyle.values)
                ButtonSegment(value: st, label: Text(st.label)),
            ],
            selected: {_style},
            onSelectionChanged: (v) => setState(() => _style = v.first),
          ),
          const SizedBox(height: 6),
          Text(_style.hint, style: const TextStyle(color: RizColors.textDim)),
          const SizedBox(height: 6),
          TextField(
            key: const Key('short-title'),
            controller: _title,
            decoration: InputDecoration(
              labelText: 'Title on top (optional)',
              filled: true,
              fillColor: RizColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GradientButton(
              key: const Key('short-make'),
              onPressed: () => Navigator.of(context).pop(ShortOptions(
                length: _length,
                style: _style,
                title: _title.text,
              )),
              icon: Icons.auto_awesome,
              label: 'Make Short',
            ),
          ),
        ],
      ),
    );
  }
}

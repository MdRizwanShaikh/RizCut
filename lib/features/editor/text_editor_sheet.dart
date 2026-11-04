import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'keyframes.dart';
import 'project.dart';

const kTextColors = <Color>[
  Color(0xFFFFFFFF),
  RizColors.magenta,
  RizColors.pink,
  RizColors.violet,
  RizColors.cyan,
  RizColors.blue,
  Color(0xFFFFD54F),
  Color(0xFF111111),
];

/// Bottom sheet to create or edit a [TextOverlay]. Pops the result.
class TextEditorSheet extends StatefulWidget {
  const TextEditorSheet({super.key, required this.initial});
  final TextOverlay initial;

  @override
  State<TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<TextEditorSheet> {
  late final _ctrl = TextEditingController(text: widget.initial.text);
  late TextOverlay _t = widget.initial;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _done() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(_t.copyWith(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Text', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            key: const Key('text-input'),
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _done(),
            decoration: InputDecoration(
              hintText: 'Type something…',
              filled: true,
              fillColor: RizColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in kTextColors)
                  GestureDetector(
                    onTap: () => setState(() => _t = _t.copyWith(color: c)),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _t.color == c
                              ? RizColors.cyan
                              : RizColors.outline,
                          width: _t.color == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.format_size, color: RizColors.textDim),
              Expanded(
                child: Slider(
                  min: 0.04,
                  max: 0.16,
                  value: _t.sizeFraction,
                  onChanged: (v) =>
                      setState(() => _t = _t.copyWith(sizeFraction: v)),
                ),
              ),
            ],
          ),
          const Text('Animation', style: TextStyle(color: RizColors.textDim)),
          const SizedBox(height: 8),
          _AnimRow(
            label: 'In',
            value: _t.animIn,
            onChanged: (a) => setState(() => _t = _t.copyWith(animIn: a)),
          ),
          const SizedBox(height: 6),
          _AnimRow(
            label: 'Out',
            value: _t.animOut,
            onChanged: (a) => setState(() => _t = _t.copyWith(animOut: a)),
          ),
          Row(
            children: [
              const Icon(Icons.opacity, color: RizColors.textDim),
              Expanded(
                child: Slider(
                  value: _t.opacity,
                  min: 0.1,
                  onChanged: (v) => setState(() => _t = _t.copyWith(opacity: v)),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('${(_t.opacity * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: RizColors.textDim)),
              ),
            ],
          ),
          const Text('Style', style: TextStyle(color: RizColors.textDim)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final st in _TextLook.values)
                ChoiceChip(
                  key: Key('text-style-${st.name}'),
                  avatar: st.band == null
                      ? null
                      : CircleAvatar(backgroundColor: Color(st.band!), radius: 7),
                  label: Text(st.label),
                  selected: _TextLook.of(_t) == st,
                  selectedColor: RizColors.violet,
                  onSelected: (_) => setState(() => _t = st.applyTo(_t)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GradientButton(
              key: const Key('text-done'),
              onPressed: _done,
              icon: Icons.check,
              label: 'Done',
            ),
          ),
        ],
      ),
    );
  }
}

/// Text looks offered in the sheet. Bands are full-width caption bars.
enum _TextLook {
  plain('Plain', null),
  box('Box', null),
  yellowBand('Yellow band', 0xFFFFE14D),
  whiteBand('White band', 0xFFFFFFFF),
  blackBand('Black band', 0xFF000000),
  pinkBand('Pink band', 0xFFFB40FA);

  const _TextLook(this.label, this.band);
  final String label;
  final int? band;

  static _TextLook of(TextOverlay t) {
    if (t.band != null) {
      return _TextLook.values.firstWhere((l) => l.band == t.band,
          orElse: () => _TextLook.yellowBand);
    }
    return t.background ? box : plain;
  }

  TextOverlay applyTo(TextOverlay t) {
    if (band == null) {
      return t.copyWith(background: this == box, clearBand: true);
    }
    // Readable text on the band: dark on light bands, white on dark ones.
    final light = band == 0xFFFFE14D || band == 0xFFFFFFFF;
    return t.copyWith(
      band: band,
      background: false,
      color: light ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
      position: Offset(0.5, t.position.dy),
    );
  }
}

class _AnimRow extends StatelessWidget {
  const _AnimRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final TextAnim value;
  final ValueChanged<TextAnim> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(width: 34, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final a in TextAnim.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(a.label),
                      selected: a == value,
                      selectedColor: RizColors.violet,
                      onSelected: (_) => onChanged(a),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

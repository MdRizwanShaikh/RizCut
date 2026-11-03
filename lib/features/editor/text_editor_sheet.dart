import 'package:flutter/material.dart';

import '../../core/theme.dart';
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Background box'),
            value: _t.background,
            activeThumbColor: RizColors.magenta,
            onChanged: (v) => setState(() => _t = _t.copyWith(background: v)),
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

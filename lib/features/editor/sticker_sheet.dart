import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'stickers.dart';
import 'text_editor_sheet.dart' show kTextColors;

class StickerChoice {
  const StickerChoice(this.index, this.color);
  final int index;
  final Color color;
}

/// Pick a sticker and its colour. Pops a [StickerChoice].
class StickerSheet extends StatefulWidget {
  const StickerSheet({super.key, this.initialColor});
  final Color? initialColor;

  @override
  State<StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<StickerSheet> {
  late Color _color = widget.initialColor ?? const Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Stickers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in {const Color(0xFFFFD54F), ...kTextColors})
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c ? RizColors.cyan : RizColors.outline,
                            width: _color == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (var i = 0; i < kStickers.length; i++)
                    InkWell(
                      key: Key('sticker-$i'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () =>
                          Navigator.of(context).pop(StickerChoice(i, _color)),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: RizColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(kStickers[i], color: _color, size: 30),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

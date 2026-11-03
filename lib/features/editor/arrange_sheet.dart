import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'project.dart';

/// Drag clips into a new order. Pops the new order as original indices.
class ArrangeSheet extends StatefulWidget {
  const ArrangeSheet({super.key, required this.project});
  final Project project;

  @override
  State<ArrangeSheet> createState() => _ArrangeSheetState();
}

class _ArrangeSheetState extends State<ArrangeSheet> {
  late final List<int> _order = [
    for (var i = 0; i < widget.project.clips.length; i++) i,
  ];

  @override
  Widget build(BuildContext context) {
    final clips = widget.project.clips;
    final maxH = MediaQuery.sizeOf(context).height * 0.6;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Arrange clips',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                GradientButton(
                  key: const Key('arrange-done'),
                  onPressed: () => Navigator.of(context).pop(_order),
                  icon: Icons.check,
                  label: 'Done',
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Drag the handle to change the order.',
                style: TextStyle(color: RizColors.textDim)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: _order.length,
                onReorderItem: (from, to) =>
                    setState(() => _order.insert(to, _order.removeAt(from))),
                itemBuilder: (_, pos) {
                  final i = _order[pos];
                  final c = clips[i];
                  final color =
                      RizColors.clipColors[i % RizColors.clipColors.length];
                  return Padding(
                    key: ValueKey(i),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: RizColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.5)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                        title: Text(
                            'Clip ${i + 1} · ${(c.timelineLength.inMilliseconds / 1000).toStringAsFixed(1)}s'),
                        subtitle: Text(
                          c.speed == 1 ? 'Normal speed' : '${c.speed}x speed',
                          style: const TextStyle(color: RizColors.textDim),
                        ),
                        trailing: ReorderableDragStartListener(
                          index: pos,
                          child: const Icon(Icons.drag_indicator,
                              color: RizColors.textDim),
                        ),
                      ),
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

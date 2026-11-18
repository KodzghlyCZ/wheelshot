import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Tappable field that opens a Cupertino-style rolling number picker.
class NumberRollerField extends StatelessWidget {
  const NumberRollerField({
    super.key,
    required this.label,
    required this.displayValue,
    required this.onTap,
    this.onDuplicate,
    this.hint,
  });

  final String label;
  final String displayValue;
  final VoidCallback onTap;
  final VoidCallback? onDuplicate;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final empty = displayValue.trim().isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                filled: true,
                fillColor: const Color(0xFF1C1F28),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: const Icon(Icons.unfold_more, color: Colors.white38),
              ),
              child: Text(
                empty ? (hint ?? '—') : displayValue,
                style: TextStyle(
                  color: empty ? Colors.white38 : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        if (onDuplicate != null) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Copy from previous type',
            onPressed: onDuplicate,
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ],
    );
  }
}

Future<T?> showRollingPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> values,
  required T initial,
  required String Function(T) labelOf,
}) async {
  if (values.isEmpty) return null;
  var index = values.indexOf(initial);
  if (index < 0) index = 0;
  final controller = FixedExtentScrollController(initialItem: index);

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: const Color(0xFF1C1F28),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final i = controller.selectedItem
                            .clamp(0, values.length - 1);
                        Navigator.pop(ctx, values[i]);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: controller,
                  itemExtent: 40,
                  magnification: 1.12,
                  useMagnifier: true,
                  onSelectedItemChanged: (_) {},
                  children: [
                    for (final v in values)
                      Center(
                        child: Text(
                          labelOf(v),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _showMultiRollingPicker({
  required BuildContext context,
  required String title,
  required List<_RollerColumn> columns,
  required void Function(List<int> indices) onDone,
}) async {
  final controllers = [
    for (final c in columns)
      FixedExtentScrollController(
        initialItem: c.initialIndex.clamp(0, c.labels.length - 1),
      ),
  ];

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1C1F28),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: 340,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        onDone([
                          for (var i = 0; i < controllers.length; i++)
                            controllers[i]
                                .selectedItem
                                .clamp(0, columns[i].labels.length - 1),
                        ]);
                        Navigator.pop(ctx);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final c in columns)
                      Expanded(
                        child: Text(
                          c.header,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < columns.length; i++)
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: controllers[i],
                          itemExtent: 40,
                          magnification: 1.1,
                          useMagnifier: true,
                          onSelectedItemChanged: (_) {},
                          children: [
                            for (final label in columns[i].labels)
                              Center(
                                child: Text(
                                  label,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  for (final c in controllers) {
    c.dispose();
  }
}

class _RollerColumn {
  const _RollerColumn({
    required this.header,
    required this.labels,
    required this.initialIndex,
  });

  final String header;
  final List<String> labels;
  final int initialIndex;
}

/// Public helper to build multi-column rollers without exporting [_RollerColumn].
class RollerColumn {
  const RollerColumn({
    required this.header,
    required this.labels,
    required this.initialIndex,
  });

  final String header;
  final List<String> labels;
  final int initialIndex;
}

Future<void> showLabeledMultiRollingPicker({
  required BuildContext context,
  required String title,
  required List<RollerColumn> columns,
  required void Function(List<int> indices) onDone,
}) {
  return _showMultiRollingPicker(
    context: context,
    title: title,
    columns: [
      for (final c in columns)
        _RollerColumn(
          header: c.header,
          labels: c.labels,
          initialIndex: c.initialIndex,
        ),
    ],
    onDone: onDone,
  );
}

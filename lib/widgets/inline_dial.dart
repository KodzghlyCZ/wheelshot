import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Compact [CupertinoPicker] that wins vertical gestures over a parent [ListView].
class InlineDial<T> extends StatefulWidget {
  const InlineDial({
    super.key,
    required this.values,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.width = 64,
    this.height = 120,
    this.reportLive = false,
  });

  final List<T> values;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final double width;
  final double height;

  /// Report the selected row while the wheel is still moving, so Next can
  /// keep the value the user just landed on.
  final bool reportLive;

  @override
  State<InlineDial<T>> createState() => _InlineDialState<T>();
}

class _InlineDialState<T> extends State<InlineDial<T>> {
  late FixedExtentScrollController _controller;

  int _indexOf(T value) {
    final i = widget.values.indexOf(value);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _controller =
        FixedExtentScrollController(initialItem: _indexOf(widget.value));
  }

  @override
  void didUpdateWidget(covariant InlineDial<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _indexOf(widget.value);
    if (_controller.hasClients && _controller.selectedItem == next) return;
    // jumpToItem notifies the picker immediately. From didUpdateWidget that
    // runs while the parent is still building (rim Ø sync moves the tire
    // dial) and onSelectedItemChanged would setState during that build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final latest = _indexOf(widget.value);
      if (_controller.selectedItem != latest) {
        _controller.jumpToItem(latest);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSelected(int index) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _emit(_controller.selectedItem);
      });
      return;
    }
    _emit(index);
  }

  void _emit(int index) {
    if (index < 0 || index >= widget.values.length) return;
    final next = widget.values[index];
    // A programmatic jump lands on the value the parent already stored.
    // Reporting it again would mark a synced diameter as a user edit.
    if (next == widget.value) return;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    const itemExtent = 36.0;
    if (widget.values.isEmpty) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    // Swallow scroll notifications so parent ListView does not steal the drag
    // (was why PCD/other dials looked "dead" — dim overlay, no roll).
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => true,
        child: CupertinoPicker(
          scrollController: _controller,
          itemExtent: itemExtent,
          diameterRatio: 1.5,
          squeeze: 1.05,
          magnification: 1.08,
          useMagnifier: true,
          looping: false,
          selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
            background:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
            capStartEdge: false,
            capEndEdge: false,
          ),
          // Scroll updates also fire while the wheel lays out. SpecsScreen
          // rebuilds every dial on each tick (and on Save). A callback then
          // setStates the screen during that layout and the whole page goes red.
          // Commit only when the wheel stops, and never from inside a frame.
          changeReportingBehavior: widget.reportLive
              ? ChangeReportingBehavior.onScrollUpdate
              : ChangeReportingBehavior.onScrollEnd,
          onSelectedItemChanged: _onSelected,
          children: [
            for (final v in widget.values)
              Center(
                child: Text(
                  widget.labelOf(v),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Labeled dial strip with optional duplicate + pencil → free-text → back (defaults).
class DialStrip extends StatefulWidget {
  const DialStrip({
    super.key,
    required this.label,
    required this.children,
    required this.dialText,
    required this.onResetToDefaults,
    required this.onManualChanged,
    this.onDuplicate,
    this.manualHint,
  });

  final String label;
  final List<Widget> children;

  /// Current dial composition — seeds the text field when opening pencil mode.
  final String Function() dialText;

  /// Back from pencil: restore dial defaults (parent resets its values).
  final VoidCallback onResetToDefaults;

  /// `null` = dial mode; non-null = free-text override for save.
  final ValueChanged<String?> onManualChanged;

  final VoidCallback? onDuplicate;
  final String? manualHint;

  @override
  State<DialStrip> createState() => _DialStripState();
}

class _DialStripState extends State<DialStrip> {
  bool _manual = false;
  late final TextEditingController _manualCtrl;

  @override
  void initState() {
    super.initState();
    _manualCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  void _enterManual() {
    _manualCtrl.text = widget.dialText();
    setState(() => _manual = true);
    widget.onManualChanged(_manualCtrl.text);
  }

  void _exitManual() {
    widget.onResetToDefaults();
    widget.onManualChanged(null);
    setState(() => _manual = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ),
            IconButton(
              tooltip: _manual ? 'Back to dials (defaults)' : 'Type manually',
              onPressed: _manual ? _exitManual : _enterManual,
              icon: Icon(
                _manual ? Icons.arrow_back : Icons.edit_outlined,
                color: Colors.white70,
              ),
            ),
            if (widget.onDuplicate != null)
              IconButton.filledTonal(
                tooltip: 'Copy from previous type',
                onPressed: widget.onDuplicate,
                icon: const Icon(Icons.copy_all_outlined),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (_manual)
          TextField(
            controller: _manualCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: widget.manualHint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1C1F28),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: widget.onManualChanged,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.children,
              ),
            ),
          ),
      ],
    );
  }
}

/// Space and a hairline so neighboring dials stay separate controls.
class DialGap extends StatelessWidget {
  const DialGap({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white24,
    );
  }
}

class DialSep extends StatelessWidget {
  const DialSep(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
        ),
      ),
    );
  }
}

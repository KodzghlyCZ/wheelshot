import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text field with optional autocomplete suggestions and a duplicate button.
class SuggestField extends StatefulWidget {
  const SuggestField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.options = const [],
    this.onDuplicate,
    this.onChanged,
    this.keyboard,
    this.formatters,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final List<String> options;
  final VoidCallback? onDuplicate;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final bool enabled;

  @override
  State<SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<SuggestField> {
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    // Rebuild so options hide when focus is lost.
    if (mounted) setState(() {});
  }

  void _dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_focus.hasFocus) _focus.unfocus();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  InputDecoration get _dec => InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        filled: true,
        fillColor: const Color(0xFF1C1F28),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final field = widget.options.isEmpty
        ? TextField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            keyboardType: widget.keyboard ?? TextInputType.text,
            inputFormatters: widget.formatters,
            textInputAction: TextInputAction.next,
            onChanged: widget.onChanged,
            onTapOutside: (_) => _dismiss(),
            decoration: _dec,
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              return RawAutocomplete<String>(
                textEditingController: widget.controller,
                focusNode: _focus,
                optionsBuilder: (text) {
                  if (!_focus.hasFocus) return const Iterable<String>.empty();
                  final q = text.text.trim().toLowerCase();
                  if (q.isEmpty) return widget.options;
                  return widget.options
                      .where((o) => o.toLowerCase().contains(q));
                },
                onSelected: (v) {
                  widget.controller.value = TextEditingValue(
                    text: v,
                    selection: TextSelection.collapsed(offset: v.length),
                  );
                  widget.onChanged?.call(v);
                  _dismiss();
                },
                fieldViewBuilder:
                    (context, textController, focusNode, onSubmit) {
                  return TextField(
                    controller: textController,
                    focusNode: focusNode,
                    enabled: widget.enabled,
                    keyboardType: widget.keyboard ?? TextInputType.text,
                    inputFormatters: widget.formatters,
                    textInputAction: TextInputAction.next,
                    onChanged: widget.onChanged,
                    onSubmitted: (_) {
                      onSubmit();
                      _dismiss();
                    },
                    onTapOutside: (_) => _dismiss(),
                    decoration: _dec,
                  );
                },
                optionsViewBuilder: (context, onSelected, opts) {
                  final list = opts.toList();
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 6,
                      color: const Color(0xFF252833),
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 220,
                          maxWidth: constraints.maxWidth,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final opt = list[i];
                            return ListTile(
                              dense: true,
                              title: Text(opt),
                              onTap: () => onSelected(opt),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        if (widget.onDuplicate != null) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton.filledTonal(
              tooltip: 'Copy from previous type',
              onPressed: widget.enabled ? widget.onDuplicate : null,
              icon: const Icon(Icons.copy_all_outlined),
            ),
          ),
        ],
      ],
    );
  }
}

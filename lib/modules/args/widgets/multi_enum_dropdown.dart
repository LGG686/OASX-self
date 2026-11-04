part of args;

class MultiEnumDropdown extends StatefulWidget {
  const MultiEnumDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.exclusiveGroups = const [],
    this.labelBuilder,
  });

  final List<String> value;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;
  final String? errorText;
  final bool enabled;
  final List<List<String>> exclusiveGroups;
  final String Function(String)? labelBuilder;

  @override
  State<MultiEnumDropdown> createState() => _MultiEnumDropdownState();
}

class _MultiEnumDropdownState extends State<MultiEnumDropdown> {
  final ScrollController _scroll = ScrollController();
  List<String> get value => widget.value;
  List<String> get options => widget.options;
  ValueChanged<List<String>> get onChanged => widget.onChanged;
  String? get errorText => widget.errorText;
  bool get enabled => widget.enabled;
  List<List<String>> get exclusiveGroups => widget.exclusiveGroups;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const double _menuMaxHeight = 288;

  @override
  Widget build(BuildContext context) {
    final selected = value.toSet();
    final label = options
        .where(selected.contains)
        .map((option) => widget.labelBuilder?.call(option) ?? option.tr)
        .join(', ');

    return MenuAnchor(
      menuChildren: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _menuMaxHeight),
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              primary: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map((option) {
                      final isSelected = selected.contains(option);
                      return MenuItemButton(
                        closeOnActivate: false,
                        trailingIcon: IgnorePointer(
                          child: Checkbox(value: isSelected, onChanged: (_) {}),
                        ),
                        onPressed: enabled
                            ? () {
                                final next = selected.toSet();
                                if (isSelected) {
                                  next.remove(option);
                                } else {
                                  for (final group in exclusiveGroups) {
                                    if (group.contains(option)) {
                                      next.removeAll(group);
                                    }
                                  }
                                  next.add(option);
                                }
                                onChanged(
                                  options
                                      .where(next.contains)
                                      .toList(growable: false),
                                );
                              }
                            : null,
                        child: Text(
                          widget.labelBuilder?.call(option) ?? option.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return InkWell(
          onTap: enabled
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            isEmpty: label.isEmpty,
            decoration: InputDecoration(
              errorText: errorText,
              enabled: enabled,
              suffixIcon: Icon(
                controller.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              ),
            ),
            child: Text(
              label.isEmpty ? ' ' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        );
      },
    );
  }
}

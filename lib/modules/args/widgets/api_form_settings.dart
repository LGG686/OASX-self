part of args;

class ApiFormSettings extends StatefulWidget {
  const ApiFormSettings({
    super.key,
    required this.script,
    required this.task,
    required this.group,
    required this.form,
    required this.onChanged,
  });
  final String script;
  final String task;
  final GroupsModel group;
  final List<dynamic> form;
  final SetArgumentCallback onChanged;

  @override
  State<ApiFormSettings> createState() => _ApiFormSettingsState();
}

class _ApiFormSettingsState extends State<ApiFormSettings> {
  List<ArgumentModel> get members => widget.group.members.cast<ArgumentModel>();
  ArgumentModel? field(String name) =>
      members.firstWhereOrNull((m) => m.title == name);
  void save(String name, dynamic value) {
    final model = field(name);
    if (model == null) return;
    final controller = Get.find<ArgsController>();
    setState(() => model.value = value);
    if (controller.isDraftMode.value) {
      controller.stageArgumentChange(
        widget.group.groupName,
        name,
        value,
        model.type,
      );
    } else {
      widget.onChanged(
        widget.script,
        widget.task,
        widget.group.groupName,
        name,
        model.type,
        value,
      );
    }
  }

  Widget input(String name, {String? label}) {
    final index = members.indexWhere((m) => m.title == name);
    if (index < 0 || members[index].uiHidden) return const SizedBox.shrink();
    return ArgumentView(
      key: ValueKey(name),
      index: index,
      scriptName: widget.script,
      taskName: widget.task,
      getGroupName: widget.group.getGroupName,
      setArgument: widget.onChanged,
      compact: true,
      label: label,
    );
  }

  Widget csvInput(Map<String, dynamic> node) {
    final name = node['field'] as String;
    final index = node['index'] as int;
    final length = node['length'] as int? ?? index + 1;
    final separator = node['separator'] as String? ?? ',';
    final label = settingsText(node['label']);
    final values = (field(name)?.value.toString() ?? '0').split(separator);
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(child: Text('$label：')),
          const SizedBox(width: 6),
          SizedBox(
            width: constraints.maxWidth * .5,
            child: TextFormField(
              key: ValueKey('csv-$name-$index-${widget.script}'),
              initialValue: index < values.length ? values[index] : '0',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                isDense: true,
                errorText: Get.find<ArgsController>().fieldError(
                  widget.group.groupName,
                  name,
                ),
              ),
              onChanged: (value) {
                final next = (field(name)?.value.toString() ?? '0').split(
                  separator,
                );
                while (next.length < length) {
                  next.add('0');
                }
                next[index] = value.isEmpty ? '0' : value;
                save(name, next.join(separator));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget pair(Widget left, Widget right) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    ),
  );

  Widget mode(String title, Widget content) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: Text(title)),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: content),
      ],
    ),
  );

  List<Map<String, dynamic>> nodes(dynamic value) => value is List
      ? value.whereType<Map>().map((n) => Map<String, dynamic>.from(n)).toList()
      : [];

  Set<String> usedFields(List<Map<String, dynamic>> items) => {
    for (final node in items) ...[
      if (node['field'] is String) node['field'] as String,
      ...usedFields(nodes(node['children'])),
    ],
  };

  Widget render(Map<String, dynamic> node, Set<String> handled) {
    final name = node['field'] as String?;
    final model = name == null ? null : field(name);
    if (model?.uiHidden == true) return const SizedBox.shrink();
    final children = nodes(node['children']);
    switch (node['type']) {
      case 'field':
        return model == null
            ? const SizedBox.shrink()
            : input(
                name!,
                label: node['label'] == null
                    ? null
                    : settingsText(node['label']),
              );
      case 'csv':
        return model == null ? const SizedBox.shrink() : csvInput(node);
      case 'selection':
        if (model == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SettingsSelectionRow(
            title: node['label'] == null
                ? model.label
                : settingsText(node['label']),
            options: model.enumEnum ?? const [],
            value: ArgumentModel.normalizeMultiEnumValue(model.value),
            exclusiveGroups: model.exclusiveGroups,
            labelBuilder: model.optionLabel,
            onChanged: (value) => save(name!, value),
          ),
        );
      case 'mode':
        return mode(
          settingsText(node['label']),
          Column(children: children.map((n) => render(n, handled)).toList()),
        );
      case 'row':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: render(children[i], handled)),
              ],
            ],
          ),
        );
      case 'remaining':
        final remaining = members
            .where((m) => !m.uiHidden && !handled.contains(m.title))
            .toList();
        final columns = (node['columns'] as int? ?? 1).clamp(1, 8);
        return Column(
          children: [
            const Divider(),
            for (var i = 0; i < remaining.length; i += columns)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var offset = 0; offset < columns; offset++) ...[
                      if (offset > 0) const SizedBox(width: 14),
                      Expanded(
                        child: i + offset < remaining.length
                            ? input(remaining[i + offset].title)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = nodes(widget.form);
    final handled = usedFields(form);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: form.map((n) => render(n, handled)).toList()),
    );
  }
}

class SettingsSelectionRow extends StatelessWidget {
  const SettingsSelectionRow({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.exclusiveGroups = const [],
    this.labelBuilder,
  });
  final String title;
  final List<String> options;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final List<List<String>> exclusiveGroups;
  final String Function(String)? labelBuilder;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title)),
      Expanded(
        flex: 2,
        child: MultiEnumDropdown(
          value: value,
          options: options,
          exclusiveGroups: exclusiveGroups,
          labelBuilder: labelBuilder,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

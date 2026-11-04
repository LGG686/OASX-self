part of args;

/// Sections and selectable sources are declared by the settings API.
class ApiSettingsGroups extends StatefulWidget {
  const ApiSettingsGroups({
    super.key,
    required this.args,
    required this.script,
    required this.task,
    required this.groupNames,
    required this.layout,
  });
  final Args args;
  final String script;
  final String task;
  final List<String> groupNames;
  final Map<String, dynamic> layout;
  @override
  State<ApiSettingsGroups> createState() => _ApiSettingsGroupsState();
}

class _ApiSettingsGroupsState extends State<ApiSettingsGroups> {
  final Map<String, String> selections = {};

  @override
  void didUpdateWidget(covariant ApiSettingsGroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.script != oldWidget.script || widget.task != oldWidget.task) {
      selections.clear();
    }
  }

  List<Map<String, dynamic>> maps(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];

  List<Widget> sourceChildren(List<Map<String, dynamic>> sources) {
    final controller = Get.find<ArgsController>();
    final result = <Widget>[];
    for (final source in sources) {
      final name = source['name'] as String?;
      final group = controller.groupsData.value[name];
      if (name == null || group == null) continue;
      if (source['fields'] is! List) {
        result.addAll(
          widget.args._children(
            groupName: name,
            selectedScript: widget.script,
            selectedTask: widget.task,
          ),
        );
        continue;
      }
      final fields = List<String>.from(source['fields']);
      final labels = source['labels'] is Map ? source['labels'] as Map : {};
      result.add(const Divider());
      for (final field in fields) {
        final index = group.members.indexWhere(
          (e) => (e as ArgumentModel).title == field,
        );
        if (index < 0) continue;
        if ((group.members[index] as ArgumentModel).uiHidden) continue;
        result.add(
          ArgumentView(
            key: ValueKey('${widget.script}-$name-$field'),
            index: index,
            scriptName: widget.script,
            taskName: widget.task,
            getGroupName: group.getGroupName,
            setArgument:
                widget.args.setArgumentOverride ?? controller.setArgument,
            label: labels[field] == null ? null : settingsText(labels[field]),
          ),
        );
      }
    }
    return result;
  }

  ExpansionTileItem section(
    String id,
    dynamic title,
    List<Map<String, dynamic>> sources, {
    List<Map<String, dynamic>> variants = const [],
    String? selected,
  }) {
    final group = sources.isEmpty ? id : sources.first['name'] as String;
    return ExpansionTileItem(
      key: ValueKey('api-${widget.script}-$id'),
      initiallyExpanded: true,
      isHasTopBorder: false,
      isHasBottomBorder: false,
      borderRadius: BorderRadius.circular(10),
      backgroundColor: widget.args._groupBackgroundColor(
        context,
        widget.script,
        widget.task,
        group,
      ),
      title: Row(
        children: [
          if (widget.args.groupDraggable)
            widget.args._buildGroupDragHandle(
              context,
              widget.script,
              widget.task,
              group,
            ),
          Text(settingsText(title)),
          if (selected != null) ...[
            const Spacer(),
            PopupMenuButton<String>(
              key: ValueKey('api-$id-category'),
              initialValue: selected,
              tooltip: '选择具体任务',
              onSelected: (value) => setState(() => selections[id] = value),
              itemBuilder: (_) => variants
                  .map(
                    (variant) => PopupMenuItem<String>(
                      value: variant['id'] as String,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          settingsText(variant['label']),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      settingsText(
                        variants.firstWhere(
                          (v) => v['id'] == selected,
                        )['label'],
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      children: sourceChildren(sources),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = <ExpansionTileItem>[];
    final consumed = <String>{};
    for (final spec in maps(widget.layout['sections'])) {
      if (spec['id'] is! String || spec['title'] == null) continue;
      final id = spec['id'] as String;
      final variants = maps(spec['variants'])
          .where(
            (v) =>
                v['id'] is String &&
                v['label'] != null &&
                maps(
                  v['groups'],
                ).any((g) => widget.groupNames.contains(g['name'])),
          )
          .toList();
      var sources = maps(spec['groups']);
      String? selected;
      if (variants.isNotEmpty) {
        selected = selections[id];
        if (!variants.any((v) => v['id'] == selected)) {
          selected = variants.first['id'] as String;
        }
        sources = maps(
          variants.firstWhere((v) => v['id'] == selected)['groups'],
        );
        for (final variant in variants) {
          consumed.addAll(
            maps(variant['groups']).map((g) => g['name']).whereType<String>(),
          );
        }
      }
      sources = sources
          .where((g) => widget.groupNames.contains(g['name']))
          .toList();
      if (sources.isEmpty) continue;
      consumed.addAll(sources.map((g) => g['name'] as String));
      sections.add(
        section(
          id,
          spec['title'],
          sources,
          variants: variants,
          selected: selected,
        ),
      );
    }
    // Unmentioned groups remain visible, including future API additions.
    for (final name in widget.groupNames.where(
      (name) => !consumed.contains(name),
    )) {
      sections.add(
        section(name, widget.args._groupTitle(name), [
          {'name': name},
        ]),
      );
    }
    return ExpansionTileGroup(spaceBetweenItem: 10, children: sections);
  }
}

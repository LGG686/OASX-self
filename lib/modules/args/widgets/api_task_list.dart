part of args;

class ApiTaskList extends StatefulWidget {
  const ApiTaskList({
    super.key,
    required this.title,
    required this.script,
    required this.task,
    required this.data,
    this.onChanged,
  });

  final String script;
  final String title;
  final String task;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>>? onChanged;

  @override
  State<ApiTaskList> createState() => _ApiTaskListState();
}

class _ApiTaskListState extends State<ApiTaskList> {
  Map<String, dynamic>? _latest;
  bool _busy = false;
  bool _editing = false;
  String? _error;

  List<Map<String, dynamic>> _items(String key) =>
      ((_latest ?? widget.data)[key] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  @override
  void didUpdateWidget(covariant ApiTaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _latest = null;
  }

  Future<bool> _change(Map<String, dynamic> change) async {
    if (_busy) return false;
    setState(() => _busy = true);
    _error = null;
    try {
      final data = await ApiClient().changeTaskList(
        widget.script,
        widget.task,
        {
          ...change,
          if (widget.onChanged != null) ...{
            'preview': true,
            'entries': _items('entries'),
          },
        },
      );
      if (!mounted || data == null) return false;
      setState(() => _latest = data);
      widget.onChanged?.call(data);
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_error ?? '任务列表保存失败，请刷新后重试')));
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    if (_editing || _busy) return;
    setState(() => _editing = true);
    final editor = item['editor'] as String;
    final controller = ArgsController();
    final settings = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(item['settings'] ?? {})),
    );
    Future<void> loadEntry() async {
      final initial = widget.onChanged == null
          ? null
          : await ApiClient().previewTaskEntry(widget.script, item);
      await controller.loadGroups(
        config: widget.script,
        task: editor,
        stagingMode: true,
        initialGroups: initial,
        saveArgumentOverride: widget.onChanged == null
            ? null
            : (config, task, group, argument, type, value) async {
                final fields = Map<String, dynamic>.from(
                  settings[group] as Map? ?? {},
                );
                fields[argument] = value;
                try {
                  await ApiClient().previewTaskEntry(widget.script, {
                    ...item,
                    'settings': {...settings, group: fields},
                  });
                } catch (_) {
                  return false;
                }
                settings[group] = fields;
                return true;
              },
      );
    }

    final load = loadEntry();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Theme.of(
            dialogContext,
          ).colorScheme.surface.withValues(alpha: .8),
          surfaceTintColor: Colors.transparent,
          title: Text(settingsText(item['title'])),
          content: SizedBox(
            width: 680,
            height: 520,
            child: FutureBuilder<void>(
              future: load,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('任务配置读取失败：${snapshot.error}');
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Args(
                  scriptName: widget.script,
                  taskName: editor,
                  groupDraggable: false,
                  argsController: controller,
                );
              },
            ),
          ),
          actions: [
            Obx(
              () => TextButton(
                onPressed: controller.isSavingDraft.value
                    ? null
                    : () async {
                        if (await _change({
                          'action': 'remove',
                          'id': item['id'],
                        })) {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } else {
                          _showError();
                        }
                      },
                child: const Text('删除'),
              ),
            ),
            Obx(
              () => TextButton(
                onPressed: controller.isSavingDraft.value
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
            ),
            Obx(
              () => FilledButton(
                onPressed:
                    controller.isSavingDraft.value ||
                        controller.dirtyFieldKeys.isEmpty
                    ? null
                    : () async {
                        if (await controller.saveDraftChanges()) {
                          if (widget.onChanged != null) {
                            final updated = {...item, 'settings': settings};
                            final data = {
                              ...(_latest ?? widget.data),
                              'entries': _items('entries')
                                  .map(
                                    (entry) => entry['id'] == item['id']
                                        ? updated
                                        : entry,
                                  )
                                  .toList(),
                            };
                            if (!mounted) return;
                            setState(() => _latest = data);
                            widget.onChanged!(data);
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } else {
                          _showError();
                        }
                      },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _items('entries');
    final choices = _items('choices');
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
            child: Row(
              children: [
                Expanded(child: Text(widget.title)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add),
                  tooltip: '添加任务',
                  enabled: !_busy && !_editing && choices.isNotEmpty,
                  itemBuilder: (context) => [
                    for (final choice in choices)
                      PopupMenuItem(
                        value: choice['type'] as String,
                        child: Text(settingsText(choice['title'])),
                      ),
                  ],
                  onSelected: (type) async {
                    if (!await _change({'action': 'add', 'type': type})) {
                      _showError();
                    }
                  },
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text('点击右上角添加任务，按列表顺序执行。每个条目的配置独立保存。'),
            ),
          if (entries.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Container(
                  key: ValueKey(entry['id']),
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        enabled: !_busy && !_editing,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.drag_indicator_outlined),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${index + 1}. ${settingsText(entry['title'])}',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: '编辑任务',
                        onPressed: _busy || _editing
                            ? null
                            : () => _edit(entry),
                      ),
                    ],
                  ),
                );
              },
              onReorder: (from, to) async {
                if (_busy || _editing) return;
                if (to > from) to--;
                final ids = entries
                    .map((entry) => entry['id'] as String)
                    .toList();
                ids.insert(to, ids.removeAt(from));
                if (!await _change({'action': 'reorder', 'ids': ids})) {
                  _showError();
                }
              },
            ),
        ],
      ),
    );
  }
}

part of args;

class ActivityGeneralSettings extends StatefulWidget {
  const ActivityGeneralSettings({
    super.key,
    required this.script,
    required this.task,
    required this.group,
    required this.onChanged,
  });
  final String script;
  final String task;
  final GroupsModel group;
  final SetArgumentCallback onChanged;

  @override
  State<ActivityGeneralSettings> createState() =>
      _ActivityGeneralSettingsState();
}

class _ActivityGeneralSettingsState extends State<ActivityGeneralSettings> {
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
    if (index < 0) return const SizedBox.shrink();
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

  Widget passInput(int index, String label) {
    final values = (field('pass_limit')?.value.toString() ?? '0').split(',');
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(child: Text('$label：')),
          const SizedBox(width: 6),
          SizedBox(
            width: constraints.maxWidth * .5,
            child: TextFormField(
              key: ValueKey('pass-$index-${widget.script}'),
              initialValue: index < values.length ? values[index] : '0',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                isDense: true,
                errorText: Get.find<ArgsController>().fieldError(
                  widget.group.groupName,
                  'pass_limit',
                ),
              ),
              onChanged: (value) {
                final next = (field('pass_limit')?.value.toString() ?? '0')
                    .split(',');
                while (next.length < 2) {
                  next.add('0');
                }
                next[index] = value.isEmpty ? '0' : value;
                save('pass_limit', next.join(','));
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

  @override
  Widget build(BuildContext context) {
    const handled = {
      'task_sequence',
      'climb_task_sequence',
      'throw_limit',
      'ap_limit',
      'ap100_limit',
      'pass_limit',
      'boss_limit',
      'fakegod_limit',
    };
    final remaining = members.where((m) => !handled.contains(m.title)).toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ActivitySelectionDropdown(
            title: '活动启用',
            options: const ['探索', '大富翁', '伪神', '爬塔', '首领'],
            value: ArgumentModel.normalizeMultiEnumValue(
              field('task_sequence')?.value,
            ),
            exclusiveGroups: const [
              ['探索', '大富翁', '伪神'],
            ],
            onChanged: (value) => save('task_sequence', value),
          ),
          const SizedBox(height: 16),
          if (field('climb_task_sequence') != null)
            ActivitySelectionDropdown(
              title: '爬塔启用',
              options: const ['困难', '简单', '体力', '百体'],
              value: ArgumentModel.normalizeMultiEnumValue(
                field('climb_task_sequence')?.value,
              ),
              onChanged: (value) => save('climb_task_sequence', value),
            ),
          const SizedBox(height: 16),
          mode('大富翁', input('throw_limit', label: '投掷次数')),
          mode(
            '爬塔',
            Column(
              children: [
                pair(
                  input('ap_limit', label: '体力'),
                  input('ap100_limit', label: '百体'),
                ),
                pair(passInput(0, '简单'), passInput(1, '困难')),
              ],
            ),
          ),
          mode('伪神', input('fakegod_limit', label: '行动次数')),
          mode('首领', input('boss_limit', label: '挑战次数')),
          const Divider(),
          for (var i = 0; i < remaining.length; i += 2)
            pair(
              input(remaining[i].title),
              i + 1 < remaining.length
                  ? input(remaining[i + 1].title)
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class ActivitySelectionDropdown extends StatelessWidget {
  const ActivitySelectionDropdown({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.exclusiveGroups = const [],
  });
  final String title;
  final List<String> options;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final List<List<String>> exclusiveGroups;

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
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

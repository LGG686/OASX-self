import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/args/index.dart';

void main() {
  test('outer save commits list draft and cancel restores original', () async {
    final controller = ArgsController();
    var writes = 0;
    dynamic saved;
    final original = {'entries': <dynamic>[], 'choices': <dynamic>[]};
    await controller.loadGroups(
      config: 'test',
      task: 'CustomTask',
      stagingMode: true,
      initialGroups: {
        'task_list': [
          {
            'name': 'task_list',
            'type': 'task_list',
            'value': original,
            'ui_task_list': original,
          },
        ],
      },
      saveArgumentOverride: (config, task, group, argument, type, value) async {
        writes++;
        saved = value;
        return true;
      },
    );
    final draft = {
      'entries': [
        {'id': 'new', 'type': 'Exploration', 'settings': {}},
      ],
      'choices': <dynamic>[],
    };
    controller.stageArgumentChange(
      'task_list',
      'task_list',
      draft,
      'task_list',
    );
    expect(writes, 0);
    expect(controller.hasDraftChanges, isTrue);
    await controller.discardDraftChanges();
    expect(controller.findArgument('task_list', 'task_list')!.value, original);
    expect(controller.hasDraftChanges, isFalse);
    controller.stageArgumentChange(
      'task_list',
      'task_list',
      draft,
      'task_list',
    );
    expect(await controller.saveDraftChanges(), isTrue);
    expect(writes, 1);
    expect(saved, draft);
    expect(controller.hasDraftChanges, isFalse);
    controller.dispose();
  });
  testWidgets('task list grows with entries and shows backend add choices', (
    tester,
  ) async {
    Future<void> render(List<Map<String, dynamic>> entries) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ApiTaskList(
                title: 'Task list',
                script: 'test',
                task: 'custom',
                data: {
                  'entries': entries,
                  'choices': const [
                    {'type': 'from-api', 'title': 'Option from API'},
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await render([]);
    final emptyHeight = tester.getSize(find.byType(ApiTaskList)).height;
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('添加任务'), findsNothing);

    await render([
      {'id': 'one', 'title': '探索', 'editor': 'one-editor'},
      {'id': 'two', 'title': '探索', 'editor': 'two-editor'},
    ]);
    expect(
      tester.getSize(find.byType(ApiTaskList)).height,
      greaterThan(emptyHeight),
    );
    expect(find.text('1. 探索'), findsOneWidget);
    expect(find.text('2. 探索'), findsOneWidget);
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    expect(find.byIcon(Icons.tune_rounded), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Option from API'), findsOneWidget);
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/args/index.dart';

void main() {
  testWidgets('activity counts and bottom controls fit aligned columns', (
    tester,
  ) async {
    final controller = Get.put(ArgsController());
    final saved = <String, dynamic>{};
    addTearDown(Get.reset);
    final payload =
        jsonDecode(File('test/activity_args.json').readAsStringSync())
            as Map<String, dynamic>;
    final definitions = (payload['general_config'] as List)
        .cast<Map<String, dynamic>>();
    final rows = <Map<String, dynamic>>[
      {
        'name': 'task_sequence',
        'type': 'multi_enum',
        'value': ['爬塔', '首领'],
      },
      {
        'name': 'climb_task_sequence',
        'type': 'multi_enum',
        'value': ['困难', '简单', '体力', '百体'],
      },
      for (final name in [
        'throw_limit',
        'ap_limit',
        'ap100_limit',
        'boss_limit',
        'fakegod_limit',
      ])
        {'name': name, 'type': 'integer', 'value': 100},
      {'name': 'pass_limit', 'type': 'string', 'value': '30,40'},
      for (final name in [
        'active_souls_clean',
        'random_sleep',
        'use_penta_pass',
        'climb_drink_break',
      ])
        {'name': name, 'type': 'boolean', 'value': false},
    ];
    final group = GroupsModel(
      groupName: 'general_config',
      members: rows
          .map(
            (row) => ArgumentModel.fromJson({
              ...definitions.firstWhere((d) => d['name'] == row['name']),
              ...row,
            }),
          )
          .toList(),
    );
    controller.groupsData.value = {'general_config': group};
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 720,
                child: ApiFormSettings(
                  script: 'TEST',
                  task: 'ActivityShikigami',
                  group: group,
                  onChanged: (_, _, _, argument, _, value) =>
                      saved[argument] = value,
                  form: definitions.first['ui_form'] as List,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSelectionRow), findsNWidgets(2));
    final checks = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(checks.length, 4);
    final positions = find
        .byType(Checkbox)
        .evaluate()
        .map((element) => tester.getTopRight(find.byWidget(element.widget)).dx)
        .toList();
    expect(positions[0], closeTo(positions[2], .1));
    expect(positions[1], closeTo(positions[3], .1));
    await tester.enterText(
      find.byKey(const ValueKey('csv-pass_limit-1-TEST')),
      '41',
    );
    await tester.pump();
    expect(saved['pass_limit'], '30,41');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'exclusive choices replace each other while other tasks coexist',
    (tester) async {
      var selected = <String>['climb', 'boss', 'explore'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => SizedBox(
                width: 400,
                child: MultiEnumDropdown(
                  options: const ['explore', 'rich', 'fake', 'climb', 'boss'],
                  value: selected,
                  exclusiveGroups: const [
                    ['explore', 'rich', 'fake'],
                  ],
                  onChanged: (value) => update(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'rich'));
      await tester.pumpAndSettle();
      expect(selected, ['rich', 'climb', 'boss']);
      await tester.tap(find.widgetWithText(MenuItemButton, 'fake'));
      await tester.pumpAndSettle();
      expect(selected, ['fake', 'climb', 'boss']);
      await tester.tap(find.widgetWithText(MenuItemButton, 'fake'));
      await tester.pumpAndSettle();
      expect(selected, ['climb', 'boss']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('climb choices can all coexist', (tester) async {
    var selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => SizedBox(
              width: 400,
              child: MultiEnumDropdown(
                options: const ['hard', 'easy', 'ap', 'ap100'],
                value: selected,
                onChanged: (value) => update(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    for (final option in ['ap100', 'easy', 'hard', 'ap']) {
      await tester.tap(find.widgetWithText(MenuItemButton, option));
      await tester.pumpAndSettle();
    }
    expect(selected, ['hard', 'easy', 'ap', 'ap100']);
    expect(tester.takeException(), isNull);
  });
}

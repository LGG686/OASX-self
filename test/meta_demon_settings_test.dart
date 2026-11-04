import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/args/index.dart';

void main() {
  testWidgets('MetaDemon blocks order and independent category storage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = Get.put(ArgsController());
    addTearDown(Get.reset);
    final payload =
        jsonDecode(File('test/meta_demon_args.json').readAsStringSync())
            as Map<String, dynamic>;
    final groups = <String, GroupsModel>{};
    for (final entry in payload.entries) {
      groups[entry.key] = GroupsModel(
        groupName: entry.key,
        members: (entry.value as List)
            .map((row) => ArgumentModel.fromJson(row as Map<String, dynamic>))
            .toList(),
      );
    }
    controller.groupsData.value = groups;
    controller.groupsName.value = groups.keys.toList();
    controller.isDraftMode.value = true;
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: Args(
            scriptName: 'TEST',
            taskName: 'MetaDemon',
            groupDraggable: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final order = ['任务调度', '通用设置', '执行任务前切换御魂', '战斗配置', '快速预设详情'];
    for (var index = 1; index < order.length; index++) {
      expect(
        tester.getTopLeft(find.text(order[index])).dy,
        greaterThan(tester.getTopLeft(find.text(order[index - 1])).dy),
      );
    }
    final soulMenu = find.byKey(
      const ValueKey('api-switch_soul_config-category'),
    );
    await tester.ensureVisible(soulMenu);
    await tester.tap(soulMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('高星鬼王').last);
    await tester.pumpAndSettle();
    final highSoul = find.byKey(
      const ValueKey('TEST-switch_soul_config-high_star_group_team'),
    );
    expect(highSoul, findsOneWidget);
    await tester.ensureVisible(highSoul);
    await tester.enterText(
      find.descendant(of: highSoul, matching: find.byType(TextFormField)),
      '3,2',
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      controller
          .findArgument('switch_soul_config', 'high_star_group_team')!
          .value,
      '3,2',
    );
    expect(
      controller
          .findArgument('switch_soul_config', 'low_star_group_team')!
          .value,
      '-1,-1',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('api-battle_config-category')),
    );
    await tester.tap(find.byKey(const ValueKey('api-battle_config-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('门票刷取').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'args-TEST-MetaDemon-ticket_farming_battle_conf-preset_group',
        ),
      ),
      findsOneWidget,
    );
    expect(highSoul, findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('api-switch_soul_config-category')),
    );
    await tester.tap(
      find.byKey(const ValueKey('api-switch_soul_config-category')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('低星鬼王').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('TEST-switch_soul_config-low_star_group_team')),
      findsOneWidget,
    );
    expect(
      controller
          .findArgument('switch_soul_config', 'high_star_group_team')!
          .value,
      '3,2',
    );
    expect(tester.takeException(), isNull);
  });
}

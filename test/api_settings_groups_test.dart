import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/args/index.dart';

void main() {
  test(
    'API text overrides stale client translations and carries selection rules',
    () {
      Get.addTranslations({
        'zh_CN': {
          'mode': 'stale client title',
          'old_help': 'stale description',
        },
      });
      Get.locale = const Locale('zh', 'CN');
      addTearDown(Get.reset);
      final model = ArgumentModel.fromJson({
        'name': 'mode',
        'type': 'multi_enum',
        'value': ['A'],
        'description': 'old_help',
        'ui_text': {
          'zh_CN': {
            'title': 'Backend title',
            'description': 'Backend description',
            'options': {'A': 'Backend option'},
          },
        },
        'ui_exclusive_groups': [
          ['A', 'B'],
        ],
      });
      expect(model.label, 'Backend title');
      expect(model.descriptionText, 'Backend description');
      expect(model.optionLabel('A'), 'Backend option');
      expect(model.exclusiveGroups, [
        ['A', 'B'],
      ]);
    },
  );
  testWidgets(
    'API layout supports arbitrary tasks and disabling restores all groups',
    (tester) async {
      final controller = Get.put(ArgsController());
      addTearDown(Get.reset);
      final rows = <String, List<Map<String, dynamic>>>{
        'display': [
          {
            'name': 'enabled',
            'type': 'boolean',
            'value': true,
            'ui_layout': {
              'version': 1,
              'sections': [
                {
                  'id': 'combined',
                  'title': 'API combined section',
                  'variants': [
                    {
                      'id': 'first',
                      'label': 'First option',
                      'groups': [
                        {'name': 'first_group'},
                      ],
                    },
                    {
                      'id': 'second',
                      'label': 'Second option',
                      'groups': [
                        {'name': 'second_group'},
                      ],
                    },
                  ],
                },
              ],
            },
          },
        ],
        'first_group': [
          {'name': 'first_value', 'type': 'string', 'value': 'first'},
        ],
        'second_group': [
          {'name': 'second_value', 'type': 'string', 'value': 'second'},
        ],
        'future_group': [
          {'name': 'future_value', 'type': 'string', 'value': 'future'},
        ],
      };
      controller.groupsData.value = rows.map(
        (name, fields) => MapEntry(
          name,
          GroupsModel(
            groupName: name,
            members: fields.map(ArgumentModel.fromJson).toList(),
          ),
        ),
      );
      controller.groupsName.value = rows.keys.toList();
      controller.isDraftMode.value = true;
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: Args(
              scriptName: 'TEST',
              taskName: 'ArbitraryTask',
              groupDraggable: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('API combined section'), findsOneWidget);
      expect(find.text('first_value'), findsOneWidget);
      expect(find.text('second_value'), findsNothing);
      expect(find.text('future_group'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('api-combined-category')));
      await tester.pumpAndSettle();
      final option = find.text('Second option').last;
      final align = tester.widget<Align>(
        find.ancestor(of: option, matching: find.byType(Align)).first,
      );
      expect(align.alignment, Alignment.centerRight);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(find.text('second_value'), findsOneWidget);
      expect(find.text('first_value'), findsNothing);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('API combined section'), findsNothing);
      expect(find.text('first_group'), findsOneWidget);
      expect(find.text('second_group'), findsOneWidget);
      expect(controller.findArgument('display', 'enabled')!.value, false);
      expect(
        controller.findArgument('first_group', 'first_value')!.value,
        'first',
      );
      expect(
        controller.findArgument('second_group', 'second_value')!.value,
        'second',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

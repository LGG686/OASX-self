import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/models/script_analysis_models.dart';
import 'package:oasx/modules/home/widgets/action_path_card.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'package:oasx/modules/log/script_log_browser_controller.dart';

void main() {
  testWidgets('error detail shows export and map without generating a report', (tester) async {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.selectedErrorDetail.value = const ScriptErrorLogDetail(
      id: 'demo_1', directory: 'demo_1', scriptName: 'demo', timestampMs: 0,
      time: '2026-10-16 00:00:00', legacy: false,
      log: ScriptErrorLogText(fileName: 'log.txt', content: 'ValueError: test', size: 16,
        limitBytes: 1048576, truncated: false), images: []);
    final vertical = ScrollController(), horizontal = ScrollController();
    await tester.pumpWidget(GetMaterialApp(home: Scaffold(body: SizedBox(width: 320,
      child: LogCenterErrorDetailView(controller: controller,
        detailScrollController: vertical, detailHorizontalScrollController: horizontal)))));
    await tester.pumpAndSettle();
    expect(find.text('下载 Markdown 报告（图片和日志）'), findsOneWidget);
    expect(find.byType(ActionPathCard), findsOneWidget);
    expect(controller.exportingErrorReport.value, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vertical.dispose(); horizontal.dispose(); controller.onClose();
  });
  testWidgets('path switches work in a narrow panel', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox(width: 280,
      child: ActionPathCard(data: ScriptAnalysisSnapshot([]), colorByTask: true)))));
    expect(find.byType(FilterChip), findsNWidgets(3));
    await tester.tap(find.byType(FilterChip).first);
    await tester.pump();
    expect(tester.widget<FilterChip>(find.byType(FilterChip).first).selected, isFalse);
    expect(tester.takeException(), isNull);
  });
}

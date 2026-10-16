import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/models/script_analysis_models.dart';
import 'package:oasx/modules/home/widgets/action_path_card.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'package:oasx/modules/log/script_log_browser_controller.dart';
import 'package:oasx/modules/log/models/error_report.dart';

void main() {
  testWidgets(
    'legacy errors are visibly separate and refresh failures stay visible',
    (tester) async {
      final controller = ScriptLogBrowserController(scriptName: 'oas1');
      controller.errorItems.assignAll([
        const ScriptErrorLogItem(
          id: 'oas1_1',
          directory: 'oas1_1',
          scriptName: 'oas1',
          timestampMs: 1,
          time: '',
          legacy: false,
          logSize: 1,
          imageCount: 0,
        ),
        const ScriptErrorLogItem(
          id: '1788964567785',
          directory: '1788964567785',
          scriptName: null,
          timestampMs: 1788964567785,
          time: '',
          legacy: true,
          logSize: 1,
          imageCount: 0,
        ),
      ]);
      for (final item in controller.errorItems) {
        controller.errorSummaries['${item.id}:${item.logSize}'] = Future.value(
          const ErrorLogSummary('RealmRaid', 'ValueError'),
        );
      }
      controller.errorMessage.value = '读取错误日志列表失败（HTTP 500）：fixture failure';
      final list = ScrollController(),
          detail = ScrollController(),
          horizontal = ScrollController();
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: LogCenterErrorView(
              controller: controller,
              listScrollController: list,
              detailScrollController: detail,
              detailHorizontalScrollController: horizontal,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('归属未确认的旧日志（不计入当前配置）'), findsOneWidget);
      expect(find.textContaining('配置：oas1'), findsOneWidget);
      expect(find.textContaining('配置：未确认'), findsOneWidget);
      expect(find.textContaining('HTTP 500'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      list.dispose();
      detail.dispose();
      horizontal.dispose();
      controller.onClose();
    },
  );
  testWidgets(
    'info refresh error remains visible alongside existing log lines',
    (tester) async {
      final controller = ScriptLogBrowserController(scriptName: 'oas1');
      controller.lines.add(
        const ScriptLogLine(
          fileName: '2026-10-16_oas1.txt',
          lineNo: 1,
          offset: 0,
          byteLength: 4,
          text: 'existing line',
          lineTruncated: false,
        ),
      );
      controller.infoError.value = '读取运行日志失败（HTTP 404）：fixture unavailable';
      final vertical = ScrollController(), horizontal = ScrollController();
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: LogCenterInfoView(
              controller: controller,
              scrollController: vertical,
              horizontalScrollController: horizontal,
              onScrollNotification: (_) => false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 404'), findsOneWidget);
      expect(
        find.textContaining('existing line', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vertical.dispose();
      horizontal.dispose();
      controller.onClose();
    },
  );
  testWidgets('error detail shows export and map without generating a report', (
    tester,
  ) async {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.selectedErrorDetail.value = const ScriptErrorLogDetail(
      id: 'demo_1',
      directory: 'demo_1',
      scriptName: 'demo',
      timestampMs: 0,
      time: '2026-10-16 00:00:00',
      legacy: false,
      log: ScriptErrorLogText(
        fileName: 'log.txt',
        content: 'ValueError: test',
        size: 16,
        limitBytes: 1048576,
        truncated: false,
      ),
      images: [],
    );
    final vertical = ScrollController(), horizontal = ScrollController();
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: LogCenterErrorDetailView(
              controller: controller,
              detailScrollController: vertical,
              detailHorizontalScrollController: horizontal,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('下载 Markdown 报告（图片和日志）'), findsOneWidget);
    expect(find.byType(ActionPathCard), findsOneWidget);
    expect(controller.exportingErrorReport.value, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vertical.dispose();
    horizontal.dispose();
    controller.onClose();
  });
  testWidgets('path switches work in a narrow panel', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: ActionPathCard(
              data: ScriptAnalysisSnapshot([]),
              colorByTask: true,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FilterChip), findsNWidgets(3));
    await tester.tap(find.byType(FilterChip).first);
    await tester.pump();
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip).first).selected,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}

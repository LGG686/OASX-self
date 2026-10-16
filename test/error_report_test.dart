import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'package:oasx/modules/log/models/error_report.dart';

ScriptErrorLogDetail detail(String text, {bool truncated = false}) =>
    ScriptErrorLogDetail(
      id: 'demo_1',
      directory: 'demo_1',
      scriptName: 'demo',
      timestampMs: 0,
      time: '2026-10-16 00:00:01',
      legacy: false,
      log: ScriptErrorLogText(
        fileName: 'log.txt',
        content: text,
        size: text.length,
        limitBytes: 1048576,
        truncated: truncated,
      ),
      images: const [],
    );

void main() {
  test('last scheduled task and exception type win', () {
    final summary = ErrorLogSummary.parse(
      '[Task] First (Enable)\n'
      '2026-10-16 00:00:00.000 | INFO | Scheduler: Start task `Last`\n'
      'ValueError: first\nmodule.errors.ScriptError: second',
    );
    expect(summary.task, 'Last');
    expect(summary.type, 'ScriptError');
  });
  test('missing metadata is explicit', () {
    final summary = ErrorLogSummary.parse('unstructured text');
    expect(summary.task, '未知任务');
    expect(summary.type, '未知错误');
  });
  test('truncated logs must not claim to identify the last failing task', () {
    final summary = ErrorLogSummary.parse(
      '[Task] First (Enable)',
      truncated: true,
    );
    expect(summary.task, contains('无法确认最后任务'));
  });
  test('error path spans midnight and retains task identity', () {
    final snapshot = analyzeErrorLog(
      detail(
        '2026-10-15 23:59:59.000 | INFO | Scheduler: Start task `First`\n'
        '2026-10-15 23:59:59.001 | INFO | Click (10, 20) @ OK\n'
        '2026-10-16 00:00:00.000 | INFO | Click (20, 30) @ OK\n'
        '2026-10-16 00:00:00.001 | INFO | Scheduler: Start task `Second`\n'
        '2026-10-16 00:00:00.002 | INFO | Click (30, 40) @ OK',
      ),
    );
    expect(snapshot.clickCount, 3);
    expect(snapshot.events.map((e) => e.task), ['First', 'First', 'Second']);
  });
  test('Markdown embeds bytes, preserves logs and marks truncation', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final report = buildErrorMarkdown(
      detail('log\n```\nend', truncated: true),
      [ScriptErrorImageBytes(fileName: 'image.png', bytes: bytes)],
    );
    expect(report, contains('data:image/png;base64,${base64Encode(bytes)}'));
    expect(report, contains('````text\nlog\n```\nend\n````'));
    expect(report, contains('不是完整日志'));
  });
}

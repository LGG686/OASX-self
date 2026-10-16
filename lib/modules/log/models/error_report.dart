import 'dart:convert';

import 'package:oasx/modules/home/models/script_analysis_models.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'log_task_context.dart';

/// Metadata is derived from existing logs, so older backends remain compatible.
class ErrorLogSummary {
  const ErrorLogSummary(this.task, this.type);
  final String task;
  final String type;

  factory ErrorLogSummary.parse(String text, {bool truncated = false}) {
    final tasks = LogTaskContext();
    var type = '未知错误';
    final exception = RegExp(
      r'^\s*(?:[\w.]+\.)?([A-Za-z_]\w*(?:Error|Exception)|KeyboardInterrupt|SystemExit):',
    );
    for (final line in const LineSplitter().convert(text)) {
      tasks.consume(line);
      final error = exception.firstMatch(line);
      if (error != null) {
        type = error.group(1)!;
      } else if (type == '未知错误') {
        final level = RegExp(
          r'\|\s*(ERROR|CRITICAL)\s*\|\s*(.+)',
        ).firstMatch(line);
        if (level != null) type = level.group(2)!.trim();
      }
    }
    return ErrorLogSummary(
      truncated
          ? '日志已截断，无法确认最后任务'
          : (tasks.task ?? tasks.fallbackTask ?? '未知任务'),
      truncated ? '已读取部分：$type' : type,
    );
  }
}

ScriptAnalysisSnapshot analyzeErrorLog(ScriptErrorLogDetail detail) {
  final context = LogTaskContext();
  var date = detail.time.length >= 10
      ? detail.time.substring(0, 10)
      : DateTime.fromMillisecondsSinceEpoch(
          detail.timestampMs,
        ).toIso8601String().substring(0, 10);
  final lines = <ScriptLogLine>[];
  for (final text in const LineSplitter().convert(detail.log.content)) {
    context.consume(text);
    date = RegExp(r'^(\d{4}-\d{2}-\d{2}) ').firstMatch(text)?.group(1) ?? date;
    lines.add(
      ScriptLogLine(
        fileName: '${date}_error.txt',
        lineNo: lines.length + 1,
        offset: 0,
        byteLength: text.length,
        text: text,
        lineTruncated: false,
      ),
    );
  }
  final dates = lines.map((line) => line.fileName.substring(0, 10)).toSet();
  final events =
      dates
          .expand(
            (day) => parseScriptAnalysis(
              lines,
              day,
              fallbackTask: context.fallbackTask,
            ).events,
          )
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
  return ScriptAnalysisSnapshot(events);
}

/// Called only by the explicit export action. Images travel inside the .md file.
String buildErrorMarkdown(
  ScriptErrorLogDetail detail,
  List<ScriptErrorImageBytes> images,
) {
  final summary = ErrorLogSummary.parse(
    detail.log.content,
    truncated: detail.log.truncated,
  );
  final output = StringBuffer('# OASX 错误报告\n\n');
  output.writeln(
    '- 任务：${summary.task}\n- 时间：${detail.time}\n- 错误类型：${summary.type}\n',
  );
  if (detail.log.truncated) output.writeln('> 注意：后端返回的日志已截断，以下不是完整日志。\n');
  output.writeln('## 截图\n\n图片内嵌于本文件；请使用支持 data URI 的 Markdown 阅读器。\n');
  for (var i = 0; i < images.length; i++) {
    output.writeln(
      '![错误截图 ${i + 1}](data:image/png;base64,${base64Encode(images[i].bytes)})\n',
    );
  }
  // Pick a fence longer than any fence in untrusted log text.
  var fence = '```';
  while (detail.log.content.contains(fence)) {
    fence += '`';
  }
  output.writeln('## 日志\n\n${fence}text\n${detail.log.content}\n$fence');
  return output.toString();
}

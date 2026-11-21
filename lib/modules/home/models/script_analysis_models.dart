import 'package:oasx/modules/log/log_browser_models.dart';
import 'package:oasx/modules/log/models/log_task_context.dart';

enum ScriptActionKind { click, swipe }

class ScriptActionEvent {
  const ScriptActionEvent({
    required this.time,
    required this.kind,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.task,
    required this.control,
  });

  final DateTime time;
  final ScriptActionKind kind;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final String task;
  final String control;

  bool get isRandomClick =>
      kind == ScriptActionKind.click &&
      control.toLowerCase().contains('random');
}

class ScriptAnalysisSnapshot {
  const ScriptAnalysisSnapshot(this.events);

  final List<ScriptActionEvent> events;

  int get clickCount =>
      events.where((event) => event.kind == ScriptActionKind.click).length;
  int get randomClickCount =>
      events.where((event) => event.isRandomClick).length;
  int get taskCount => clicksByTask.length;

  Map<String, int> get clicksByTask {
    final values = <String, int>{};
    for (final event in events.where((e) => e.kind == ScriptActionKind.click)) {
      values.update(event.task, (value) => value + 1, ifAbsent: () => 1);
    }
    return values;
  }

  List<int> get clicksPerFourHours {
    return _clicksPerFourHours(
      events.where((event) => event.kind == ScriptActionKind.click),
    );
  }

  List<int> get randomClicksPerFourHours {
    return _clicksPerFourHours(events.where((event) => event.isRandomClick));
  }

  List<int> _clicksPerFourHours(Iterable<ScriptActionEvent> source) {
    final values = List<int>.filled(6, 0);
    for (final event in source) {
      values[event.time.hour ~/ 4]++;
    }
    return values;
  }
}

final RegExp _fullTimestamp = RegExp(
  r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})',
);
final RegExp _compactTimestamp = RegExp(r'^(\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})');
final RegExp _clickPattern = RegExp(
  r'Click\s+\(\s*(\d+),\s*(\d+)\)\s+@\s+(.+?)\s*$',
);
final RegExp _swipePattern = RegExp(
  r'Swipe\s+\(\s*(\d+),\s*(\d+)\)\s*->\s*\(\s*(\d+),\s*(\d+)\)',
);

/// Parses one pass over [lines] and builds a snapshot per requested date.
///
/// The analysis panel needs the selected day plus the recent-trend days;
/// running the previous per-date parse 8 times over the same lines compiled
/// millions of regexes on the UI isolate and froze the app. One pass that
/// files events into per-date buckets produces identical results because
/// [LogTaskContext] advances over every line exactly as before.
Map<String, ScriptAnalysisSnapshot> parseScriptAnalysisByDates(
  Iterable<ScriptLogLine> lines,
  Set<String> dateKeys, {
  String? fallbackTask,
}) {
  final taskContext = LogTaskContext();
  final eventsByDate = <String, List<ScriptActionEvent>>{
    for (final date in dateKeys) date: <ScriptActionEvent>[],
  };
  for (final line in lines) {
    final fileDate = line.fileName.length >= 10
        ? line.fileName.substring(0, 10)
        : '';
    taskContext.consume(line.text);
    final task =
        taskContext.task ??
        taskContext.fallbackTask ??
        fallbackTask ??
        'Unknown';
    final events = eventsByDate[fileDate];
    if (events == null) continue;
    final fullTimeMatch = _fullTimestamp.firstMatch(line.text);
    final compactTimeMatch = fullTimeMatch == null
        ? _compactTimestamp.firstMatch(line.text)
        : null;
    final timestampText = fullTimeMatch?.group(1) ??
        (compactTimeMatch == null || fileDate.length < 4
            ? null
            : '${fileDate.substring(0, 4)}-${compactTimeMatch.group(1)}');
    final time = timestampText == null
        ? null
        : DateTime.tryParse(timestampText.replaceFirst(' ', 'T'));
    if (time == null) continue;
    final click = _clickPattern.firstMatch(line.text);
    if (click != null) {
      events.add(
        ScriptActionEvent(
          time: time,
          kind: ScriptActionKind.click,
          startX: double.parse(click.group(1)!),
          startY: double.parse(click.group(2)!),
          endX: double.parse(click.group(1)!),
          endY: double.parse(click.group(2)!),
          task: task,
          control: click.group(3)!.trim(),
        ),
      );
      continue;
    }
    final swipe = _swipePattern.firstMatch(line.text);
    if (swipe != null) {
      events.add(
        ScriptActionEvent(
          time: time,
          kind: ScriptActionKind.swipe,
          startX: double.parse(swipe.group(1)!),
          startY: double.parse(swipe.group(2)!),
          endX: double.parse(swipe.group(3)!),
          endY: double.parse(swipe.group(4)!),
          task: task,
          control: 'Swipe',
        ),
      );
    }
  }
  return {
    for (final entry in eventsByDate.entries)
      entry.key: ScriptAnalysisSnapshot(entry.value),
  };
}

ScriptAnalysisSnapshot parseScriptAnalysis(
  Iterable<ScriptLogLine> lines,
  String dateKey, {
  String? fallbackTask,
}) {
  return parseScriptAnalysisByDates(
    lines,
    {dateKey},
    fallbackTask: fallbackTask,
  )[dateKey] ??
  const ScriptAnalysisSnapshot([]);
}

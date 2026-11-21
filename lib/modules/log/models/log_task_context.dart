import 'package:get/get.dart';
import 'package:oasx/translation/i18n.dart';

/// Precompiled patterns: parse runs over hundreds of thousands of log lines,
/// so compiling RegExp per line is the single hottest cost.
final RegExp _taskTagRe = RegExp(
  r'\[Task\]\s+(\w+)\s+\(|Scheduler: Start task `([^`]+)`',
);
final RegExp _separatorRe = RegExp(r'^═{15,}$');
final RegExp _titleRe = RegExp(r'^─{10,}\s*(.*?)\s*─{10,}$');
final RegExp _modulePathRe = RegExp(r'tasks[/\\]([^/\\]+)[/\\]script_task\.py');
final RegExp _whitespaceRe = RegExp(r'[\s_]');

String _normalizeTaskKey(String text) =>
    text.replaceAll(_whitespaceRe, '').toUpperCase();

/// Bundled Chinese translations are static data; build them once instead of
/// per call. Backend additions arrive through Get.translations instead.
final Map<String, String> _bundledCnTranslate = Messages().all_cn_translate;

/// One normalized-key -> canonical-key index over all known translations.
/// Rebuilt only when the translation tables change; the naive scan
/// (rebuild Messages + walk every key per heading) froze the UI isolate.
Map<String, String>? _canonicalIndex;
int? _canonicalIndexSignature;

int _translationsSignature() {
  var signature = _bundledCnTranslate.length;
  Get.translations.forEach((locale, table) {
    signature = signature * 31 + locale.hashCode + table.length;
  });
  return signature;
}

Map<String, String> _buildCanonicalIndex() {
  final index = <String, String>{};
  final tables = <Map<String, String>>[
    ...Get.translations.values,
    _bundledCnTranslate,
  ];
  for (final table in tables) {
    for (final key in table.keys) {
      index.putIfAbsent(_normalizeTaskKey(key), () => key);
    }
  }
  return index;
}

/// Use the same runtime translations as the task catalog, including backend additions.
/// Resolve on demand because remote translations may arrive after logs are opened.
String _canonicalTask(String value) {
  final signature = _translationsSignature();
  if (_canonicalIndex == null || _canonicalIndexSignature != signature) {
    _canonicalIndex = _buildCanonicalIndex();
    _canonicalIndexSignature = signature;
  }
  return _canonicalIndex![_normalizeTaskKey(value)] ?? value;
}

/// Tracks only level-0 task headings, not battle/page subheadings.
/// save_error_log keeps the final separator plus the preceding two lines,
/// so these headings survive even when scheduler/[Task] messages are omitted.
class LogTaskContext {
  String? task;
  String? fallbackTask;
  bool _separator = false;
  String? _heading;

  void consume(String line) {
    final explicit = _taskTagRe.firstMatch(line);
    if (explicit != null) {
      task = _canonicalTask(explicit.group(1) ?? explicit.group(2)!);
    }
    final trimmed = line.trim();
    if (_separatorRe.hasMatch(trimmed)) {
      if (_heading != null) {
        task = _heading!.toUpperCase() == 'START'
            ? null
            : _canonicalTask(_heading!);
      }
      _heading = null;
      _separator = true;
      return;
    }
    final title = _titleRe.firstMatch(trimmed);
    _heading = _separator ? title?.group(1)?.trim() : null;
    _separator = false;
    // Tracebacks and module_path survive in some older saved error formats.
    if (line.contains('module_path:') || line.trimLeft().startsWith('File ')) {
      final path = _modulePathRe.firstMatch(line);
      if (path != null) fallbackTask = _canonicalTask(path.group(1)!);
    }
  }
}

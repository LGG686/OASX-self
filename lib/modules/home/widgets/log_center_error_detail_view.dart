part of 'log_center_panel.dart';

/// Error report export and task-colored action map.
class LogCenterErrorDetailView extends StatelessWidget {
  const LogCenterErrorDetailView({
    super.key, required this.controller, required this.detailScrollController,
    required this.detailHorizontalScrollController,
  });
  final ScriptLogBrowserController controller;
  final ScrollController detailScrollController;
  final ScrollController detailHorizontalScrollController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final detail = controller.selectedErrorDetail.value;
      final summary = detail == null ? null : ErrorLogSummary.parse(detail.log.content);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(tooltip: I18n.back.tr, onPressed: controller.backToErrorList,
            icon: const Icon(Icons.arrow_back_rounded)),
          Expanded(child: Text(summary?.task.tr ?? controller.selectedErrorTitle.value,
            style: Theme.of(context).textTheme.titleMedium)),
        ]),
        Expanded(child: detail == null
          ? Center(child: controller.errorDetailLoading.value
            ? const CircularProgressIndicator()
            : Text(controller.errorMessage.value.isEmpty ? '请选择错误日志' : controller.errorMessage.value))
          : Scrollbar(controller: detailScrollController, thumbVisibility: true,
            child: ListView(controller: detailScrollController, children: [
              Text(controller.formatErrorTimestamp(detail.timestampMs, detail.time)),
              const SizedBox(height: 6),
              SelectableText(summary!.type),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.exportingErrorReport.value ? null : controller.exportErrorReport,
                icon: const Icon(Icons.download_rounded),
                label: Text(controller.exportingErrorReport.value ? '正在制作报告…' : '下载 Markdown 报告（图片和日志）'),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('仅点击下载后制作文档。截图内嵌，需使用支持 data URI 的 Markdown 阅读器。',
                  style: TextStyle(fontSize: 12))),
              if (detail.log.truncated)
                const Text('日志超过接口上限（1 MiB），报告与点击图仅包含返回部分。'),
              ActionPathCard(key: ValueKey(detail.id), data: analyzeErrorLog(detail), colorByTask: true),
            ]),
          )),
      ]);
    });
  }
}

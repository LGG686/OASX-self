part of 'log_center_panel.dart';

/// Error log list and detail view.
class LogCenterErrorView extends StatelessWidget {
  /// Creates the error log view.
  const LogCenterErrorView({
    super.key,
    required this.controller,
    required this.listScrollController,
    required this.detailScrollController,
    required this.detailHorizontalScrollController,
  });

  /// Log browser controller.
  final ScriptLogBrowserController controller;

  /// Scroll controller for the error list.
  final ScrollController listScrollController;

  /// Scroll controller for the error detail.
  final ScrollController detailScrollController;

  /// Horizontal scroll controller for non-wrapped error detail text.
  final ScrollController detailHorizontalScrollController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.errorListLoading.value && controller.errorItems.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errorMessage.value.isNotEmpty &&
          controller.errorItems.isEmpty) {
        return Center(child: Text(controller.errorMessage.value));
      }
      if (controller.errorItems.isEmpty) {
        return Center(child: Text(I18n.homeLogNoErrors.tr));
      }
      return controller.errorDetailVisible.value
          ? _buildDetail(context)
          : _buildList(context);
    });
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: listScrollController,
            interactive: true,
            thumbVisibility: true,
            child: ListView.separated(
              controller: listScrollController,
              itemCount: controller.errorItems.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                final item = controller.errorItems[index];
                return FutureBuilder<ErrorLogSummary>(
                  future: controller.errorSummary(item),
                  builder: (context, snapshot) {
                    final summary = snapshot.data;
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                        title: Text(summary?.task.tr ?? '正在读取任务…'),
                        subtitle: Text('${_formatErrorTime(item)}\n${summary?.type ?? "正在识别错误类型…"}',
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => controller.selectError(item.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (controller.errorHasMore.value) _buildLoadMore(context),
      ],
    );
  }

  Widget _buildLoadMore(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton(
        onPressed: () => controller.loadErrorList(),
        child: Text(I18n.homeLogLoadOlder.tr),
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    return LogCenterErrorDetailView(
      controller: controller,
      detailScrollController: detailScrollController,
      detailHorizontalScrollController: detailHorizontalScrollController,
    );
  }

  String _formatErrorTime(ScriptErrorLogItem item) {
    return controller.formatErrorTimestamp(item.timestampMs, item.time);
  }
}

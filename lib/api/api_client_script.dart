part of 'api_client.dart';

extension ApiClientScriptX on ApiClient {
  Future<Map<String, dynamic>> previewTaskEntry(
    String script,
    Map<String, dynamic> entry,
  ) async {
    final res = await request(
      () => post(
        '/${Uri.encodeComponent(script)}/CustomTask/entry-args',
        data: entry,
      ),
    );
    if (res.code == 404) {
      throw StateError('后端尚未加载自定义任务新接口，请重启后端服务后重试');
    }
    if (!res.isSuccess || res.data is! Map) {
      throw StateError(res.error ?? '任务配置读取失败');
    }
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>?> changeTaskList(
    String script,
    String task,
    Map<String, dynamic> change,
  ) async {
    if (change['preview'] == true) {
      // Old servers ignore unknown preview fields and would save immediately.
      await previewTaskEntry(script, {
        'id': 'compatibility-check',
        'type': 'AccountSwitch',
        'settings': {},
      });
    }
    final res = await request(
      () => post(
        '/${Uri.encodeComponent(script)}/${Uri.encodeComponent(task)}/list',
        data: change,
      ),
    );
    return res.isSuccess && res.data is Map
        ? Map<String, dynamic>.from(res.data)
        : null;
  }

  /// Loads the full argument model for one task.
  Future<Map<String, dynamic>> getScriptTask(
    String scriptName,
    String taskName, {
    bool fresh = false,
  }) async {
    final res = await request(
      () => get(
        '/${Uri.encodeComponent(scriptName)}/${Uri.encodeComponent(taskName)}/args',
        options: fresh ? _noCacheOptions() : null,
      ),
    );
    return res.data ?? {};
  }

  /// Persists one task argument through the generic value endpoint.
  Future<bool> putScriptArg(
    String scriptName,
    String taskName,
    String groupName,
    String argumentName,
    String type,
    dynamic value,
  ) async {
    final encodedValue = type == 'multi_enum' || type == 'task_list'
        ? jsonEncode(value)
        : value;
    final res = await request(
      () => put(
        '/$scriptName/$taskName/$groupName/$argumentName/value',
        queryParameters: {'types': type, 'value': encodedValue},
      ),
    );
    return res.isSuccess && res.data == true;
  }

  /// Synchronizes one task back into the waiting queue immediately.
  Future<bool> syncScriptTaskNextRun(
    String scriptName,
    String taskName,
    String targetDt,
  ) async {
    final res = await request(
      () => put(
        '/$scriptName/$taskName/sync_next_run',
        queryParameters: {'target_dt': targetDt},
      ),
    );
    return res.isSuccess && res.data == true;
  }
}

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/backup_service.dart';
import '../data/data_change_notifier.dart';
import '../utils/formatters.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = AppDatabase.instance;
  late final BackupService _backupService = BackupService(_db);
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportJson() => _run(() async {
        final path = await _backupService.exportJson();
        if (!mounted) return;
        showSnack(context, path == null ? '导出失败或权限未授权' : 'JSON已导出：$path');
      });

  Future<void> _exportExcel() => _run(() async {
        final path = await _backupService.exportExcel();
        if (!mounted) return;
        showSnack(context, path == null ? '导出失败或权限未授权' : 'Excel已导出：$path');
      });

  Future<void> _importJson() => _run(() async {
        final ok = await confirmDialog(
          context,
          title: '导入恢复',
          content: '导入JSON备份会替换当前全部账单，确认继续吗？',
        );
        if (!ok) return;
        final count = await _backupService.importJson();
        if (!mounted) return;
        showSnack(context, count == null ? '导入失败或已取消' : '已恢复 $count 条账单');
        if (count != null) DataChangeNotifier.instance.notifyChanged();
      });

  Future<void> _clearBills() => _run(() async {
        final ok = await confirmDialog(
          context,
          title: '清空全部账单',
          content: '确认清空全部账单数据吗？此操作不可恢复。',
          confirmText: '清空',
        );
        if (!ok) return;
        final success = await _db.clearBills();
        if (!mounted) return;
        showSnack(context, success ? '已清空全部账单' : '清空失败');
        if (success) DataChangeNotifier.instance.notifyChanged();
      });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('设置', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.table_view),
              title: const Text('导出Excel账单'),
              subtitle: const Text('保存到手机本地存储空间'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportExcel,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.data_object),
              title: const Text('导出JSON备份'),
              subtitle: const Text('用于本地备份与恢复'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportJson,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restore_page_outlined),
              title: const Text('导入JSON恢复'),
              subtitle: const Text('读取本地备份文件并替换当前账单'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _importJson,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('清空全部账单'),
              subtitle: const Text('会弹出二次确认，防止误操作'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _clearBills,
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('应用版本：1.0.0'),
                    SizedBox(height: 8),
                    Text('隐私说明：LUSH记账仅在手机本地保存账单数据，不上传云端，不包含任何网络请求。'),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_busy)
          const ColoredBox(
            color: Color(0x33000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

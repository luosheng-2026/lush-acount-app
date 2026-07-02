import 'package:flutter/material.dart';

import '../constants/default_categories.dart';
import '../data/app_database.dart';
import '../data/data_change_notifier.dart';
import '../models/category.dart';
import '../utils/formatters.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _db = AppDatabase.instance;
  int _type = expenseType;
  List<AccountCategory> _parents = [];
  final Map<int, List<AccountCategory>> _childrenMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    DataChangeNotifier.instance.version.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DataChangeNotifier.instance.version.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final parents = await _db.getCategories(type: _type, parentId: 0);
    final childrenMap = <int, List<AccountCategory>>{};
    for (final parent in parents) {
      if (parent.id != null) {
        childrenMap[parent.id!] = await _db.getCategories(
          type: _type,
          parentId: parent.id,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _parents = parents;
      _childrenMap
        ..clear()
        ..addAll(childrenMap);
      _loading = false;
    });
  }

  Future<String?> _askName({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '分类名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  Future<void> _addParent() async {
    final name = await _askName(title: '新增一级分类');
    if (name == null) return;
    final id = await _db.insertCategory(AccountCategory(
      parentId: 0,
      name: name,
      type: _type,
      sort: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    showSnack(context, id > 0 ? '已新增分类' : '新增失败');
    if (id > 0) DataChangeNotifier.instance.notifyChanged();
  }

  Future<void> _addChild(AccountCategory parent) async {
    final name = await _askName(title: '新增二级子类');
    if (name == null || parent.id == null) return;
    final id = await _db.insertCategory(AccountCategory(
      parentId: parent.id!,
      name: name,
      type: _type,
      sort: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    showSnack(context, id > 0 ? '已新增子类' : '新增失败');
    if (id > 0) DataChangeNotifier.instance.notifyChanged();
  }

  Future<void> _rename(AccountCategory category) async {
    final name = await _askName(
      title: category.isParent ? '修改一级分类' : '修改二级子类',
      initialValue: category.name,
    );
    if (name == null) return;
    final success = await _db.updateCategory(category.copyWith(name: name));
    if (!mounted) return;
    showSnack(context, success ? '已保存修改' : '修改失败');
    if (success) DataChangeNotifier.instance.notifyChanged();
  }

  Future<void> _delete(AccountCategory category) async {
    final ok = await confirmDialog(
      context,
      title: '删除分类',
      content: category.isParent
          ? '确认删除“${category.name}”及其下所有二级子类吗？有账单关联时将禁止删除。'
          : '确认删除“${category.name}”吗？有账单关联时将禁止删除。',
      confirmText: '删除',
    );
    if (!ok) return;
    final success = await _db.deleteCategory(category);
    if (!mounted) return;
    showSnack(context, success ? '已删除分类' : '删除失败：该分类可能已有账单关联');
    if (success) DataChangeNotifier.instance.notifyChanged();
  }

  Future<void> _resetDefault() async {
    final ok = await confirmDialog(
      context,
      title: '重置默认分类',
      content: '确认恢复系统初始默认分类模板吗？已有账单时会禁止重置，防止账单分类异常。',
    );
    if (!ok) return;
    final success = await _db.resetDefaultCategories();
    if (!mounted) return;
    showSnack(context, success ? '已恢复默认分类' : '重置失败：请先清空账单或保留现有分类');
    if (success) DataChangeNotifier.instance.notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '分类管理',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: '重置默认分类',
                    onPressed: _resetDefault,
                    icon: const Icon(Icons.restart_alt),
                  ),
                  IconButton(
                    tooltip: '新增一级分类',
                    onPressed: _addParent,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: expenseType, label: Text('支出分类')),
                  ButtonSegment(value: incomeType, label: Text('收入分类')),
                ],
                selected: {_type},
                onSelectionChanged: (value) {
                  setState(() => _type = value.first);
                  _load();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _parents.isEmpty
                  ? const Center(child: Text('暂无分类'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      itemCount: _parents.length,
                      itemBuilder: (context, index) {
                        final parent = _parents[index];
                        final children = _childrenMap[parent.id] ?? [];
                        return ExpansionTile(
                          key: ValueKey(parent.id),
                          initiallyExpanded: true,
                          title: Text(parent.name),
                          subtitle: Text('${children.length} 个二级子类'),
                          trailing: PopupMenuButton<String>(
                            tooltip: '分类操作',
                            onSelected: (value) {
                              if (value == 'add') _addChild(parent);
                              if (value == 'edit') _rename(parent);
                              if (value == 'delete') _delete(parent);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'add', child: Text('新增子类')),
                              PopupMenuItem(value: 'edit', child: Text('修改分类')),
                              PopupMenuItem(value: 'delete', child: Text('删除分类')),
                            ],
                          ),
                          children: children
                              .map((child) => ListTile(
                                    title: Text(child.name),
                                    leading: const Icon(Icons.subdirectory_arrow_right),
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        IconButton(
                                          tooltip: '修改子类',
                                          onPressed: () => _rename(child),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: '删除子类',
                                          onPressed: () => _delete(child),
                                          icon: const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/default_categories.dart';
import '../data/app_database.dart';
import '../data/data_change_notifier.dart';
import '../models/bill.dart';
import '../models/category.dart';
import '../utils/formatters.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _moneyController = TextEditingController();
  final _remarkController = TextEditingController();
  final _db = AppDatabase.instance;

  int _billType = expenseType;
  DateTime _billTime = DateTime.now();
  List<AccountCategory> _parents = [];
  List<AccountCategory> _children = [];
  AccountCategory? _selectedParent;
  AccountCategory? _selectedChild;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _moneyController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    final parents = await _db.getCategories(type: _billType, parentId: 0);
    final firstParent = parents.isEmpty ? null : parents.first;
    final children = firstParent == null
        ? <AccountCategory>[]
        : await _db.getCategories(type: _billType, parentId: firstParent.id);
    if (!mounted) return;
    setState(() {
      _parents = parents;
      _selectedParent = firstParent;
      _children = children;
      _selectedChild = children.isEmpty ? null : children.first;
      _loading = false;
    });
  }

  Future<void> _loadChildren(AccountCategory parent) async {
    final children = await _db.getCategories(
      type: _billType,
      parentId: parent.id,
    );
    if (!mounted) return;
    setState(() {
      _selectedParent = parent;
      _children = children;
      _selectedChild = children.isEmpty ? null : children.first;
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _billTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_billTime),
    );
    if (time == null) return;
    setState(() {
      _billTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final money = double.tryParse(_moneyController.text.trim());
    if (money == null || money <= 0) {
      showSnack(context, '请输入大于0的金额');
      return;
    }
    if (_selectedChild?.id == null) {
      showSnack(context, '请选择二级分类');
      return;
    }
    setState(() => _saving = true);
    final id = await _db.insertBill(Bill(
      money: money,
      billType: _billType,
      categoryId: _selectedChild!.id!,
      billTime: _billTime,
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (id > 0) {
      _moneyController.clear();
      _remarkController.clear();
      setState(() => _billTime = DateTime.now());
      DataChangeNotifier.instance.notifyChanged();
      showSnack(context, '记账成功');
    } else {
      showSnack(context, '保存失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text('快速记账', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: expenseType,
                    label: Text('支出'),
                    icon: Icon(Icons.trending_down),
                  ),
                  ButtonSegment(
                    value: incomeType,
                    label: Text('收入'),
                    icon: Icon(Icons.trending_up),
                  ),
                ],
                selected: {_billType},
                onSelectionChanged: (value) {
                  setState(() => _billType = value.first);
                  _loadCategories();
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _moneyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixText: '¥ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountCategory>(
                value: _selectedParent,
                decoration: const InputDecoration(
                  labelText: '一级分类',
                  border: OutlineInputBorder(),
                ),
                items: _parents
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) _loadChildren(value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountCategory>(
                value: _selectedChild,
                decoration: const InputDecoration(
                  labelText: '二级分类',
                  border: OutlineInputBorder(),
                ),
                items: _children
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedChild = value),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('记账时间'),
                subtitle: Text(dateTimeText(_billTime)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarkController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注（选填）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? '保存中' : '保存记账'),
              ),
            ],
          );
  }
}

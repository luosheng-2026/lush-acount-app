import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/default_categories.dart';
import '../data/app_database.dart';
import '../data/data_change_notifier.dart';
import '../models/bill.dart';
import '../models/category.dart';
import '../models/stat_summary.dart';
import '../utils/formatters.dart';

enum QuickRange { today, week, month, custom }

class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  final _db = AppDatabase.instance;
  QuickRange _range = QuickRange.month;
  DateTime? _start;
  DateTime? _end;
  int? _billType;
  int? _parentCategoryId;
  List<AccountCategory> _parentCategories = [];
  List<BillView> _bills = [];
  Summary _summary = const Summary(income: 0, expense: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _applyQuickRange(QuickRange.month, refresh: false);
    DataChangeNotifier.instance.version.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DataChangeNotifier.instance.version.removeListener(_load);
    super.dispose();
  }

  BillFilter get _filter => BillFilter(
        start: _start,
        end: _end,
        billType: _billType,
        parentCategoryId: _parentCategoryId,
      );

  void _applyQuickRange(QuickRange range, {bool refresh = true}) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;
    if (range == QuickRange.today) {
      start = dayStart(now);
      end = dayEnd(now);
    } else if (range == QuickRange.week) {
      start = dayStart(now).subtract(Duration(days: now.weekday - 1));
      end = dayEnd(start.add(const Duration(days: 6)));
    } else {
      start = DateTime(now.year, now.month);
      end = dayEnd(DateTime(now.year, now.month + 1, 0));
    }
    setState(() {
      _range = range;
      if (range != QuickRange.custom) {
        _start = start;
        _end = end;
      }
    });
    if (refresh) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final parentCategories = await _db.getCategories(parentId: 0);
    final bills = await _db.getBills(filter: _filter);
    final summary = await _db.getSummary(filter: _filter);
    if (!mounted) return;
    setState(() {
      _parentCategories = parentCategories;
      _bills = bills;
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _start == null || _end == null
          ? null
          : DateTimeRange(start: _start!, end: _end!),
    );
    if (range == null) return;
    setState(() {
      _range = QuickRange.custom;
      _start = dayStart(range.start);
      _end = dayEnd(range.end);
    });
    _load();
  }

  Future<void> _deleteBill(BillView bill) async {
    final ok = await confirmDialog(
      context,
      title: '删除账单',
      content: '确认删除这条账单吗？删除后无法恢复。',
      confirmText: '删除',
    );
    if (!ok) return;
    final success = await _db.deleteBill(bill.id!);
    if (!mounted) return;
    showSnack(context, success ? '已删除账单' : '删除失败');
    if (success) {
      DataChangeNotifier.instance.notifyChanged();
    }
  }

  Future<void> _showBillActions(BillView bill) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑账单'),
              onTap: () {
                Navigator.pop(context);
                _editBill(bill);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除账单'),
              onTap: () {
                Navigator.pop(context);
                _deleteBill(bill);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBill(BillView bill) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _BillEditDialog(bill: bill),
    );
    if (saved == true) {
      DataChangeNotifier.instance.notifyChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('账单列表', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              _SummaryPanel(summary: _summary),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('今日'),
                    selected: _range == QuickRange.today,
                    onSelected: (_) => _applyQuickRange(QuickRange.today),
                  ),
                  ChoiceChip(
                    label: const Text('本周'),
                    selected: _range == QuickRange.week,
                    onSelected: (_) => _applyQuickRange(QuickRange.week),
                  ),
                  ChoiceChip(
                    label: const Text('本月'),
                    selected: _range == QuickRange.month,
                    onSelected: (_) => _applyQuickRange(QuickRange.month),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.date_range),
                    label: Text(_range == QuickRange.custom && _start != null
                        ? '${dateText(_start!)} 至 ${dateText(_end!)}'
                        : '自定义'),
                    onPressed: _pickCustomRange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _billType,
                      decoration: const InputDecoration(labelText: '收支类型'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('全部')),
                        DropdownMenuItem(value: incomeType, child: Text('收入')),
                        DropdownMenuItem(value: expenseType, child: Text('支出')),
                      ],
                      onChanged: (value) {
                        setState(() => _billType = value);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _parentCategoryId,
                      decoration: const InputDecoration(labelText: '一级分类'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('全部')),
                        ..._parentCategories.map((item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _parentCategoryId = value);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _bills.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('暂无账单')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _bills.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final bill = _bills[index];
                        final isIncome = bill.billType == incomeType;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Icon(isIncome ? Icons.add : Icons.remove),
                          ),
                          title: Text('${bill.parentCategoryName} / ${bill.childCategoryName}'),
                          subtitle: Text([
                            dateTimeText(bill.billTime),
                            if ((bill.remark ?? '').isNotEmpty) bill.remark!,
                          ].join(' · ')),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}¥${moneyText(bill.money)}',
                            style: TextStyle(
                              color: isIncome ? Colors.green : Colors.redAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () => _showBillActions(bill),
                          onLongPress: () => _showBillActions(bill),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: _SummaryItem(label: '收入', value: summary.income)),
            Expanded(child: _SummaryItem(label: '支出', value: summary.expense)),
            Expanded(child: _SummaryItem(label: '结余', value: summary.balance)),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text('¥${moneyText(value)}', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _BillEditDialog extends StatefulWidget {
  const _BillEditDialog({required this.bill});

  final BillView bill;

  @override
  State<_BillEditDialog> createState() => _BillEditDialogState();
}

class _BillEditDialogState extends State<_BillEditDialog> {
  final _db = AppDatabase.instance;
  late final TextEditingController _moneyController;
  late final TextEditingController _remarkController;
  late int _billType;
  late DateTime _billTime;
  List<AccountCategory> _parents = [];
  List<AccountCategory> _children = [];
  AccountCategory? _selectedParent;
  AccountCategory? _selectedChild;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _moneyController = TextEditingController(text: moneyText(widget.bill.money));
    _remarkController = TextEditingController(text: widget.bill.remark ?? '');
    _billType = widget.bill.billType;
    _billTime = widget.bill.billTime;
    _loadCategories();
  }

  @override
  void dispose() {
    _moneyController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final parents = await _db.getCategories(type: _billType, parentId: 0);
    final selectedParent = _findById(parents, widget.bill.parentCategoryId) ??
        (parents.isEmpty ? null : parents.first);
    final children = selectedParent == null
        ? <AccountCategory>[]
        : await _db.getCategories(type: _billType, parentId: selectedParent.id);
    final selectedChild = _findById(children, widget.bill.categoryId) ??
        (children.isEmpty ? null : children.first);
    if (!mounted) return;
    setState(() {
      _parents = parents;
      _selectedParent = selectedParent;
      _children = children;
      _selectedChild = selectedChild;
      _loading = false;
    });
  }

  Future<void> _reloadForType(int type) async {
    setState(() {
      _billType = type;
      _loading = true;
    });
    final parents = await _db.getCategories(type: type, parentId: 0);
    final selectedParent = parents.isEmpty ? null : parents.first;
    final children = selectedParent == null
        ? <AccountCategory>[]
        : await _db.getCategories(type: type, parentId: selectedParent.id);
    if (!mounted) return;
    setState(() {
      _parents = parents;
      _selectedParent = selectedParent;
      _children = children;
      _selectedChild = children.isEmpty ? null : children.first;
      _loading = false;
    });
  }

  AccountCategory? _findById(List<AccountCategory> items, int id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _loadChildren(AccountCategory parent) async {
    final children = await _db.getCategories(type: _billType, parentId: parent.id);
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
    final success = await _db.updateBill(Bill(
      id: widget.bill.id,
      money: money,
      billType: _billType,
      categoryId: _selectedChild!.id!,
      billTime: _billTime,
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
      createTime: widget.bill.createTime,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      Navigator.pop(context, true);
    } else {
      showSnack(context, '保存失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑账单'),
      content: _loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: expenseType, label: Text('支出')),
                      ButtonSegment(value: incomeType, label: Text('收入')),
                    ],
                    selected: {_billType},
                    onSelectionChanged: (value) => _reloadForType(value.first),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('记账时间'),
                    subtitle: Text(dateTimeText(_billTime)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDateTime,
                  ),
                  TextField(
                    controller: _remarkController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '备注（选填）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中' : '保存'),
        ),
      ],
    );
  }
}

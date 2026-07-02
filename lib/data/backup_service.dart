import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/default_categories.dart';
import '../models/bill.dart';
import '../models/category.dart';
import '../utils/formatters.dart';
import 'app_database.dart';

class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final storage = await Permission.storage.request();
    // Android 10+ allows app-specific export directories and system file pickers
    // without broad storage access. We still request permission first for older
    // devices and vendor ROM prompts, then continue with scoped storage fallback.
    return storage.isGranted ||
        storage.isDenied ||
        storage.isPermanentlyDenied ||
        storage.isRestricted ||
        storage.isLimited;
  }

  Future<Directory> _exportDirectory() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) return directory;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<String?> exportJson() async {
    if (!await ensureStoragePermission()) return null;
    final bills = await _db.getBills();
    final directory = await _exportDirectory();
    final file = File(p.join(directory.path, 'lush_backup_${_stamp()}.json'));
    final payload = {
      'app': 'LUSH记账',
      'version': 1,
      'export_time': DateTime.now().toIso8601String(),
      'bills': bills.map((bill) {
        return {
          ...bill.toMap(),
          'parent_category_name': bill.parentCategoryName,
          'child_category_name': bill.childCategoryName,
        };
      }).toList(),
    };
    await file.writeAsString(jsonEncode(payload), flush: true);
    return file.path;
  }

  Future<String?> exportExcel() async {
    if (!await ensureStoragePermission()) return null;
    final bills = await _db.getBills();
    final directory = await _exportDirectory();
    final file = File(p.join(directory.path, 'lush_bills_${_stamp()}.xlsx'));
    final excel = Excel.createExcel();
    final sheet = excel['账单'];
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('类型'),
      TextCellValue('金额'),
      TextCellValue('一级分类'),
      TextCellValue('二级分类'),
      TextCellValue('记账时间'),
      TextCellValue('备注'),
    ]);
    for (final bill in bills) {
      sheet.appendRow([
        IntCellValue(bill.id ?? 0),
        TextCellValue(bill.billType == incomeType ? '收入' : '支出'),
        DoubleCellValue(bill.money),
        TextCellValue(bill.parentCategoryName),
        TextCellValue(bill.childCategoryName),
        TextCellValue(dateTimeText(bill.billTime)),
        TextCellValue(bill.remark ?? ''),
      ]);
    }
    final bytes = excel.encode();
    if (bytes == null) return null;
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<int?> importJson() async {
    try {
      if (!await ensureStoragePermission()) return null;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return null;
      final content = await File(path).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final rawBills = data['bills'];
      if (rawBills is! List) return null;
      final bills = <Bill>[];
      for (final item in rawBills) {
        if (item is! Map<String, dynamic>) continue;
        final bill = await _parseBackupBill(item);
        if (bill != null) bills.add(bill);
      }
      final success = await _db.replaceBills(bills);
      return success ? bills.length : null;
    } catch (_) {
      return null;
    }
  }

  Future<Bill?> _parseBackupBill(Map<String, dynamic> row) async {
    final money = row['money'];
    final type = row['bill_type'];
    final billTime = row['bill_time'];
    if (money is! num || type is! int || billTime is! String) return null;
    if (money <= 0 || (type != incomeType && type != expenseType)) return null;
    final categoryId = await _resolveCategoryId(row, type);
    if (categoryId == null) return null;
    final parsedTime = DateTime.tryParse(billTime);
    if (parsedTime == null) return null;
    return Bill(
      money: money.toDouble(),
      billType: type,
      categoryId: categoryId,
      billTime: parsedTime,
      remark: row['remark'] as String?,
    );
  }

  Future<int?> _resolveCategoryId(Map<String, dynamic> row, int type) async {
    final parentName = row['parent_category_name'] as String?;
    final childName = row['child_category_name'] as String?;
    if (parentName != null && childName != null) {
      final parents = await _db.getCategories(type: type, parentId: 0);
      AccountCategory? parent;
      for (final item in parents) {
        if (item.name == parentName) {
          parent = item;
          break;
        }
      }
      if (parent?.id != null) {
        final children = await _db.getCategories(type: type, parentId: parent!.id);
        for (final child in children) {
          if (child.name == childName) return child.id;
        }
      }
    }

    final fallbackId = row['category_id'] as int?;
    if (fallbackId == null) return null;
    final categories = await _db.getCategories(type: type);
    for (final item in categories) {
      if (item.id == fallbackId && !item.isParent) return fallbackId;
    }
    return null;
  }

  String _stamp() {
    final now = DateTime.now();
    return '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

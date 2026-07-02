import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../constants/default_categories.dart';
import '../models/bill.dart';
import '../models/category.dart';
import '../models/stat_summary.dart';

class BillFilter {
  const BillFilter({
    this.start,
    this.end,
    this.billType,
    this.parentCategoryId,
  });

  final DateTime? start;
  final DateTime? end;
  final int? billType;
  final int? parentCategoryId;
}

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const _databaseName = 'lush_account.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createTables(db);
        await db.transaction(_insertDefaultCategories);
      },
      onOpen: (db) async {
        final count = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM category'),
            ) ??
            0;
        if (count == 0) {
          await db.transaction(_insertDefaultCategories);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        sort INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE bill (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        money REAL NOT NULL,
        bill_type INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        bill_time TEXT NOT NULL,
        remark TEXT,
        create_time TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _insertDefaultCategories(Transaction txn) async {
    var sort = 0;
    Future<void> insertGroup(int type, Map<String, List<String>> source) async {
      for (final entry in source.entries) {
        final parentId = await txn.insert(
          'category',
          AccountCategory(
            parentId: 0,
            name: entry.key,
            type: type,
            sort: sort++,
          ).toMap(includeId: false),
        );
        for (final childName in entry.value) {
          await txn.insert(
            'category',
            AccountCategory(
              parentId: parentId,
              name: childName,
              type: type,
              sort: sort++,
            ).toMap(includeId: false),
          );
        }
      }
    }

    await insertGroup(expenseType, defaultExpenseCategories);
    await insertGroup(incomeType, defaultIncomeCategories);
  }

  Future<List<AccountCategory>> getCategories({
    int? type,
    int? parentId,
  }) async {
    try {
      final db = await database;
      final whereParts = <String>[];
      final args = <Object?>[];
      if (type != null) {
        whereParts.add('type = ?');
        args.add(type);
      }
      if (parentId != null) {
        whereParts.add('parent_id = ?');
        args.add(parentId);
      }
      final rows = await db.query(
        'category',
        where: whereParts.isEmpty ? null : whereParts.join(' AND '),
        whereArgs: args,
        orderBy: 'sort ASC, id ASC',
      );
      return rows.map(AccountCategory.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> insertCategory(AccountCategory category) async {
    try {
      final db = await database;
      return db.insert('category', category.toMap(includeId: false));
    } catch (_) {
      return 0;
    }
  }

  Future<bool> updateCategory(AccountCategory category) async {
    if (category.id == null) return false;
    try {
      final db = await database;
      final count = await db.update(
        'category',
        category.toMap(includeId: false),
        where: 'id = ?',
        whereArgs: [category.id],
      );
      return count > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> canDeleteCategory(AccountCategory category) async {
    if (category.id == null) return false;
    try {
      final db = await database;
      if (category.isParent) {
        final childIds = await db.query(
          'category',
          columns: ['id'],
          where: 'parent_id = ?',
          whereArgs: [category.id],
        );
        if (childIds.isEmpty) return true;
        final placeholders = List.filled(childIds.length, '?').join(',');
        final billCount = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM bill WHERE category_id IN ($placeholders)',
              childIds.map((row) => row['id']).toList(),
            )) ??
            0;
        return billCount == 0;
      }
      final billCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM bill WHERE category_id = ?',
            [category.id],
          )) ??
          0;
      return billCount == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCategory(AccountCategory category) async {
    if (category.id == null || !await canDeleteCategory(category)) return false;
    try {
      final db = await database;
      await db.transaction((txn) async {
        if (category.isParent) {
          await txn.delete(
            'category',
            where: 'parent_id = ?',
            whereArgs: [category.id],
          );
        }
        await txn.delete(
          'category',
          where: 'id = ?',
          whereArgs: [category.id],
        );
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetDefaultCategories() async {
    try {
      final db = await database;
      final billCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM bill'),
          ) ??
          0;
      if (billCount > 0) return false;
      await db.transaction((txn) async {
        await txn.delete('category');
        await _insertDefaultCategories(txn);
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> insertBill(Bill bill) async {
    try {
      final db = await database;
      return db.insert('bill', bill.toMap(includeId: false));
    } catch (_) {
      return 0;
    }
  }

  Future<bool> updateBill(Bill bill) async {
    if (bill.id == null) return false;
    try {
      final db = await database;
      final count = await db.update(
        'bill',
        bill.toMap(includeId: false),
        where: 'id = ?',
        whereArgs: [bill.id],
      );
      return count > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteBill(int id) async {
    try {
      final db = await database;
      final count = await db.delete('bill', where: 'id = ?', whereArgs: [id]);
      return count > 0;
    } catch (_) {
      return false;
    }
  }

  Future<List<BillView>> getBills({BillFilter filter = const BillFilter()}) async {
    try {
      final db = await database;
      final whereParts = <String>[];
      final args = <Object?>[];
      if (filter.start != null) {
        whereParts.add('datetime(b.bill_time) >= datetime(?)');
        args.add(filter.start!.toIso8601String());
      }
      if (filter.end != null) {
        whereParts.add('datetime(b.bill_time) <= datetime(?)');
        args.add(filter.end!.toIso8601String());
      }
      if (filter.billType != null) {
        whereParts.add('b.bill_type = ?');
        args.add(filter.billType);
      }
      if (filter.parentCategoryId != null) {
        whereParts.add('parent.id = ?');
        args.add(filter.parentCategoryId);
      }
      final rows = await db.rawQuery('''
        SELECT
          b.*,
          child.name AS child_category_name,
          parent.id AS parent_category_id,
          parent.name AS parent_category_name
        FROM bill b
        JOIN category child ON child.id = b.category_id
        JOIN category parent ON parent.id = child.parent_id
        ${whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}'}
        ORDER BY datetime(b.bill_time) DESC, b.id DESC
      ''', args);
      return rows.map(BillView.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Summary> getSummary({BillFilter filter = const BillFilter()}) async {
    final bills = await getBills(filter: filter);
    var income = 0.0;
    var expense = 0.0;
    for (final bill in bills) {
      if (bill.billType == incomeType) {
        income += bill.money;
      } else {
        expense += bill.money;
      }
    }
    return Summary(income: income, expense: expense);
  }

  Future<List<MonthlyTrend>> getMonthlyTrend() async {
    try {
      final db = await database;
      final rows = await db.rawQuery('''
        SELECT
          substr(bill_time, 1, 7) AS month,
          SUM(CASE WHEN bill_type = 1 THEN money ELSE 0 END) AS income,
          SUM(CASE WHEN bill_type = 2 THEN money ELSE 0 END) AS expense
        FROM bill
        GROUP BY substr(bill_time, 1, 7)
        ORDER BY month ASC
      ''');
      return rows.map((row) {
        return MonthlyTrend(
          month: row['month'] as String,
          income: (row['income'] as num?)?.toDouble() ?? 0,
          expense: (row['expense'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<CategoryExpenseStat>> getExpenseCategoryStats() async {
    try {
      final db = await database;
      final rows = await db.rawQuery('''
        SELECT parent.name AS category_name, SUM(b.money) AS amount
        FROM bill b
        JOIN category child ON child.id = b.category_id
        JOIN category parent ON parent.id = child.parent_id
        WHERE b.bill_type = 2
        GROUP BY parent.id, parent.name
        ORDER BY amount DESC
      ''');
      return rows.map((row) {
        return CategoryExpenseStat(
          categoryName: row['category_name'] as String,
          amount: (row['amount'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> clearBills() async {
    try {
      final db = await database;
      await db.delete('bill');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> replaceBills(List<Bill> bills) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('bill');
        for (final bill in bills) {
          await txn.insert('bill', bill.toMap(includeId: false));
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

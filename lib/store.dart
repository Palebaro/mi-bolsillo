import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'domain.dart';

class BudgetStore {
  BudgetStore(this.db);

  final Database db;

  static Future<BudgetStore> open({String? databasePath}) async {
    final db = await openDatabase(
      databasePath ?? path.join(await getDatabasesPath(), 'presupuesto.db'),
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE movements (
            id INTEGER PRIMARY KEY,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            currency TEXT NOT NULL,
            amount INTEGER NOT NULL,
            kind TEXT NOT NULL,
            date TEXT NOT NULL,
            rule_id INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE budgets (
            month TEXT NOT NULL,
            currency TEXT NOT NULL,
            category TEXT NOT NULL,
            amount INTEGER NOT NULL,
            PRIMARY KEY (month, currency, category)
          )
        ''');
        await db.execute('''
          CREATE TABLE recurring (
            id INTEGER PRIMARY KEY,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            currency TEXT NOT NULL,
            amount INTEGER NOT NULL,
            kind TEXT NOT NULL DEFAULT 'expense',
            day INTEGER NOT NULL,
            next_month TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE recurring ADD COLUMN kind TEXT NOT NULL DEFAULT 'expense'",
          );
        }
        if (oldVersion < 3) {
          for (final (oldCategory, newCategory) in [
            ('Vivienda', 'Arriendo'),
            ('Servicios', 'Servicios públicos'),
          ]) {
            for (final table in ['movements', 'recurring']) {
              await db.update(
                table,
                {'category': newCategory},
                where: 'category = ? AND kind = ?',
                whereArgs: [oldCategory, 'expense'],
              );
            }
            await db.update(
              'budgets',
              {'category': newCategory},
              where: 'category = ?',
              whereArgs: [oldCategory],
            );
          }
        }
      },
    );
    return BudgetStore(db);
  }

  Future<void> addMovement({
    required String description,
    required String category,
    required String currency,
    required int amount,
    required String kind,
    required DateTime date,
    required bool recurring,
  }) async {
    await db.transaction((txn) async {
      int? ruleId;
      if (recurring) {
        final next = DateTime(date.year, date.month + 1);
        ruleId = await txn.insert('recurring', {
          'description': description,
          'category': category,
          'currency': currency,
          'amount': amount,
          'kind': kind,
          'day': date.day,
          'next_month': monthKey(next),
        });
      }
      await txn.insert('movements', {
        'description': description,
        'category': category,
        'currency': currency,
        'amount': amount,
        'kind': kind,
        'date': dateKey(date),
        'rule_id': ruleId,
      });
    });
  }

  Future<void> generateDue(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    await db.transaction((txn) async {
      final rules = await txn.query('recurring');
      for (final rule in rules) {
        final parts = (rule['next_month'] as String).split('-');
        var month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        final day = rule['day'] as int;
        while (!monthlyDate(month, day).isAfter(today)) {
          await txn.insert('movements', {
            'description': rule['description'],
            'category': rule['category'],
            'currency': rule['currency'],
            'amount': rule['amount'],
            'kind': rule['kind'],
            'date': dateKey(monthlyDate(month, day)),
            'rule_id': rule['id'],
          });
          month = DateTime(month.year, month.month + 1);
        }
        await txn.update(
          'recurring',
          {'next_month': monthKey(month)},
          where: 'id = ?',
          whereArgs: [rule['id']],
        );
      }
    });
  }

  Future<List<Map<String, Object?>>> movements(String month, String currency) =>
      db.query(
        'movements',
        where: 'date LIKE ? AND currency = ?',
        whereArgs: ['$month-%', currency],
        orderBy: 'date DESC, id DESC',
      );

  Future<List<Map<String, Object?>>> allMovements() =>
      db.query('movements', orderBy: 'date DESC, id DESC');

  Future<List<Map<String, Object?>>> budgets(String month, String currency) =>
      db.query(
        'budgets',
        where: 'month = ? AND currency = ?',
        whereArgs: [month, currency],
      );

  Future<void> setBudget(
    String month,
    String currency,
    String category,
    int amount,
  ) async {
    await db.insert('budgets', {
      'month': month,
      'currency': currency,
      'category': category,
      'amount': amount,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBudget(
    String month,
    String currency,
    String category,
  ) async => db.delete(
    'budgets',
    where: 'month = ? AND currency = ? AND category = ?',
    whereArgs: [month, currency, category],
  );

  Future<void> deleteMovement(int id) async =>
      db.delete('movements', where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, Object?>>> rules() =>
      db.query('recurring', orderBy: 'description');

  Future<void> deleteRule(int id) async =>
      db.delete('recurring', where: 'id = ?', whereArgs: [id]);
}

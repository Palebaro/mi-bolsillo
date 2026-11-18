import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:presupuesto_personal/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'recurrencias son idempotentes, atómicas y conservan la moneda',
    () async {
      final store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
      addTearDown(() => store.db.close());
      await store.addMovement(
        description: 'Renta',
        category: 'Arriendo',
        currency: 'USD',
        amount: 12550,
        kind: 'expense',
        date: DateTime(2024, 1, 31),
        recurring: true,
      );
      await store.generateDue(DateTime(2024, 3, 30));
      await store.generateDue(DateTime(2024, 3, 30));
      expect(
        (await store.movements('2024-02', 'USD')).single['date'],
        '2024-02-29',
      );
      expect(
        (await store.movements('2024-02', 'USD')).single['kind'],
        'expense',
      );
      expect(await store.movements('2024-03', 'USD'), isEmpty);
      await store.generateDue(DateTime(2024, 3, 31));
      expect(
        (await store.movements('2024-03', 'USD')).single['date'],
        '2024-03-31',
      );
      expect(await store.movements('2024-02', 'COP'), isEmpty);
      final rule = (await store.rules()).single;
      await store.deleteRule(rule['id'] as int);
      await store.generateDue(DateTime(2024, 4, 30));
      expect(await store.movements('2024-04', 'USD'), isEmpty);
      expect(await store.movements('2024-02', 'USD'), hasLength(1));
    },
  );

  test('ingresos recurrentes conservan tipo y fecha sin duplicados', () async {
    final store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
    addTearDown(() => store.db.close());
    await store.addMovement(
      description: 'Salario',
      category: 'Ventas',
      currency: 'COP',
      amount: 300000,
      kind: 'income',
      date: DateTime(2024, 1, 31),
      recurring: true,
    );
    expect((await store.rules()).single['kind'], 'income');
    await store.generateDue(DateTime(2024, 3, 30));
    await store.generateDue(DateTime(2024, 3, 30));
    final february = (await store.movements('2024-02', 'COP')).single;
    expect(february['date'], '2024-02-29');
    expect(february['kind'], 'income');
    expect(february['amount'], 300000);
    expect(february['description'], 'Salario');
    expect(february['category'], 'Ventas');
    expect(await store.movements('2024-03', 'COP'), isEmpty);
    await store.generateDue(DateTime(2024, 3, 31));
    final march = (await store.movements('2024-03', 'COP')).single;
    expect(march['date'], '2024-03-31');
    expect(march['kind'], 'income');
    expect(await store.movements('2024-03', 'USD'), isEmpty);
    await store.deleteRule((await store.rules()).single['id'] as int);
    await store.generateDue(DateTime(2024, 4, 30));
    expect(await store.movements('2024-04', 'COP'), isEmpty);
    expect(await store.movements('2024-03', 'COP'), hasLength(1));
  });

  test('la migración conserva gastos recurrentes y datos existentes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'presupuesto_test_',
    );
    final dbPath = path.join(directory.path, 'presupuesto.db');
    final oldDb = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE movements (
            id INTEGER PRIMARY KEY, description TEXT NOT NULL,
            category TEXT NOT NULL, currency TEXT NOT NULL,
            amount INTEGER NOT NULL, kind TEXT NOT NULL,
            date TEXT NOT NULL, rule_id INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE budgets (
            month TEXT NOT NULL, currency TEXT NOT NULL, category TEXT NOT NULL,
            amount INTEGER NOT NULL, PRIMARY KEY (month, currency, category)
          )
        ''');
        await db.execute('''
          CREATE TABLE recurring (
            id INTEGER PRIMARY KEY, description TEXT NOT NULL,
            category TEXT NOT NULL, currency TEXT NOT NULL, amount INTEGER NOT NULL,
            day INTEGER NOT NULL, next_month TEXT NOT NULL
          )
        ''');
        await db.insert('recurring', {
          'id': 42,
          'description': 'Renta',
          'category': 'Vivienda',
          'currency': 'USD',
          'amount': 10000,
          'day': 31,
          'next_month': '2024-02',
        });
        await db.insert('movements', {
          'description': 'Renta',
          'category': 'Vivienda',
          'currency': 'USD',
          'amount': 10000,
          'kind': 'expense',
          'date': '2024-01-31',
          'rule_id': 42,
        });
        await db.insert('budgets', {
          'month': '2024-01',
          'currency': 'USD',
          'category': 'Vivienda',
          'amount': 20000,
        });
      },
    );
    await oldDb.close();
    final store = await BudgetStore.open(databasePath: dbPath);
    addTearDown(() async {
      await store.db.close();
      await directory.delete(recursive: true);
    });
    expect((await store.rules()).single['kind'], 'expense');
    expect((await store.rules()).single['category'], 'Arriendo');
    expect((await store.movements('2024-01', 'USD')).single['rule_id'], 42);
    expect(
      (await store.movements('2024-01', 'USD')).single['category'],
      'Arriendo',
    );
    expect((await store.budgets('2024-01', 'USD')).single['amount'], 20000);
    expect(
      (await store.budgets('2024-01', 'USD')).single['category'],
      'Arriendo',
    );
    await store.generateDue(DateTime(2024, 2, 29));
    final movement = (await store.movements('2024-02', 'USD')).single;
    expect(movement['kind'], 'expense');
    expect(movement['rule_id'], 42);
    expect(movement['category'], 'Arriendo');
    expect(movement['date'], '2024-02-29');
  });

  test(
    'migración desde versión 2 actualiza gastos y conserva ingresos',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'presupuesto_v2_',
      );
      final dbPath = path.join(directory.path, 'presupuesto.db');
      final oldDb = await openDatabase(
        dbPath,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE movements (
            id INTEGER PRIMARY KEY, description TEXT NOT NULL,
            category TEXT NOT NULL, currency TEXT NOT NULL,
            amount INTEGER NOT NULL, kind TEXT NOT NULL,
            date TEXT NOT NULL, rule_id INTEGER
          )
        ''');
          await db.execute('''
          CREATE TABLE budgets (
            month TEXT NOT NULL, currency TEXT NOT NULL, category TEXT NOT NULL,
            amount INTEGER NOT NULL, PRIMARY KEY (month, currency, category)
          )
        ''');
          await db.execute('''
          CREATE TABLE recurring (
            id INTEGER PRIMARY KEY, description TEXT NOT NULL,
            category TEXT NOT NULL, currency TEXT NOT NULL, amount INTEGER NOT NULL,
            kind TEXT NOT NULL DEFAULT 'expense', day INTEGER NOT NULL,
            next_month TEXT NOT NULL
          )
        ''');
          for (final (id, kind, category) in [
            (1, 'expense', 'Vivienda'),
            (2, 'expense', 'Servicios'),
            (3, 'income', 'Vivienda'),
            (4, 'income', 'Servicios'),
            (5, 'income', 'Arriendo'),
          ]) {
            await db.insert('recurring', {
              'id': id,
              'description': 'Regla $id',
              'category': category,
              'currency': 'COP',
              'amount': 100,
              'kind': kind,
              'day': 1,
              'next_month': '2024-02',
            });
            await db.insert('movements', {
              'description': 'Registro $id',
              'category': category,
              'currency': 'COP',
              'amount': 100,
              'kind': kind,
              'date': '2024-01-01',
              'rule_id': id,
            });
          }
          for (final category in ['Vivienda', 'Servicios']) {
            await db.insert('budgets', {
              'month': '2024-01',
              'currency': 'COP',
              'category': category,
              'amount': 1000,
            });
          }
        },
      );
      await oldDb.close();
      final store = await BudgetStore.open(databasePath: dbPath);
      addTearDown(() async {
        await store.db.close();
        await directory.delete(recursive: true);
      });
      final movements = await store.movements('2024-01', 'COP');
      final expected = {
        1: 'Arriendo',
        2: 'Servicios públicos',
        3: 'Vivienda',
        4: 'Servicios',
        5: 'Arriendo',
      };
      for (final movement in movements) {
        expect(movement['category'], expected[movement['rule_id']]);
      }
      for (final rule in await store.rules()) {
        expect(rule['category'], expected[rule['id']]);
      }
      expect(
        (await store.budgets('2024-01', 'COP')).map((b) => b['category']),
        unorderedEquals(['Arriendo', 'Servicios públicos']),
      );
      await store.generateDue(DateTime(2024, 2, 1));
      for (final movement in await store.movements('2024-02', 'COP')) {
        expect(movement['category'], expected[movement['rule_id']]);
      }
    },
  );

  test('presupuestos se guardan por mes, categoría y moneda', () async {
    final store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
    addTearDown(() => store.db.close());
    await store.setBudget('2026-01', 'USD', 'Ocio', 10000);
    await store.setBudget('2026-01', 'COP', 'Ocio', 250000);
    await store.setBudget('2026-02', 'USD', 'Ocio', 20000);
    await store.setBudget('2026-01', 'USD', 'Ocio', 11000);
    expect((await store.budgets('2026-01', 'USD')).single['amount'], 11000);
    expect((await store.budgets('2026-01', 'COP')).single['amount'], 250000);
    expect((await store.budgets('2026-02', 'USD')).single['amount'], 20000);
    await store.deleteBudget('2026-01', 'USD', 'Ocio');
    expect(await store.budgets('2026-01', 'USD'), isEmpty);
    expect(await store.budgets('2026-01', 'COP'), hasLength(1));
  });
}

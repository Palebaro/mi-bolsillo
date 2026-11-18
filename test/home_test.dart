import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:presupuesto_personal/domain.dart';
import 'package:presupuesto_personal/main.dart';
import 'package:presupuesto_personal/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('resumen muestra alerta y balance de la moneda seleccionada', (
    tester,
  ) async {
    late BudgetStore store;
    await tester.runAsync(() async {
      await initializeDateFormatting('es');
      store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
      final today = DateTime.now();
      await store.setBudget(monthKey(today), 'COP', 'Arriendo', 10000);
      await store.addMovement(
        description: 'Pago',
        category: 'Arriendo',
        currency: 'COP',
        amount: 8000,
        kind: 'expense',
        date: today,
        recurring: false,
      );
    });
    await tester.pumpWidget(BudgetApp(initialStore: store));
    for (
      var i = 0;
      i < 30 && find.text('Balance del mes').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Balance del mes'), findsOneWidget);
    expect(find.text('Mi Bolsillo'), findsOneWidget);
    expect(find.text('-COP 80.00'), findsOneWidget);
    expect(find.text('Cerca del límite: Arriendo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'los diálogos de movimientos y presupuestos cierran sin errores',
    (tester) async {
      late BudgetStore store;
      await tester.runAsync(() async {
        await initializeDateFormatting('es');
        store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
      });
      await tester.pumpWidget(BudgetApp(initialStore: store));
      for (
        var i = 0;
        i < 30 && find.text('Balance del mes').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Balance del mes'), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.tap(find.text('Movimiento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Compra');
      await tester.enterText(find.byType(TextFormField).at(1), '25');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Movimiento'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo movimiento'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Movimiento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Compra');
      await tester.enterText(find.byType(TextFormField).at(1), '25');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 30 && find.text('-COP 25.00').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('-COP 25.00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Movimientos'));
      await tester.pumpAndSettle();
      expect(find.text('Compra'), findsOneWidget);
      expect(find.text('-COP 25.00'), findsOneWidget);

      await tester.tap(find.text('Presupuestos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arriendo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '100');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Arriendo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '100');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 30 && find.text('COP 100.00').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('COP 100.00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Arriendo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar límite'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 30 && find.text('COP 100.00').evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('COP 100.00'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final movements = await store.movements(
          monthKey(DateTime.now()),
          'COP',
        );
        expect(movements, hasLength(1));
        expect(movements.single['description'], 'Compra');
        expect(movements.single['amount'], 2500);
        expect(await store.budgets(monthKey(DateTime.now()), 'COP'), isEmpty);
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('se puede registrar y detener un ingreso recurrente', (
    tester,
  ) async {
    late BudgetStore store;
    await tester.runAsync(() async {
      await initializeDateFormatting('es');
      store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
    });
    await tester.pumpWidget(BudgetApp(initialStore: store));
    for (
      var i = 0;
      i < 30 && find.text('Balance del mes').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Balance del mes'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Salario');
    await tester.enterText(find.byType(TextFormField).at(1), '1000');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingreso').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ventas').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Repetir cada mes'));
    await tester.tap(find.text('Repetir cada mes'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 30 && find.text('COP 1000.00').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('COP 1000.00'), findsOneWidget);
    await tester.tap(find.text('Recurrentes'));
    await tester.pumpAndSettle();
    expect(find.text('Salario'), findsOneWidget);
    expect(find.textContaining('Ingreso ·'), findsOneWidget);
    expect(find.textContaining('Ventas'), findsOneWidget);
    await tester.runAsync(() async {
      expect((await store.rules()).single['category'], 'Ventas');
    });
    await tester.tap(find.byTooltip('Detener recurrencia'));
    await tester.pumpAndSettle();
    expect(find.text('¿Detener este ingreso recurrente?'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 30 && find.text('Salario').evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Salario'), findsNothing);
    await tester.runAsync(() async {
      expect(await store.rules(), isEmpty);
      final movement = (await store.movements(
        monthKey(DateTime.now()),
        'COP',
      )).single;
      expect(movement['description'], 'Salario');
      expect(movement['kind'], 'income');
      expect(movement['category'], 'Ventas');
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('las categorías cambian según el tipo y conservan la selección', (
    tester,
  ) async {
    late BudgetStore store;
    await tester.runAsync(() async {
      await initializeDateFormatting('es');
      store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
    });
    await tester.pumpWidget(BudgetApp(initialStore: store));
    for (
      var i = 0;
      i < 30 && find.text('Balance del mes').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Balance del mes'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movimiento'));
    await tester.pumpAndSettle();
    final categoryField = find.byType(DropdownButtonFormField<String>).last;
    List<String?> choices() => tester
        .widget<DropdownButton<String>>(
          find.descendant(
            of: categoryField,
            matching: find.byType(DropdownButton<String>),
          ),
        )
        .items!
        .map((item) => item.value)
        .toList();
    expect(choices(), [
      'Arriendo',
      'Alimentación',
      'Transporte',
      'Servicios públicos',
      'Educación',
      'Servicios financieros',
      'Salud',
      'Ocio',
      'Otros',
    ]);
    await tester.tap(categoryField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transporte').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingreso').last);
    await tester.pumpAndSettle();
    expect(choices(), incomeCategories);
    expect(find.text('Salario'), findsOneWidget);
    await tester.tap(categoryField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arriendo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gasto').last);
    await tester.pumpAndSettle();
    expect(choices(), categories);
    expect(find.text('Transporte'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingreso').last);
    await tester.pumpAndSettle();
    expect(choices(), incomeCategories);
    expect(find.text('Arriendo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nuevas categorías sirven para gastos y presupuestos', (
    tester,
  ) async {
    late BudgetStore store;
    await tester.runAsync(() async {
      await initializeDateFormatting('es');
      store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
    });
    await tester.pumpWidget(BudgetApp(initialStore: store));
    for (
      var i = 0;
      i < 30 && find.text('Balance del mes').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Balance del mes'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Curso');
    await tester.enterText(find.byType(TextFormField).at(1), '80');
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Educación').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 30 && find.text('Educación').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Educación'), findsOneWidget);
    await tester.tap(find.text('Presupuestos'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Servicios financieros'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Servicios financieros'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '100');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 30 && find.text('COP 100.00').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('COP 100.00'), findsOneWidget);
    await tester.runAsync(() async {
      final movement = (await store.movements(
        monthKey(DateTime.now()),
        'COP',
      )).single;
      expect(movement['category'], 'Educación');
      final budget = (await store.budgets(
        monthKey(DateTime.now()),
        'COP',
      )).single;
      expect(budget['category'], 'Servicios financieros');
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'un ingreso recurrente generado aparece en el resumen y la lista',
    (tester) async {
      late BudgetStore store;
      await tester.runAsync(() async {
        await initializeDateFormatting('es');
        store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
        final now = DateTime.now();
        await store.addMovement(
          description: 'Salario mensual',
          category: 'Otros',
          currency: 'COP',
          amount: 125000,
          kind: 'income',
          date: DateTime(now.year, now.month - 1, 1),
          recurring: true,
        );
      });
      await tester.pumpWidget(BudgetApp(initialStore: store));
      for (
        var i = 0;
        i < 30 && find.text('COP 1250.00').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('COP 1250.00'), findsOneWidget);
      expect(find.text('Ingresos: COP 1250.00'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Movimientos'));
      await tester.pumpAndSettle();
      expect(find.text('Salario mensual'), findsOneWidget);
      expect(find.text('+COP 1250.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('el tema sigue el modo claro u oscuro del sistema', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BudgetStore store;
    await tester.runAsync(() async {
      await initializeDateFormatting('es');
      store = await BudgetStore.open(databasePath: inMemoryDatabasePath);
    });
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(BudgetApp(initialStore: store));
    for (
      var i = 0;
      i < 30 && find.text('Balance del mes').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Balance del mes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.text('Balance del mes'))).brightness,
      Brightness.light,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.text('Balance del mes'))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.text('Movimiento'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Nuevo movimiento'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No hay movimientos en este mes.'), findsOneWidget);
    await tester.tap(find.text('Presupuestos'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Arriendo'), findsOneWidget);
    await tester.tap(find.text('Recurrentes'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Marca un ingreso o gasto como recurrente al registrarlo. Se generará mensualmente al abrir la app.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

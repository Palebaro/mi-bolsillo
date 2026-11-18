import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'app_theme.dart';
import 'domain.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key, this.initialStore});

  final BudgetStore? initialStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mi Bolsillo',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    home: HomePage(initialStore: initialStore),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialStore});

  final BudgetStore? initialStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  BudgetStore? store;
  String currency = 'COP';
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, Object?>> movements = [];
  List<Map<String, Object?>> budgets = [];
  List<Map<String, Object?>> rules = [];
  String? error;
  bool busy = true;
  int tab = 0;
  int loadId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store?.db.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && store != null) _reload();
  }

  Future<void> _open() async {
    try {
      store = widget.initialStore ?? await BudgetStore.open();
      await _reload();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          busy = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    final request = ++loadId;
    if (mounted) setState(() => busy = true);
    try {
      final db = store!;
      await db.generateDue(DateTime.now());
      final key = monthKey(month);
      final code = currency;
      final data = await db.movements(key, code);
      final limits = await db.budgets(key, code);
      final recurring = await db.rules();
      if (!mounted ||
          request != loadId ||
          key != monthKey(month) ||
          code != currency) {
        return;
      }
      setState(() {
        movements = data;
        budgets = limits;
        rules = recurring;
        busy = false;
        error = null;
      });
    } catch (e) {
      if (mounted && request == loadId) {
        setState(() {
          error = '$e';
          busy = false;
        });
      }
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar la operación: $e')),
        );
      }
    }
  }

  int total(String kind, [String? category]) => movements
      .where(
        (m) =>
            m['kind'] == kind &&
            (category == null || m['category'] == category),
      )
      .fold(0, (sum, m) => sum + (m['amount'] as int));

  int limit(String category) => budgets
      .where((b) => b['category'] == category)
      .fold(0, (sum, b) => sum + (b['amount'] as int));

  Future<void> _export() => _action(() async {
    final rows = await store!.allMovements();
    final csv = StringBuffer('\uFEFF');
    csv.writeln('Fecha,Tipo,Descripción,Categoría,Moneda,Importe');
    for (final row in rows) {
      csv.writeln(
        [
          row['date'],
          row['kind'] == 'income' ? 'Ingreso' : 'Gasto',
          row['description'],
          row['category'],
          row['currency'],
          ((row['amount'] as int) / 100).toStringAsFixed(2),
        ].map(csvCell).join(','),
      );
    }
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(csv.toString())),
            mimeType: 'text/csv',
            name: 'movimientos.csv',
          ),
        ],
        fileNameOverrides: ['movimientos.csv'],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Bolsillo'),
        actions: [
          IconButton(
            onPressed: store == null || busy ? null : _export,
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exportar movimientos CSV',
          ),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No se pudieron cargar los datos: $error'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: store == null ? _open : _reload,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(
                            () => month = DateTime(month.year, month.month - 1),
                          );
                          _reload();
                        },
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            DateFormat.yMMMM('es').format(month),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(
                            () => month = DateTime(month.year, month.month + 1),
                          );
                          _reload();
                        },
                        icon: const Icon(Icons.chevron_right),
                      ),
                      DropdownButton<String>(
                        value: currency,
                        items: const [
                          DropdownMenuItem(value: 'COP', child: Text('COP')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => currency = value);
                            _reload();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (tab) {
                    0 => _summary(),
                    1 => _movements(),
                    2 => _budgets(),
                    _ => _recurring(),
                  },
                ),
              ],
            ),
      floatingActionButton: store == null || error != null || busy
          ? null
          : FloatingActionButton.extended(
              onPressed: _movementDialog,
              icon: const Icon(Icons.add),
              label: const Text('Movimiento'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Presupuestos',
          ),
          NavigationDestination(icon: Icon(Icons.repeat), label: 'Recurrentes'),
        ],
      ),
    );
  }

  Widget _summary() {
    final income = total('income');
    final expense = total('expense');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Balance del mes',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  money(income - expense, currency),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingresos: ${money(income, currency)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gastos: ${money(expense, currency)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Gastos por categoría',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (expense == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Aún no hay gastos en este mes.'),
          ),
        for (final category in categories)
          if (total('expense', category) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(category)),
                      Text(money(total('expense', category), currency)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: total('expense', category) / expense,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 16),
        for (final category in categories)
          if (budgetWarning(total('expense', category), limit(category)) !=
              BudgetWarning.none)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text(
                  budgetWarning(total('expense', category), limit(category)) ==
                          BudgetWarning.reached
                      ? 'Límite alcanzado: $category'
                      : 'Cerca del límite: $category',
                ),
                subtitle: Text(
                  '${money(total('expense', category), currency)} de ${money(limit(category), currency)}',
                ),
              ),
            ),
      ],
    );
  }

  Widget _movements() => movements.isEmpty
      ? const Center(child: Text('No hay movimientos en este mes.'))
      : ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: movements.length,
          itemBuilder: (context, index) {
            final item = movements[index];
            final income = item['kind'] == 'income';
            return ListTile(
              leading: CircleAvatar(
                child: Icon(income ? Icons.south_west : Icons.north_east),
              ),
              title: Text(item['description'] as String),
              subtitle: Text('${item['category']} · ${item['date']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${income ? '+' : '-'}${money(item['amount'] as int, currency)}',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar',
                    onPressed: () => _confirmDeleteMovement(item),
                  ),
                ],
              ),
            );
          },
        );

  Widget _budgets() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    children: [
      const Text(
        'Configura un límite mensual por categoría. Toca una categoría para modificarlo.',
      ),
      for (final category in categories)
        Card(
          child: ListTile(
            title: Text(category),
            subtitle: Text(
              'Gastado: ${money(total('expense', category), currency)}',
            ),
            trailing: Text(
              limit(category) == 0
                  ? 'Sin límite'
                  : money(limit(category), currency),
            ),
            onTap: () => _budgetDialog(category),
          ),
        ),
    ],
  );

  Widget _recurring() => rules.isEmpty
      ? const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Marca un ingreso o gasto como recurrente al registrarlo. Se generará mensualmente al abrir la app.',
            ),
          ),
        )
      : ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Los ingresos y gastos pendientes se registran al abrir o retomar la app.',
              ),
            ),
            for (final rule in rules)
              ListTile(
                title: Text(rule['description'] as String),
                subtitle: Text(
                  '${rule['kind'] == 'income' ? 'Ingreso' : 'Gasto'} · ${rule['category']} · día ${rule['day']} · ${money(rule['amount'] as int, rule['currency'] as String)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: 'Detener recurrencia',
                  onPressed: () => _confirmDeleteRule(rule),
                ),
              ),
          ],
        );

  Future<void> _confirmDeleteMovement(Map<String, Object?> item) async {
    final confirm = await _confirm(
      '¿Eliminar este movimiento?',
      'Si es recurrente, esto no detiene los futuros movimientos.',
    );
    if (confirm) await _action(() => store!.deleteMovement(item['id'] as int));
  }

  Future<void> _confirmDeleteRule(Map<String, Object?> rule) async {
    final confirm = await _confirm(
      '¿Detener este ${rule['kind'] == 'income' ? 'ingreso' : 'gasto'} recurrente?',
      'Los movimientos ya registrados se conservarán.',
    );
    if (confirm) await _action(() => store!.deleteRule(rule['id'] as int));
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _budgetDialog(String category) async {
    final controller = TextEditingController(
      text: limit(category) == 0
          ? ''
          : (limit(category) / 100).toStringAsFixed(2),
    );
    final form = GlobalKey<FormState>();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _DialogControllers(
        controllers: [controller],
        child: AlertDialog(
          title: Text('Presupuesto: $category'),
          content: Form(
            key: form,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Límite en $currency',
                hintText: 'Ej. 250.00',
              ),
              validator: (value) => parseMoney(value ?? '') == null
                  ? 'Ingresa un importe mayor que cero (máximo 2 decimales).'
                  : null,
            ),
          ),
          actions: [
            if (limit(category) > 0)
              TextButton(
                onPressed: () => Navigator.pop(context, 0),
                child: const Text('Quitar límite'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, parseMoney(controller.text));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result == 0) {
      await _action(
        () => store!.deleteBudget(monthKey(month), currency, category),
      );
    } else if (result != null) {
      await _action(
        () => store!.setBudget(monthKey(month), currency, category, result),
      );
    }
  }

  Future<void> _movementDialog() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final form = GlobalKey<FormState>();
    var expenseCategory = categories.first;
    var incomeCategory = incomeCategories.first;
    var kind = 'expense';
    var recurring = false;
    var date = DateTime.now();
    final selectedCurrency = currency;
    final result = await showDialog<({String description, int amount})>(
      context: context,
      builder: (context) => _DialogControllers(
        controllers: [description, amount],
        child: StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Nuevo movimiento'),
            content: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: description,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Ingresa una descripción.'
                          : null,
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Importe en $selectedCurrency',
                      ),
                      validator: (value) => parseMoney(value ?? '') == null
                          ? 'Ingresa un importe mayor que cero (máximo 2 decimales).'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(
                          value: 'expense',
                          child: Text('Gasto'),
                        ),
                        DropdownMenuItem(
                          value: 'income',
                          child: Text('Ingreso'),
                        ),
                      ],
                      onChanged: (value) => update(() => kind = value!),
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(kind),
                      isExpanded: true,
                      initialValue: kind == 'income'
                          ? incomeCategory
                          : expenseCategory,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [
                        for (final value
                            in kind == 'income' ? incomeCategories : categories)
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) => update(() {
                        if (kind == 'income') {
                          incomeCategory = value!;
                        } else {
                          expenseCategory = value!;
                        }
                      }),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fecha'),
                      subtitle: Text(dateKey(date)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (selected != null) update(() => date = selected);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repetir cada mes'),
                      subtitle: const Text(
                        'Se generará al abrir la aplicación',
                      ),
                      value: recurring,
                      onChanged: (value) => update(() => recurring = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(context, (
                      description: description.text.trim(),
                      amount: parseMoney(amount.text)!,
                    ));
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      await _action(
        () => store!.addMovement(
          description: result.description,
          category: kind == 'income' ? incomeCategory : expenseCategory,
          currency: selectedCurrency,
          amount: result.amount,
          kind: kind,
          date: date,
          recurring: recurring,
        ),
      );
    }
  }
}

class _DialogControllers extends StatefulWidget {
  const _DialogControllers({required this.controllers, required this.child});

  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<_DialogControllers> createState() => _DialogControllersState();
}

class _DialogControllersState extends State<_DialogControllers> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

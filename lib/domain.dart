import 'dart:math' as math;

const categories = [
  'Arriendo',
  'Alimentación',
  'Transporte',
  'Servicios públicos',
  'Educación',
  'Servicios financieros',
  'Salud',
  'Ocio',
  'Otros',
];

const incomeCategories = [
  'Salario',
  'Ventas',
  'Arriendo',
  'Trabajo independiente',
  'Inversiones',
  'Regalos',
  'Otros',
];

enum BudgetWarning { none, near, reached }

BudgetWarning budgetWarning(int spending, int limit) {
  if (limit <= 0) return BudgetWarning.none;
  if (spending >= limit) return BudgetWarning.reached;
  return spending * 100 >= limit * 80 ? BudgetWarning.near : BudgetWarning.none;
}

String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

String dateKey(DateTime date) =>
    '${monthKey(date)}-${date.day.toString().padLeft(2, '0')}';

DateTime monthlyDate(DateTime month, int day) {
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, math.min(day, lastDay));
}

int? parseMoney(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 999999999999) return null;
  final cents = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  final amount = whole * 100 + cents;
  return amount > 0 ? amount : null;
}

String money(int cents, String currency) {
  final sign = cents < 0 ? '-' : '';
  final value = cents.abs();
  return '$sign$currency ${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
}

String csvCell(Object? value) {
  var text = '$value';
  if (RegExp(r'^[\s]*[=+\-@]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

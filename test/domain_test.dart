import 'package:flutter_test/flutter_test.dart';
import 'package:presupuesto_personal/domain.dart';

void main() {
  test('importes se convierten a centavos sin redondeo', () {
    expect(parseMoney('123,4'), 12340);
    expect(parseMoney('1.01'), 101);
    expect(parseMoney('0.01'), 1);
    expect(parseMoney('0'), isNull);
    expect(parseMoney('-1'), isNull);
    expect(parseMoney('1.001'), isNull);
    expect(parseMoney('1e3'), isNull);
    expect(money(-101, 'USD'), '-USD 1.01');
  });

  test('recurrencia respeta el día original y el último día del mes', () {
    expect(dateKey(monthlyDate(DateTime(2024, 2), 31)), '2024-02-29');
    expect(dateKey(monthlyDate(DateTime(2025, 2), 31)), '2025-02-28');
    expect(dateKey(monthlyDate(DateTime(2025, 3), 31)), '2025-03-31');
  });

  test('alertas se activan al 80% y al 100%', () {
    expect(budgetWarning(0, 0), BudgetWarning.none);
    expect(budgetWarning(7999, 10000), BudgetWarning.none);
    expect(budgetWarning(8000, 10000), BudgetWarning.near);
    expect(budgetWarning(9999, 10000), BudgetWarning.near);
    expect(budgetWarning(10000, 10000), BudgetWarning.reached);
    expect(budgetWarning(11000, 10000), BudgetWarning.reached);
  });

  test('CSV escapa contenido y neutraliza fórmulas', () {
    expect(csvCell('Hola, "mundo"'), '"Hola, ""mundo"""');
    expect(csvCell(' =1+1'), '"\' =1+1"');
  });
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/app_state_provider.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/constants.dart';

class BudgetAlertBanner extends StatelessWidget {
  const BudgetAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final budgets = context.watch<BudgetProvider>();
    final finance = context.watch<FinanceProvider>();
    final appState = context.watch<AppStateProvider>();

    final alertBudgets = budgets.getAlertBudgets(finance.transactions);
    if (alertBudgets.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: alertBudgets.map((b) {
        final spent = budgets.getSpentFor(b.category, finance.transactions);
        final percent = (spent / b.monthlyLimit * 100).toInt();
        final isExceeded = spent >= b.monthlyLimit;
        final color = isExceeded ? AppConstants.accentRed : AppConstants.accentAmber;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(
                isExceeded ? Icons.error_rounded : Icons.warning_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isExceeded
                          ? 'Teto Estourado: ${b.category} ($percent%)'
                          : 'Atenção ao Teto: ${b.category} ($percent%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gasto de ${CurrencyFormatter.format(spent)} do limite mensal de ${CurrencyFormatter.format(b.monthlyLimit)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  // Direct to budgets screen or tab
                  appState.setTab(5); // Budgets tab
                },
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: const Text('Ver Tetos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

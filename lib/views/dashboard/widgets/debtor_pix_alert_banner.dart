import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/notification_event_model.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/constants.dart';

class DebtorPixAlertBanner extends StatelessWidget {
  const DebtorPixAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final debtProvider = context.watch<DebtProvider>();
    final financeProvider = context.read<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingDebtorPix = notifProvider.notifications.where(
      (n) => n.isDebtAbatementCandidate && n.status == NotificationStatus.pending,
    ).toList();

    if (pendingDebtorPix.isEmpty) return const SizedBox.shrink();

    final notif = pendingDebtorPix.first;
    final personName = notif.matchedPersonName ?? 'Devedor';
    final amount = notif.parsedAmount ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.accentGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.accentGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.accentGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pix_rounded, color: AppConstants.accentGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          'Pix de $personName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.accentGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            CurrencyFormatter.format(amount),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Identificamos uma transferência de $personName. Como você deseja registrar?',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Abater Mês'),
                onPressed: () {
                  notifProvider.abateFromNotification(
                    event: notif,
                    personName: personName,
                    debtProvider: debtProvider,
                    financeProvider: financeProvider,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pix de ${CurrencyFormatter.format(amount)} abatido das contas de $personName!'),
                      backgroundColor: AppConstants.accentGreen,
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : AppConstants.primaryColor,
                  side: BorderSide(color: AppConstants.primaryColor.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                label: const Text('Receita Comum'),
                onPressed: () {
                  notifProvider.approveAsIncome(notif, financeProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pix de ${CurrencyFormatter.format(amount)} registrado como receita comum!'),
                    ),
                  );
                },
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Ignorar'),
                onPressed: () {
                  notifProvider.ignoreNotification(notif);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

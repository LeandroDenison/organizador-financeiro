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
        color: AppConstants.accentGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.accentGreen.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppConstants.accentGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pix_rounded, color: AppConstants.accentGreen, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Pix de $personName Identificado!',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
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
                const SizedBox(height: 2),
                Text(
                  'Deseja abater esse valor das contas em aberto de $personName?',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              notifProvider.abateFromNotification(
                event: notif,
                personName: personName,
                debtProvider: debtProvider,
                financeProvider: financeProvider,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pix de ${CurrencyFormatter.format(amount)} abatido com sucesso das contas de $personName!'),
                  backgroundColor: AppConstants.accentGreen,
                ),
              );
            },
            child: const Text('Abater Contas'),
          ),
        ],
      ),
    );
  }
}

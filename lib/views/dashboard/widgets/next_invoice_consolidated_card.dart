import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/payable_provider.dart';
import '../../../models/card_cycle_model.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/constants.dart';
import '../../invoice/unified_invoice_view.dart';

class NextInvoiceConsolidatedCard extends StatelessWidget {
  const NextInvoiceConsolidatedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final payables = context.watch<PayableProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    final invoice = payables.nextInvoice;
    if (invoice == null) return const SizedBox.shrink();

    const monthsPt = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    final targetDue = invoice.targetDueDate;
    final dueMonthName = monthsPt[(targetDue.month - 1).clamp(0, 11)];
    final isCurrentDec = targetDue.year == 2026 && targetDue.month == 12;
    final isFuture = targetDue.isAfter(DateTime(2026, 12, 31));
    final subtitleText = isCurrentDec
        ? 'Gastos acumulando para $dueMonthName/${targetDue.year}'
        : (isFuture
            ? 'Parcelas projetadas para $dueMonthName/${targetDue.year}'
            : 'Fatura fechada de $dueMonthName/${targetDue.year}');
    final badgeText = isCurrentDec ? 'Fatura Aberta' : (isFuture ? 'Fatura Futura' : 'Fatura Paga');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UnifiedInvoiceView()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.oledCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppConstants.primaryColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppConstants.primaryColor.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.credit_score_rounded,
                          color: AppConstants.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Próxima Fatura Consolidada',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              subtitleText,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total Amount Display
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  CurrencyFormatter.format(invoice.totalAmount),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '(${invoice.totalTransactionsCount} compras no novo ciclo)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Split: Sua Parte vs Devedores
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_rounded, size: 14, color: AppConstants.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Sua parte: ${CurrencyFormatter.format(invoice.myShareAmount)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppConstants.accentIndigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.handshake_rounded, size: 14, color: AppConstants.accentIndigo),
                    const SizedBox(width: 6),
                    Text(
                      'Devedores: ${CurrencyFormatter.format(invoice.debtorShareAmount)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.accentIndigo,
                      ),
                    ),
                  ],
                ),
              ),
              if (invoice.projectedSubscriptionsTotal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppConstants.accentAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.autorenew_rounded, size: 14, color: AppConstants.accentAmber),
                      const SizedBox(width: 6),
                      Text(
                        '+ ${CurrencyFormatter.format(invoice.projectedSubscriptionsTotal)} previstos',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.accentAmber,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // 4 Cards Grid 2x2 (2 por linha)
          Column(
            children: [
              for (int i = 0; i < invoice.cardInvoices.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(bottom: i + 2 < invoice.cardInvoices.length ? 8.0 : 0.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildCardItem(isDark, invoice.cardInvoices[i]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: (i + 1 < invoice.cardInvoices.length)
                            ? _buildCardItem(isDark, invoice.cardInvoices[i + 1])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Action link to view payables in open mode
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppConstants.primaryColor,
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text(
                'Abrir Fatura Unificada (Estilo Nubank)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnifiedInvoiceView()),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCardItem(bool isDark, CardOpenInvoice card) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.config.color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: card.config.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card.config.cardName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(card.totalAmount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: card.totalAmount > 0
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? AppConstants.oledSubtext : Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fecha dia ${card.config.closingDay} • Vence ${card.config.dueDay}',
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../providers/payable_provider.dart';
import '../../../providers/bank_loan_provider.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/constants.dart';

class ProjectedBalanceCard extends StatefulWidget {
  const ProjectedBalanceCard({super.key});

  @override
  State<ProjectedBalanceCard> createState() => _ProjectedBalanceCardState();
}

class _ProjectedBalanceCardState extends State<ProjectedBalanceCard> {
  bool _onlyMyBills = true; // Padrão: Previsão real considerando apenas as minhas contas

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final debts = context.watch<DebtProvider>();
    final subscriptions = context.watch<SubscriptionProvider>();
    final payables = context.watch<PayableProvider>();
    final loans = context.watch<BankLoanProvider>();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    // Saldo real consolidado dos 3 bancos pelo Open Finance (dinheiro disponível agora)
    final openFinanceTotal = finance.openFinanceCashBalance;
    final currentCashBalance = openFinanceTotal;

    // Parcelas de devedores que ainda NÃO foram pagas neste mês (aba de devedores)
    final selectedMonth = finance.selectedMonth;
    final pendingDebtorReceivables = debts.totalOwedThisMonth(selectedMonth);

    // Assinaturas que ainda faltam cobrar neste mês
    final unbilledSubs = subscriptions.activeSubscriptions.where((sub) {
      final alreadyInTransactions = finance.scopedTransactions.any((tx) =>
          (tx.amount - sub.amount).abs() < 0.05 &&
          (tx.title.toLowerCase() == sub.sourceTransactionTitle?.toLowerCase() ||
              tx.title.toLowerCase() == sub.name.toLowerCase()));
      return !alreadyInTransactions;
    }).fold(0.0, (sum, s) => sum + (_onlyMyBills ? s.effectiveMyCost : s.amount));

    // Identificação do Salário do Usuário (transação de salário no mês ou fallback do valor real conhecido)
    final salaryTxs = finance.scopedTransactions.where((t) =>
        t.type == TransactionType.income &&
        (t.category.toLowerCase().contains('salário') ||
            t.title.toLowerCase().contains('salário') ||
            t.title.toLowerCase().contains('salarios') ||
            t.title.toLowerCase().contains('pagto'))).toList();
    final detectedSalary = salaryTxs.isNotEmpty
        ? salaryTxs.fold(0.0, (s, t) => s + t.amount)
        : (finance.totalIncome > 0 ? finance.totalIncome : 2995.34);

    // Contas da Próxima Fatura Consolidada (Nubank, Itaú Click, Samsung Itaú, Mercado Pago)
    final nextInv = payables.nextInvoice;
    final double cardBillsMyShare = (nextInv != null && nextInv.totalAmount > 0)
        ? nextInv.myShareAmount
        : finance.myNetExpense;
    final double cardBillsTotal = (nextInv != null && nextInv.totalAmount > 0)
        ? nextInv.totalAmount
        : finance.totalExpense;
    final double cardBillsDebtorShare = nextInv != null
        ? nextInv.debtorShareAmount
        : finance.thirdPartyExpense;

    final double unbilledSubsMyShare = nextInv != null
        ? nextInv.cardInvoices.fold(
            0.0,
            (s, c) => s + c.projectedSubscriptions.fold(0.0, (ss, sub) => ss + sub.effectiveMyCost),
          )
        : unbilledSubs;
    final double unbilledSubsTotal = nextInv != null
        ? nextInv.projectedSubscriptionsTotal
        : unbilledSubs;

    final loansTotal = loans.activeLoans.fold(0.0, (s, l) => s + l.installmentAmount);
    final fixedBoletosOutsideCard = payables.nonCardFixedBillsTotal;
    final fixedOutsideCardTotal = loansTotal + fixedBoletosOutsideCard;

    // Minhas Contas: Meu gasto pessoal com cartões + assinaturas a cair + boletos fixos/empréstimos fora do cartão
    final double myPersonalBills = cardBillsMyShare + unbilledSubsMyShare + fixedOutsideCardTotal;

    // Total Bruto de Contas a Pagar (se eu tivesse que bancar a fatura inteira sozinho sem devedores)
    final double allBillsTotal = cardBillsTotal + unbilledSubsTotal + fixedOutsideCardTotal;

    // Contas que os devedores têm que pagar nas faturas abertas
    final double debtorReceivables = cardBillsDebtorShare > 0
        ? cardBillsDebtorShare
        : pendingDebtorReceivables;

    // 1. Sobra Real Livre (Descontando apenas a minha parte): Salário - Minhas Contas
    final double salarySurplus = detectedSalary - myPersonalBills;

    // 2. Cenário de Alerta "Se Devedores Atrasarem" (Salário - Fatura Inteira e todas as contas)
    final double worstCaseWithoutDebtors = detectedSalary - allBillsTotal;

    // Saldo projetado conforme o modo selecionado
    final double projectedBalance = _onlyMyBills ? salarySurplus : worstCaseWithoutDebtors;

    final isPositive = projectedBalance >= 0;
    final isTight = isPositive && projectedBalance < 300;

    // Cálculo do teto diário disponível até o fim do mês
    final now = DateTime.now();
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final remainingDays = (selectedMonth.year == now.year && selectedMonth.month == now.month)
        ? (daysInMonth - now.day + 1).clamp(1, 31)
        : daysInMonth;
    final dailyBudget = projectedBalance > 0 ? (projectedBalance / remainingDays) : 0.0;

    final statusColor = isTight
        ? AppConstants.accentAmber
        : (isPositive ? AppConstants.accentGreen : AppConstants.accentRed);

    final nubankBal = finance.getBankBalance('Nubank');
    final itauBal = finance.getBankBalance('Itaú');
    final mpBal = finance.getBankBalance('Mercado Pago');

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Mode Switcher & Status Badge
          if (isMobile) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _onlyMyBills ? Icons.savings_rounded : Icons.auto_graph_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _onlyMyBills
                            ? 'Previsão do Salário'
                            : 'Previsão Completa (Com Devedores)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _onlyMyBills
                            ? 'Apenas suas contas do mês'
                            : 'Fluxo mensal com recebimento de devedores',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppConstants.oledSurface : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppConstants.oledBorder : Colors.grey.shade300,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _onlyMyBills = true),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _onlyMyBills ? AppConstants.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 13,
                              color: _onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Apenas Minhas Contas',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _onlyMyBills = false),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: !_onlyMyBills ? AppConstants.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_rounded,
                              size: 13,
                              color: !_onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Se Atrasarem',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: !_onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _onlyMyBills ? Icons.savings_rounded : Icons.auto_graph_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _onlyMyBills
                              ? 'Previsão do Salário (Apenas Minhas Contas)'
                              : 'Previsão Completa (Com Devedores)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          _onlyMyBills
                              ? 'Sobra real do seu bolso sem depender de terceiros'
                              : 'Fluxo mensal: Receitas - Despesas + Devedores deste mês - Assinaturas',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Segmented Button Toggle
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppConstants.oledSurface : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppConstants.oledBorder : Colors.grey.shade300,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _onlyMyBills = true),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _onlyMyBills ? AppConstants.primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 13,
                                color: _onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Apenas Minhas Contas',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _onlyMyBills = false),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: !_onlyMyBills ? AppConstants.primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.group_rounded,
                                size: 13,
                                color: !_onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Se Devedores Atrasarem',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: !_onlyMyBills ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          // Main Projected Value
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _onlyMyBills ? 'Quanto ainda posso gastar: ' : 'Se devedores atrasarem: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(projectedBalance),
                      style: TextStyle(
                        fontSize: isMobile ? 22 : 26,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isTight ? 'Margem Apertada' : (isPositive ? 'Positivo' : 'Risco Negativo'),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              _onlyMyBills
                  ? 'Salário (${CurrencyFormatter.format(detectedSalary)}) - Todas as Minhas Contas (${CurrencyFormatter.format(myPersonalBills)})'
                  : 'Cenário de Alerta: Salário (${CurrencyFormatter.format(detectedSalary)}) - Fatura Inteira e Contas (${CurrencyFormatter.format(allBillsTotal)})',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Open Finance Multi-Bank Live Balance Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppConstants.oledSurface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hub_rounded, size: 14, color: AppConstants.accentCyan),
                        const SizedBox(width: 6),
                        Text(
                          isMobile ? 'Saldo Open Finance:' : 'Saldo Consolidado (3 Bancos Open Finance):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          CurrencyFormatter.format(currentCashBalance),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.accentGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        finance.isSyncingBalances
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : InkWell(
                                onTap: () => finance.refreshBankBalances(),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.sync_rounded, size: 15, color: Colors.grey),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildBankChip(
                      name: 'Nubank',
                      amount: nubankBal,
                      color: AppConstants.nubankPurple,
                      isDark: isDark,
                    ),
                    _buildBankChip(
                      name: 'Itaú',
                      amount: itauBal,
                      color: AppConstants.itauOrange,
                      isDark: isDark,
                    ),
                    _buildBankChip(
                      name: 'Mercado Pago',
                      amount: mpBal,
                      color: AppConstants.mercadoPagoBlue,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Funil Anti-Sufoco (Conta de Padaria passo a passo)
          Column(
            children: [
              _buildBreakdownTile(
                label: '1. Meu Salário no Mês',
                amount: detectedSalary,
                icon: Icons.account_balance_wallet_rounded,
                color: AppConstants.accentGreen,
                prefix: '+ ',
              ),
              const SizedBox(height: 6),
              _buildBreakdownTile(
                label: _onlyMyBills
                    ? '2. Minha Parte nas Faturas (Cartões)'
                    : '2. Faturas Totais (Incluindo Devedores)',
                amount: _onlyMyBills ? cardBillsMyShare : cardBillsTotal,
                icon: Icons.credit_card_rounded,
                color: AppConstants.accentRed,
                prefix: '- ',
              ),
              if ((_onlyMyBills ? unbilledSubsMyShare : unbilledSubsTotal) > 0) ...[
                const SizedBox(height: 6),
                _buildBreakdownTile(
                  label: '3. Assinaturas que ainda vão cair',
                  amount: _onlyMyBills ? unbilledSubsMyShare : unbilledSubsTotal,
                  icon: Icons.autorenew_rounded,
                  color: AppConstants.accentAmber,
                  prefix: '- ',
                ),
              ],
              if (fixedOutsideCardTotal > 0) ...[
                const SizedBox(height: 6),
                _buildBreakdownTile(
                  label: '4. Boletos Fixos / Faculdade (Fora do Cartão)',
                  amount: fixedOutsideCardTotal,
                  icon: Icons.receipt_long_rounded,
                  color: AppConstants.accentRed,
                  prefix: '- ',
                ),
              ],
              if (debtorReceivables > 0) ...[
                const SizedBox(height: 6),
                _buildBreakdownTile(
                  label: _onlyMyBills
                      ? 'Parte dos Devedores (Já descontada acima)'
                      : 'A Receber dos Devedores (Em aberto)',
                  amount: debtorReceivables,
                  icon: Icons.handshake_rounded,
                  color: AppConstants.accentIndigo,
                  prefix: '',
                ),
              ],
            ],
          ),
          // Daily Allowance Box
          if (projectedBalance > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppConstants.oledSurface : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppConstants.accentGreen.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppConstants.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppConstants.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quanto posso gastar por dia:',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              '${CurrencyFormatter.format(dailyBudget)} / dia',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.accentGreen,
                              ),
                            ),
                            Text(
                              '($remainingDays dias restantes)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankChip({
    required String name,
    required double amount,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$name: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownTile({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    required String prefix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$prefix${CurrencyFormatter.format(amount)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

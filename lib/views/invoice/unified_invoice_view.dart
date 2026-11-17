import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/card_cycle_model.dart';
import '../../models/transaction_model.dart';
import '../../models/subscription_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/payable_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/bank_loan_provider.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import '../debts/widgets/whatsapp_reminder_dialog.dart';
import 'widgets/invoice_transaction_bottom_sheet.dart';

class UnifiedInvoiceView extends StatefulWidget {
  const UnifiedInvoiceView({super.key});

  @override
  State<UnifiedInvoiceView> createState() => _UnifiedInvoiceViewState();
}

class _UnifiedInvoiceViewState extends State<UnifiedInvoiceView> {
  // Offset relativo a Dezembro de 2026 (0 = Dezembro/2026 Aberta, -1 = Novembro/2026 Paga, 1 = Janeiro/2027 Futura)
  int _selectedMonthOffset = 0;
  String _selectedCardId = 'all'; // 'all', 'nubank', 'itau_click', 'itau_samsung', 'mercado_pago'
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _monthScrollController = ScrollController();

  final List<int> _availableOffsets = [-3, -2, -1, 0, 1, 2, 3];

  DateTime _getTargetMonth(int offset) {
    final base = DateTime(2026, 12, 1);
    return DateTime(base.year, base.month + offset, 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _monthScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finance = context.watch<FinanceProvider>();
    final debts = context.watch<DebtProvider>();
    final subs = context.watch<SubscriptionProvider>();
    final payables = context.watch<PayableProvider>();
    final loans = context.watch<BankLoanProvider>();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    final targetMonth = _getTargetMonth(_selectedMonthOffset);
    final isCurrentOpenMonth = _selectedMonthOffset == 0;
    final isPastMonth = _selectedMonthOffset < 0;
    final isFutureMonth = _selectedMonthOffset > 0;

    // 1. GERAÇÃO DOS DADOS DOS 4 CARTÕES PARA O MÊS SELECIONADO
    final List<CardOpenInvoice> cardInvoices = [];

    for (final cardConfig in CardConfig.defaultCards) {
      final targetDue = DateTime(targetMonth.year, targetMonth.month, cardConfig.dueDay);
      final cycleEnd = DateTime(targetMonth.year, targetMonth.month, cardConfig.closingDay, 23, 59, 59);
      final cycleStart = DateTime(targetMonth.year, targetMonth.month - 1, cardConfig.closingDay, 23, 59, 59);

      List<TransactionModel> cardTxs = [];
      List<SubscriptionModel> cardSubs = [];

      if (isCurrentOpenMonth) {
        // Fatura Aberta de Dezembro (usar dados apurados do PayableProvider)
        final inv = payables.nextInvoice?.cardInvoices.firstWhere(
          (c) => c.config.id == cardConfig.id,
          orElse: () => CardOpenInvoice(
            config: cardConfig,
            targetDueDate: targetDue,
            cycleStartDate: cycleStart,
            cycleEndDate: cycleEnd,
            transactions: [],
          ),
        );
        cardTxs = inv?.transactions ?? [];
        cardSubs = inv?.projectedSubscriptions ?? [];
      } else if (isPastMonth) {
        // Fatura Passada (Novembro, Outubro...): busca transações do ciclo correspondente
        final rawPast = finance.transactions.where((tx) {
          if (!FinanceProvider.isCreditCardTransaction(tx)) return false;

          bool matchesCard = false;
          final txBank = tx.bank?.toLowerCase() ?? '';
          final title = tx.title.toLowerCase();
          if (cardConfig.id == 'nubank') {
            matchesCard = txBank.contains('nubank');
          } else if (cardConfig.id == 'itau_click') {
            matchesCard = (txBank.contains('itau') || txBank.contains('itaú')) &&
                (title.contains('click') || !title.contains('samsung'));
          } else if (cardConfig.id == 'itau_samsung') {
            matchesCard = (txBank.contains('itau') || txBank.contains('itaú')) && title.contains('samsung');
          } else if (cardConfig.id == 'mercado_pago') {
            matchesCard = txBank.contains('mercado pago');
          }
          if (!matchesCard) return false;

          final isOnClosingDay = tx.date.year == cycleEnd.year &&
              tx.date.month == cycleEnd.month &&
              tx.date.day == cycleEnd.day;
          if (isOnClosingDay && tx.source != TransactionSource.pdf) {
            return false; // Pertence ao ciclo aberto seguinte
          }

          return tx.date.isAfter(cycleStart) && !tx.date.isAfter(cycleEnd);
        }).toList();

        cardTxs = rawPast.map((tx) {
          final matchedPerson = debts.matchDebtorForPurchase(tx);
          return (matchedPerson != null && tx.personName != matchedPerson)
              ? tx.copyWith(personName: matchedPerson)
              : tx;
        }).toList();
      } else {
        // Faturas Futuras (Janeiro 2027, Fevereiro 2027...): projeta compras parceladas da fatura aberta atual
        final futureOffset = _selectedMonthOffset;
        final currentOpenInv = payables.nextInvoice?.cardInvoices.firstWhere(
          (c) => c.config.id == cardConfig.id,
          orElse: () => CardOpenInvoice(
            config: cardConfig,
            targetDueDate: targetDue,
            cycleStartDate: cycleStart,
            cycleEndDate: cycleEnd,
            transactions: [],
          ),
        );

        List<TransactionModel> baseTransactions = currentOpenInv?.transactions ?? [];
        if (baseTransactions.isEmpty) {
          // Fallback seguro: ciclo aberto atual (Novembro -> Dezembro)
          final now = DateTime(2026, 11, 16);
          final defCycleEnd = DateTime(now.year, now.month + 1, cardConfig.closingDay, 23, 59, 59);
          final defCycleStart = DateTime(now.year, now.month, cardConfig.closingDay);
          baseTransactions = finance.transactions.where((tx) {
            if (!FinanceProvider.isCreditCardTransaction(tx)) return false;
            final txBank = tx.bank?.toLowerCase() ?? '';
            final title = tx.title.toLowerCase();
            bool matches = false;
            if (cardConfig.id == 'nubank') matches = txBank.contains('nubank');
            if (cardConfig.id == 'itau_click') matches = (txBank.contains('itau') || txBank.contains('itaú')) && !title.contains('samsung');
            if (cardConfig.id == 'itau_samsung') matches = (txBank.contains('itau') || txBank.contains('itaú')) && title.contains('samsung');
            if (cardConfig.id == 'mercado_pago') matches = txBank.contains('mercado pago');
            if (!matches) return false;
            return !tx.date.isBefore(defCycleStart) && !tx.date.isAfter(defCycleEnd);
          }).toList();
        }

        for (final tx in baseTransactions) {
          if (!FinanceProvider.isCreditCardTransaction(tx)) continue;

          // Extrai referência de parcelamento válida (ex: 1/4, 2/6, 13/18)
          String? instStr = tx.installmentRef;
          if (instStr == null) {
            final match = RegExp(r'(?:parcela|parc\.?)\s*(\d+)\s*/\s*(\d+)', caseSensitive: false).firstMatch(tx.title);
            if (match != null) {
              instStr = '${match.group(1)}/${match.group(2)}';
            }
          }
          if (instStr == null) continue;

          final instMatch = RegExp(r'^(\d+)/(\d+)$').firstMatch(instStr.trim());
          if (instMatch == null) continue;

          final currentNum = int.tryParse(instMatch.group(1) ?? '1') ?? 1;
          final totalNum = int.tryParse(instMatch.group(2) ?? '1') ?? 1;
          if (totalNum <= 1 || totalNum > 48 || currentNum > totalNum) continue;

          final projectedNum = currentNum + futureOffset;

          if (projectedNum <= totalNum) {
            final matchedPerson = tx.personName ?? debts.matchDebtorForPurchase(tx);
            cardTxs.add(
              TransactionModel(
                id: 'future_${tx.id}_$projectedNum',
                title: tx.title.replaceAll(RegExp(r'\d+/\d+'), '$projectedNum/$totalNum'),
                amount: tx.amount,
                date: DateTime(targetMonth.year, targetMonth.month, cardConfig.closingDay),
                type: TransactionType.expense,
                category: tx.category,
                bank: cardConfig.bank,
                installmentRef: '$projectedNum/$totalNum',
                personName: matchedPerson,
                notes: 'Parcela futura projetada para ${DateFormat('MMMM yyyy', 'pt_BR').format(targetMonth)}',
              ),
            );
          }
        }

        // Assinaturas ativas continuam nas faturas futuras
        cardSubs = subs.activeSubscriptions.where((s) {
          final sBank = s.bank?.toLowerCase() ?? 'nubank';
          if (cardConfig.id == 'nubank') return sBank.contains('nubank');
          if (cardConfig.id == 'itau_click') return sBank.contains('itau') || sBank.contains('itaú');
          if (cardConfig.id == 'itau_samsung') return false;
          if (cardConfig.id == 'mercado_pago') return sBank.contains('mercado pago');
          return false;
        }).toList();
      }

      cardInvoices.add(
        CardOpenInvoice(
          config: cardConfig,
          targetDueDate: targetDue,
          cycleStartDate: cycleStart,
          cycleEndDate: cycleEnd,
          transactions: cardTxs,
          projectedSubscriptions: cardSubs,
        ),
      );
    }

    // 2. CONSOLIDAÇÃO GERAL E FILTRO POR CARTÃO
    // Cartões filtrados para exibição
    final displayedCardInvoices = _selectedCardId == 'all'
        ? cardInvoices
        : cardInvoices.where((c) => c.config.id == _selectedCardId).toList();

    final activeTotal = displayedCardInvoices.fold(0.0, (s, c) => s + c.totalAmount);
    final activeMyShare = displayedCardInvoices.fold(0.0, (s, c) => s + c.myShareAmount);
    final activeDebtorShare = displayedCardInvoices.fold(0.0, (s, c) => s + c.debtorShareAmount);

    // Lista de transações consolidadas para o feed cronológico (apenas compras reais!)
    List<TransactionModel> allTransactions = [];
    final List<SubscriptionModel> allProjectedSubs = [];

    for (final card in displayedCardInvoices) {
      allTransactions.addAll(card.transactions);
      allProjectedSubs.addAll(card.projectedSubscriptions);
    }

    // Filtro de busca se houver
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      allTransactions = allTransactions.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            (t.personName?.toLowerCase().contains(q) ?? false) ||
            (t.bank?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Ordenação cronológica decrescente
    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    // Agrupamento por dia
    final Map<String, List<TransactionModel>> groupedByDay = {};
    for (final tx in allTransactions) {
      final dayKey = DateFormat('yyyy-MM-dd').format(tx.date);
      groupedByDay.putIfAbsent(dayKey, () => []).add(tx);
    }

    return Scaffold(
      backgroundColor: isDark ? AppConstants.oledBlack : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppConstants.oledBlack : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar na fatura...',
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fatura Unificada',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Nubank • Itaú Click • Samsung • Mercado Pago',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- 1. CARROSSEL HORIZONTAL DE MESES ESTILO NUBANK ---
          _buildMonthCarousel(isDark),

          // --- 2. CONTEÚDO PRINCIPAL ROLÁVEL ---
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HERO CARD NUBANK CONSOLIDADO
                  _buildNubankHeroCard(
                    isDark: isDark,
                    isMobile: isMobile,
                    targetMonth: targetMonth,
                    isCurrentOpen: isCurrentOpenMonth,
                    isPast: isPastMonth,
                    isFuture: isFutureMonth,
                    total: activeTotal,
                    myShare: activeMyShare,
                    debtorShare: activeDebtorShare,
                    cardInvoices: cardInvoices,
                  ),
                  const SizedBox(height: 16),

                  // FILTRO DE BANCOS / CARTÕES (PILLS)
                  _buildBankFilterPills(isDark, cardInvoices),
                  const SizedBox(height: 16),

                  // TÍTULO DA SEÇÃO DE COMPRAS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Compras da Fatura (${allTransactions.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (_selectedCardId != 'all')
                        TextButton(
                          onPressed: () => setState(() => _selectedCardId = 'all'),
                          child: const Text('Limpar filtro', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // FEED CRONOLÓGICO DE COMPRAS AGRUPADO POR DIA
                  if (allTransactions.isEmpty)
                    _buildEmptyState(isDark)
                  else
                    ...groupedByDay.entries.map((entry) {
                      return _buildDayGroup(
                        entry.key,
                        entry.value,
                        isDark,
                        finance,
                        debts,
                        subs,
                        loans,
                        payables,
                      );
                    }),
                  if (allProjectedSubs.isNotEmpty)
                    _buildProjectedSubscriptionsSection(isDark, allProjectedSubs),
                  const SizedBox(height: 80), // Espaço para a barra de ações fixada
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(
        context,
        isDark,
        activeTotal,
        activeDebtorShare,
        isCurrentOpenMonth,
        isPastMonth,
        allTransactions,
        debts,
      ),
    );
  }

  // --- CARROSSEL HORIZONTAL DE MESES ---
  Widget _buildMonthCarousel(bool isDark) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: ListView.builder(
        controller: _monthScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _availableOffsets.length,
        itemBuilder: (context, index) {
          final offset = _availableOffsets[index];
          final isSelected = offset == _selectedMonthOffset;
          final monthDate = _getTargetMonth(offset);

          final monthLabel = DateFormat('MMM yy', 'pt_BR').format(monthDate).toUpperCase();

          Color dotColor;
          String statusText;
          if (offset < 0) {
            dotColor = AppConstants.accentGreen;
            statusText = 'PAGA';
          } else if (offset == 0) {
            dotColor = const Color(0xFF00B4D8); // Cyan Nubank
            statusText = 'ABERTA';
          } else {
            dotColor = Colors.grey;
            statusText = 'FUTURA';
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                setState(() => _selectedMonthOffset = offset);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppConstants.oledCard : Colors.grey.shade100)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? (dotColor)
                        : (isDark ? AppConstants.oledBorder : Colors.transparent),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      monthLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? AppConstants.oledSubtext : Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '• $statusText',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: dotColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- HERO CARD NUBANK ---
  Widget _buildNubankHeroCard({
    required bool isDark,
    required bool isMobile,
    required DateTime targetMonth,
    required bool isCurrentOpen,
    required bool isPast,
    required bool isFuture,
    required double total,
    required double myShare,
    required double debtorShare,
    required List<CardOpenInvoice> cardInvoices,
  }) {
    Color statusColor;
    String statusTitle;
    String datesInfo;

    if (isPast) {
      statusColor = AppConstants.accentGreen;
      statusTitle = 'Fatura Paga';
      datesInfo = 'Vencimento ocorrido nos dias 10 e 13 de ${DateFormat('MMMM', 'pt_BR').format(targetMonth)}';
    } else if (isCurrentOpen) {
      statusColor = const Color(0xFF00B4D8);
      statusTitle = 'Fatura Aberta';
      datesInfo = 'Fechamentos: 03 a 06 de dez • Vencimentos: 10 a 13 de dez';
    } else {
      statusColor = const Color(0xFF8B5CF6);
      statusTitle = 'Fatura Futura';
      datesInfo = 'Parcelas e assinaturas projetadas para ${DateFormat('MMMM yyyy', 'pt_BR').format(targetMonth)}';
    }

    final double myShareRatio = total > 0 ? (myShare / total).clamp(0.0, 1.0) : 1.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Pill & Title
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('MMMM yyyy', 'pt_BR').format(targetMonth).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total Amount Display Gigante
          Text(
            CurrencyFormatter.format(total),
            style: TextStyle(
              fontSize: isMobile ? 32 : 38,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),

          // Dates Subtitle
          Text(
            datesInfo,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),

          // Barra Proporcional de Divisão (Sua Parte vs Devedores)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 8,
                  width: double.infinity,
                  color: AppConstants.accentIndigo,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: myShareRatio,
                    child: Container(color: AppConstants.primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppConstants.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sua Parte: ${CurrencyFormatter.format(myShare)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppConstants.accentIndigo,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Devedores: ${CurrencyFormatter.format(debtorShare)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.accentIndigo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 MINI-CARDS INDIVIDUAIS DOS BANCOS (2 POR LINHA - GRID 2x2 ELEGANTE)
          Column(
            children: [
              for (int i = 0; i < cardInvoices.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(bottom: i + 2 < cardInvoices.length ? 8.0 : 0.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMiniCardItem(isDark, cardInvoices[i]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: (i + 1 < cardInvoices.length)
                            ? _buildMiniCardItem(isDark, cardInvoices[i + 1])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCardItem(bool isDark, CardOpenInvoice card) {
    final isCardSelected = _selectedCardId == card.config.id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCardId = isCardSelected ? 'all' : card.config.id;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.oledSurface : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCardSelected
                ? card.config.color
                : (isDark ? AppConstants.oledBorder : Colors.grey.shade200),
            width: isCardSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: card.config.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.config.cardName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppConstants.oledSubtext : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(card.totalAmount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FILTRO DE BANCOS / CARTÕES (PILLS) ---
  Widget _buildBankFilterPills(bool isDark, List<CardOpenInvoice> cardInvoices) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Todos os Cartões (${cardInvoices.fold(0, (s, c) => s + c.transactions.length)})',
            isSelected: _selectedCardId == 'all',
            color: AppConstants.primaryColor,
            isDark: isDark,
            onTap: () => setState(() => _selectedCardId = 'all'),
          ),
          const SizedBox(width: 6),
          ...CardConfig.defaultCards.map((card) {
            final cardData = cardInvoices.firstWhere(
              (c) => c.config.id == card.id,
              orElse: () => CardOpenInvoice(
                config: card,
                targetDueDate: DateTime.now(),
                cycleStartDate: DateTime.now(),
                cycleEndDate: DateTime.now(),
                transactions: [],
              ),
            );
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildFilterChip(
                label: '${card.cardName} (${cardData.transactions.length})',
                isSelected: _selectedCardId == card.id,
                color: card.color,
                isDark: isDark,
                onTap: () => setState(() => _selectedCardId = card.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : (isDark ? AppConstants.oledSurface : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppConstants.oledBorder : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? color : (isDark ? AppConstants.oledSubtext : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  // --- AGRUPAMENTO DIÁRIO DAS COMPRAS ---
  Widget _buildDayGroup(
    String dayKey,
    List<TransactionModel> txs,
    bool isDark,
    FinanceProvider finance,
    DebtProvider debts,
    SubscriptionProvider subs,
    BankLoanProvider loans,
    PayableProvider payables,
  ) {
    final parsedDate = DateTime.tryParse(dayKey) ?? DateTime.now();
    final now = DateTime.now();

    String dayLabel;
    if (parsedDate.year == now.year && parsedDate.month == now.month && parsedDate.day == now.day) {
      dayLabel = 'HOJE • ${DateFormat("dd 'DE' MMMM", 'pt_BR').format(parsedDate).toUpperCase()}';
    } else if (parsedDate.year == now.year && parsedDate.month == now.month && parsedDate.day == now.day - 1) {
      dayLabel = 'ONTEM • ${DateFormat("dd 'DE' MMMM", 'pt_BR').format(parsedDate).toUpperCase()}';
    } else {
      dayLabel = DateFormat("EEEE, dd 'DE' MMMM", 'pt_BR').format(parsedDate).toUpperCase();
    }

    final dayTotal = txs.fold(0.0, (s, t) => s + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                CurrencyFormatter.format(dayTotal),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppConstants.oledCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: txs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? AppConstants.oledBorder : Colors.grey.shade100,
            ),
            itemBuilder: (context, index) {
              final tx = txs[index];
              return _buildTransactionTile(
                tx,
                isDark,
                () {
                  // Resync payables after any edit
                  payables.syncWithProviders(
                    finance: finance,
                    debts: debts,
                    subscriptions: subs,
                    loans: loans,
                  );
                  setState(() {});
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // --- ITEM DE COMPRA NO ESTILO NUBANK ---
  Widget _buildTransactionTile(TransactionModel tx, bool isDark, VoidCallback onRefresh) {
    final bLower = (tx.bank ?? '').toLowerCase();
    Color bankColor = AppConstants.primaryColor;
    if (bLower.contains('nubank')) bankColor = AppConstants.nubankPurple;
    if (bLower.contains('itau') || bLower.contains('itaú')) bankColor = AppConstants.itauOrange;
    if (bLower.contains('mercado pago')) bankColor = AppConstants.mercadoPagoBlue;

    final hasDebtor = tx.personName != null && tx.personName!.trim().isNotEmpty;

    return InkWell(
      onTap: () {
        InvoiceTransactionBottomSheet.show(
          context,
          transaction: tx,
          onUpdated: onRefresh,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Category Icon in Circle
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bankColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(tx.category),
                color: bankColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Title, Bank Pill & Debtor Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Bank Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: bankColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tx.bank ?? 'Cartão',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: bankColor,
                          ),
                        ),
                      ),
                      // Debtor Pill
                      if (hasDebtor)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.accentIndigo.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '👤 ${tx.personName}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.accentIndigo,
                            ),
                          ),
                        ),
                      // Installment Pill
                      if (tx.installmentRef != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.accentAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Parcela ${tx.installmentRef}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.accentAmber,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount
            Text(
              CurrencyFormatter.format(tx.amount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: hasDebtor ? AppConstants.accentIndigo : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BARRA DE AÇÕES NO RODAPÉ ESTILO NUBANK ---
  Widget _buildBottomActionBar(
    BuildContext context,
    bool isDark,
    double total,
    double debtorShare,
    bool isCurrentOpen,
    bool isPast,
    List<TransactionModel> transactions,
    DebtProvider debtProvider,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Botão Pagar Fatura
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPast ? AppConstants.accentGreen : AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(isPast ? Icons.check_circle_rounded : Icons.payments_rounded, size: 18),
                label: Text(
                  isPast ? 'Fatura Já Paga' : 'Pagar Fatura',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _showPaymentDialog(context, total, isPast);
                },
              ),
            ),
            const SizedBox(width: 10),

            // Botão Cobrar Devedores
            if (debtorShare > 0) ...[
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.accentIndigo,
                    side: const BorderSide(color: AppConstants.accentIndigo),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.handshake_rounded, size: 18),
                  label: const Text(
                    'Cobrar Devedores',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _showDebtorsSummarySheet(context, transactions, debtProvider, isDark);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- DIÁLOGO DE PAGAMENTO DA FATURA ---
  void _showPaymentDialog(BuildContext context, double total, bool isPast) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(isPast ? Icons.check_circle_rounded : Icons.payments_rounded, color: AppConstants.primaryColor),
            const SizedBox(width: 8),
            Text(isPast ? 'Fatura Liquidada' : 'Liquidar Fatura Unificada'),
          ],
        ),
        content: Text(
          isPast
              ? 'Esta fatura já foi quitada no período correspondente no valor de ${CurrencyFormatter.format(total)}.'
              : 'O valor consolidado a ser pago entre os 4 cartões é de ${CurrencyFormatter.format(total)}.\n\nDeseja registrar o pagamento consolidado das faturas?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          if (!isPast)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fatura marcada como liquidada com sucesso!'),
                    backgroundColor: AppConstants.accentGreen,
                  ),
                );
              },
              child: const Text('Confirmar Pagamento'),
            ),
        ],
      ),
    );
  }

  // --- BOTTOM SHEET DE COBRANÇA DE DEVEDORES DA FATURA ---
  void _showDebtorsSummarySheet(
    BuildContext context,
    List<TransactionModel> txs,
    DebtProvider debtProvider,
    bool isDark,
  ) {
    final Map<String, List<TransactionModel>> debtorTxs = {};
    for (final t in txs) {
      if (t.personName != null && t.personName!.trim().isNotEmpty) {
        debtorTxs.putIfAbsent(t.personName!, () => []).add(t);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppConstants.oledCard : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Devedores com Compras nesta Fatura',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Toque para enviar o lembrete de cobrança Pix diretamente no WhatsApp:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ...debtorTxs.entries.map((entry) {
              final person = entry.key;
              final personTxs = entry.value;
              final personTotal = personTxs.fold(0.0, (s, t) => s + t.amount);
              final personDebts = debtProvider.activeDebtsByPerson[person] ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppConstants.oledSurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '${personTxs.length} compras • ${CurrencyFormatter.format(personTotal)}',
                          style: const TextStyle(fontSize: 12, color: AppConstants.accentIndigo),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                      label: const Text('Cobrar', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => WhatsAppReminderDialog(
                            personName: person,
                            debts: personDebts,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: isDark ? AppConstants.oledSubtext : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhuma compra nesta fatura',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Nenhum lançamento encontrado para "$_searchQuery".'
                : 'Não há gastos registrados para os filtros selecionados.',
            style: TextStyle(fontSize: 12, color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'alimentação':
      case 'restaurante':
        return Icons.restaurant_rounded;
      case 'supermercado':
        return Icons.shopping_cart_rounded;
      case 'transporte':
      case 'uber':
        return Icons.directions_car_rounded;
      case 'saúde':
      case 'farmácia':
        return Icons.local_hospital_rounded;
      case 'lazer':
        return Icons.movie_rounded;
      case 'serviços':
        return Icons.miscellaneous_services_rounded;
      case 'compras':
        return Icons.shopping_bag_rounded;
      case 'moradia':
        return Icons.home_rounded;
      case 'telefonia & internet':
        return Icons.wifi_rounded;
      case 'financeiro':
        return Icons.account_balance_rounded;
      default:
        return Icons.credit_card_rounded;
    }
  }

  Widget _buildProjectedSubscriptionsSection(bool isDark, List<SubscriptionModel> subs) {
    final totalSubs = subs.fold(0.0, (s, sub) => s + sub.amount);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.oledCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppConstants.oledBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.autorenew_rounded, size: 16, color: AppConstants.accentAmber),
                  const SizedBox(width: 8),
                  const Text(
                    'Assinaturas Previstas',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppConstants.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+ ${CurrencyFormatter.format(totalSubs)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.accentAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cobranças estimadas que ainda não caíram no extrato do cartão. Não inclusas no total oficial acima.',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppConstants.oledSubtext : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          ...subs.map((sub) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Dia ${sub.billingDay}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppConstants.oledSubtext : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            sub.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (sub.sharedWithPerson != null && sub.sharedWithPerson!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppConstants.accentIndigo.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sub.sharedWithPerson!,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppConstants.accentIndigo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(sub.amount),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

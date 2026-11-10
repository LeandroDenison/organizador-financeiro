import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/debt_provider.dart';
import '../../models/subscription_model.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/constants.dart';

class SubscriptionsView extends StatelessWidget {
  const SubscriptionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assinaturas & Custos Recorrentes',
                      style: (isMobile
                              ? Theme.of(context).textTheme.titleLarge
                              : Theme.of(context).textTheme.headlineSmall)
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reconhecimento automático de streamings, clubes (Uber, iFood) e planos na fatura',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showAuditDialog(context, subProvider, financeProvider),
                      icon: const Icon(Icons.rule_rounded, size: 17),
                      label: const Text('Auditar Mês Retrasado'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (subProvider.pausedSubscriptions.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final removed = await subProvider.purgeInactiveSubscriptions();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$removed assinatura(s) inativa(s) excluída(s) com sucesso!'),
                                backgroundColor: AppConstants.accentGreen,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_sweep_rounded, size: 17, color: Colors.redAccent),
                        label: Text('Excluir (${subProvider.pausedSubscriptions.length}) Inativas'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final added = await subProvider.syncFromTransactions(
                          financeProvider.transactions,
                          ignoreDismissed: true,
                          debtProvider: context.read<DebtProvider>(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                added > 0
                                    ? '$added novas assinaturas reconhecidas da fatura!'
                                    : 'Todas as assinaturas da fatura já estão listadas abaixo.',
                              ),
                              backgroundColor: AppConstants.primaryColor,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 17),
                      label: const Text('Reconhecer da Fatura'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.primaryColor,
                        side: const BorderSide(color: AppConstants.primaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddSubscriptionDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nova Assinatura'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Annual Drain Awareness Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dreno Anual em Assinaturas Ativas',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 22),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(subProvider.totalAnnualCost),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sua parte: ${CurrencyFormatter.format(subProvider.totalMonthlyCost)}/mês em ${subProvider.activeSubscriptions.length} assinaturas ativas'
                    '${subProvider.totalSharedThirdPartyCost > 0 ? ' (Bruto: ${CurrencyFormatter.format(subProvider.totalGrossMonthlyCost)}/mês • ${CurrencyFormatter.format(subProvider.totalSharedThirdPartyCost)}/mês pagos por terceiros)' : ''}'
                    '${subProvider.pausedSubscriptions.isNotEmpty ? ' • ${subProvider.pausedSubscriptions.length} pausada(s)' : ''}.',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Subscriptions list
            if (subProvider.subscriptions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(Icons.subscriptions_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhuma assinatura cadastrada.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Importe sua fatura ou clique em "Reconhecer da Fatura" para detectar automaticamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subProvider.subscriptions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final sub = subProvider.subscriptions[index];
                  return _buildSubscriptionCard(context, sub, isDark);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, SubscriptionModel sub, bool isDark) {
    final subProvider = context.read<SubscriptionProvider>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: sub.isActive
              ? (isDark ? const Color(0xFF334155) : Colors.grey.shade200)
              : Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: sub.isActive
                    ? AppConstants.primaryColor.withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.15),
                child: Icon(
                  sub.isActive ? Icons.repeat_rounded : Icons.pause_circle_outline_rounded,
                  color: sub.isActive ? AppConstants.primaryColor : Colors.amber.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            sub.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: sub.isActive ? null : TextDecoration.lineThrough,
                              color: sub.isActive ? null : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${CurrencyFormatter.format(sub.effectiveMyCost)}/mês',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: sub.isActive ? AppConstants.accentRed : Colors.grey,
                              ),
                            ),
                            if (sub.isShared)
                              Text(
                                'de ${CurrencyFormatter.format(sub.amount)} na fatura',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dia ${sub.billingDay} • ${sub.category} • Seu custo anual: ${CurrencyFormatter.format(sub.annualAmount)}/ano',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    if (sub.isShared) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🤝 Conta dividida: você paga ${CurrencyFormatter.format(sub.effectiveMyCost)} e ${sub.sharedWithPerson} paga ${CurrencyFormatter.format(sub.thirdPartyShare)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.primaryColor,
                          ),
                        ),
                      ),
                    ],
                    if (sub.sourceTransactionTitle != null &&
                        sub.sourceTransactionTitle!.toLowerCase() != sub.name.toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reconhecida de: "${sub.sourceTransactionTitle}"',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sub.isActive
                            ? AppConstants.accentGreen.withValues(alpha: 0.14)
                            : Colors.amber.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sub.isActive ? '● Ativa' : '⏸ Pausada',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: sub.isActive ? AppConstants.accentGreen : Colors.amber.shade700,
                        ),
                      ),
                    ),
                    if (sub.bank != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppConstants.getBankColor(sub.bank).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sub.bank!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.getBankColor(sub.bank),
                          ),
                        ),
                      ),
                    if (!sub.isActive && sub.inactiveReason != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sub.inactiveReason!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _showSplitSubscriptionDialog(context, sub),
                    style: TextButton.styleFrom(
                      foregroundColor: AppConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.group_add_rounded, size: 15),
                    label: Text(
                      sub.isShared ? 'Divisão' : 'Dividir',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => subProvider.toggleSubscription(sub.id),
                    style: TextButton.styleFrom(
                      foregroundColor: sub.isActive ? Colors.amber.shade700 : AppConstants.accentGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      sub.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(
                      sub.isActive ? 'Pausar' : 'Ativar',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Excluir assinatura',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.grey),
                    onPressed: () => subProvider.deleteSubscription(sub.id),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSplitSubscriptionDialog(BuildContext context, SubscriptionModel sub) {
    final myShareController = TextEditingController(
      text: sub.myShareAmount != null
          ? sub.myShareAmount!.toStringAsFixed(2).replaceAll('.', ',')
          : (sub.amount / 2).toStringAsFixed(2).replaceAll('.', ','),
    );
    final personController = TextEditingController(text: sub.sharedWithPerson ?? 'Sergio Lucas');
    bool syncToDebts = true;

    final debtProvider = context.read<DebtProvider>();
    final suggestedPeople = <String>{
      'Sergio Lucas',
      'Clecio',
      ...debtProvider.uniquePersonNames,
    }.toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final parsedMyShare =
              double.tryParse(myShareController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
          final thirdPartyAmount = (sub.amount - parsedMyShare).clamp(0.0, sub.amount);

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            title: Text('Dividir Assinatura: ${sub.name}'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valor Total na Fatura:', style: TextStyle(fontSize: 13)),
                          Text(
                            CurrencyFormatter.format(sub.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: myShareController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quanto VOCÊ paga (R\$)',
                        hintText: 'Ex: 4,90',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: personController,
                      decoration: const InputDecoration(
                        labelText: 'Quem paga o restante?',
                        hintText: 'Ex: Sergio Lucas',
                        prefixIcon: Icon(Icons.handshake_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: suggestedPeople.map((name) {
                        return ActionChip(
                          label: Text(name, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            personController.text = name;
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined, size: 18, color: AppConstants.accentGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Parte de ${personController.text.trim().isEmpty ? "Terceiro" : personController.text.trim()}: '
                              '${CurrencyFormatter.format(thirdPartyAmount)}/mês',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.accentGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: syncToDebts,
                      onChanged: (v) => setState(() => syncToDebts = v ?? true),
                      title: const Text(
                        'Registrar cobrança em "Quem me Deve"',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Adiciona automaticamente o valor restante na conta da pessoa',
                        style: TextStyle(fontSize: 11),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (sub.isShared)
                TextButton(
                  onPressed: () async {
                    await ctx.read<SubscriptionProvider>().updateSubscriptionSplit(
                          id: sub.id,
                          myShareAmount: null,
                          sharedWithPerson: null,
                          debtProvider: debtProvider,
                          syncToDebts: true,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Remover Divisão', style: TextStyle(color: AppConstants.accentRed)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final person = personController.text.trim();
                  if (parsedMyShare >= 0 && parsedMyShare < sub.amount && person.isNotEmpty) {
                    await ctx.read<SubscriptionProvider>().updateSubscriptionSplit(
                          id: sub.id,
                          myShareAmount: parsedMyShare,
                          sharedWithPerson: person,
                          debtProvider: debtProvider,
                          syncToDebts: syncToDebts,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text('Salvar Divisão'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController();
    String? selectedBank = 'Nubank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nova Assinatura'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome (ex: Netflix, Spotify, Academia)',
                  prefixIcon: Icon(Icons.subscriptions_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor Mensal (R\$)',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dia do Vencimento (1 a 31)',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedBank,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Banco / Cartão',
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'Nubank', child: Text('Nubank')),
                  DropdownMenuItem(value: 'Itaú', child: Text('Itaú')),
                  DropdownMenuItem(value: 'Mercado Pago', child: Text('Mercado Pago')),
                  DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                ],
                onChanged: (val) => setState(() => selectedBank = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
                final day = int.tryParse(dayController.text) ?? 1;

                if (name.isNotEmpty && amount > 0) {
                  ctx.read<SubscriptionProvider>().addSubscription(
                        SubscriptionModel(
                          name: name,
                          amount: amount,
                          billingDay: day.clamp(1, 31),
                          bank: selectedBank,
                        ),
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuditDialog(
    BuildContext context,
    SubscriptionProvider subProvider,
    FinanceProvider financeProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rule_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Regra do Mês Retrasado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Se uma assinatura foi cobrada no mês retrasado (ou antes), mas no mês passado NÃO teve cobrança nem neste mês, ela é considerada cancelada/expirada.\n\nO que você deseja fazer com as assinaturas identificadas?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final affected = await subProvider.auditLapsedSubscriptions(
                financeProvider.transactions,
                deleteInstead: false,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      affected.isNotEmpty
                          ? '${affected.length} assinatura(s) desativada(s): ${affected.join(", ")}'
                          : 'Nenhuma assinatura pendente de desativação encontrada.',
                    ),
                    backgroundColor: AppConstants.primaryColor,
                  ),
                );
              }
            },
            child: const Text('Desativar (Pausar)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final affected = await subProvider.auditLapsedSubscriptions(
                financeProvider.transactions,
                deleteInstead: true,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      affected.isNotEmpty
                          ? '${affected.length} assinatura(s) excluída(s): ${affected.join(", ")}'
                          : 'Nenhuma assinatura encontrada para exclusão.',
                    ),
                    backgroundColor: AppConstants.accentRed,
                  ),
                );
              }
            },
            child: const Text('Excluir Definitivamente'),
          ),
        ],
      ),
    );
  }
}

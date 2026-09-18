import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/sync_status_chip.dart';
import '../bloc/accounts_bloc.dart';
import '../bloc/saving_goals_bloc.dart';
import '../bloc/transactions_bloc.dart';
import 'accounts_page.dart';
import 'categories_page.dart';
import 'saving_goals_page.dart';
import 'transaction_editor_page.dart';
import 'transactions_page.dart';

class BudgetDashboardPage extends StatefulWidget {
  const BudgetDashboardPage({super.key});

  @override
  State<BudgetDashboardPage> createState() => _BudgetDashboardPageState();
}

class _BudgetDashboardPageState extends State<BudgetDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<AccountsBloc>().add(const AccountsSubscriptionRequested());
    context.read<TransactionsBloc>().add(
      const TransactionsSubscriptionRequested(),
    );
    context.read<SavingGoalsBloc>().add(
      const SavingGoalsSubscriptionRequested(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: const [SyncStatusChip()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<AccountsBloc>().add(const AccountsRefreshRequested());
          context.read<TransactionsBloc>().add(
            const TransactionsRefreshRequested(),
          );
          context.read<SavingGoalsBloc>().add(
            const SavingGoalsRefreshRequested(),
          );
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BlocBuilder<AccountsBloc, AccountsState>(
              builder: (context, accountsState) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOLDE TOTAL',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(accountsState.totalBalance),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${accountsState.accounts.length} compte${accountsState.accounts.length > 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            BlocBuilder<TransactionsBloc, TransactionsState>(
              builder: (context, state) {
                final now = DateTime.now();
                final thisMonth = state.transactions.where(
                  (t) =>
                      t.occurredAt.year == now.year &&
                      t.occurredAt.month == now.month,
                );
                final income = thisMonth
                    .where((t) => t.type == 'income')
                    .fold(0.0, (sum, t) => sum + t.amount);
                final expenses = thisMonth
                    .where((t) => t.type == 'expense')
                    .fold(0.0, (sum, t) => sum + t.amount);

                return Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Revenus (mois)',
                        value: income,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Dépenses (mois)',
                        value: expenses,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
              children: [
                _QuickLink(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Comptes',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AccountsPage(),
                    ),
                  ),
                ),
                _QuickLink(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transactions',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TransactionsPage(),
                    ),
                  ),
                ),
                _QuickLink(
                  icon: Icons.savings_outlined,
                  label: 'Objectifs',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SavingGoalsPage(),
                    ),
                  ),
                ),
                _QuickLink(
                  icon: Icons.category_outlined,
                  label: 'Catégories',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CategoriesPage(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Objectifs d\'épargne', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            BlocBuilder<SavingGoalsBloc, SavingGoalsState>(
              builder: (context, state) {
                if (state.goals.isEmpty) {
                  return const EmptyState(
                    icon: Icons.savings_outlined,
                    title: 'Aucun objectif pour le moment',
                  );
                }

                return Column(
                  children: state.goals
                      .take(3)
                      .map(
                        (goal) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.name,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: goal.progress,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${CurrencyFormatter.format(goal.currentAmount)} / ${CurrencyFormatter.format(goal.targetAmount)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<TransactionsBloc>()),
                BlocProvider.value(value: context.read<AccountsBloc>()),
              ],
              child: const TransactionEditorPage(),
            ),
          ),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(value),
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../bloc/accounts_bloc.dart';
import '../bloc/categories_bloc.dart';
import '../bloc/transactions_bloc.dart';
import '../data/account_model.dart';
import '../data/category_model.dart';
import '../data/transaction_model.dart';
import 'transaction_editor_page.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  @override
  void initState() {
    super.initState();
    context.read<TransactionsBloc>().add(
      const TransactionsSubscriptionRequested(),
    );
    context.read<AccountsBloc>().add(const AccountsSubscriptionRequested());
    context.read<CategoriesBloc>().add(const CategoriesSubscriptionRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: BlocBuilder<TransactionsBloc, TransactionsState>(
        builder: (context, txState) => BlocBuilder<AccountsBloc, AccountsState>(
          builder: (context, accountsState) =>
              BlocBuilder<CategoriesBloc, CategoriesState>(
                builder: (context, categoriesState) {
                  if (txState.transactions.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Aucune transaction pour le moment',
                    );
                  }

                  final accountsByUuid = {
                    for (final a in accountsState.accounts) a.localUuid: a,
                  };
                  final categoriesByUuid = {
                    for (final c in categoriesState.categories) c.localUuid: c,
                  };

                  return RefreshIndicator(
                    onRefresh: () async => context.read<TransactionsBloc>().add(
                      const TransactionsRefreshRequested(),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: txState.transactions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) => _TransactionTile(
                        transaction: txState.transactions[index],
                        account:
                            accountsByUuid[txState
                                .transactions[index]
                                .accountLocalUuid],
                        category:
                            txState.transactions[index].categoryLocalUuid ==
                                null
                            ? null
                            : categoriesByUuid[txState
                                  .transactions[index]
                                  .categoryLocalUuid],
                      ),
                    ),
                  );
                },
              ),
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.account,
    required this.category,
  });

  final TransactionModel transaction;
  final AccountModel? account;
  final CategoryModel? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM', 'fr_FR');
    final isExpense = transaction.type == 'expense';
    final isTransfer = transaction.type == 'transfer';
    final amountColor = isTransfer
        ? theme.colorScheme.onSurfaceVariant
        : (isExpense ? theme.colorScheme.error : Colors.green.shade600);
    final bloc = context.read<TransactionsBloc>();

    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: bloc),
                BlocProvider.value(value: context.read<AccountsBloc>()),
              ],
              child: TransactionEditorPage(transaction: transaction),
            ),
          ),
        ),
        onLongPress: () => _confirmDelete(context, bloc),
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.12),
          child: Icon(
            isTransfer
                ? Icons.swap_horiz_rounded
                : (isExpense
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded),
            color: amountColor,
          ),
        ),
        title: Text(
          transaction.description?.isNotEmpty == true
              ? transaction.description!
              : (category?.name ??
                    transactionTypes[transaction.type] ??
                    transaction.type),
        ),
        subtitle: Text(
          '${account?.name ?? '—'} · ${dateFormat.format(transaction.occurredAt)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isExpense ? '-' : (isTransfer ? '' : '+')}${CurrencyFormatter.format(transaction.amount)}',
              style: theme.textTheme.titleSmall?.copyWith(color: amountColor),
            ),
            if (!transaction.isSynced)
              Icon(
                Icons.cloud_upload_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionsBloc bloc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette transaction ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: AppButtonStyles.destructive(context),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(TransactionDeleted(transaction));
    }
  }
}

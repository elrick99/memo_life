import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../bloc/accounts_bloc.dart';
import '../data/account_model.dart';
import '../data/account_repository.dart';
import 'account_editor_sheet.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comptes')),
      body: BlocBuilder<AccountsBloc, AccountsState>(
        builder: (context, state) {
          if (state.accounts.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Aucun compte pour le moment',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => context.read<AccountsBloc>().add(
              const AccountsRefreshRequested(),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.accounts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _AccountTile(account: state.accounts[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: context.read<AccountsBloc>(),
            child: const AccountEditorSheet(),
          ),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final AccountModel account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<AccountsBloc>();

    return Card(
      child: ListTile(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: AccountEditorSheet(account: account),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(account.name),
        subtitle: Text(accountTypes[account.type] ?? account.type),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(account.balance),
              style: theme.textTheme.titleSmall,
            ),
            if (!account.isSynced)
              Icon(
                Icons.cloud_upload_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
        onLongPress: () => _confirmDelete(context, bloc, account),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AccountsBloc bloc,
    AccountModel account,
  ) async {
    final hasTransactions = await getIt<AccountRepository>().hasTransactions(
      account.localUuid,
    );
    if (!context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
          hasTransactions
              ? 'Ce compte est lié à des transactions et ne peut pas être supprimé.'
              : '« ${account.name} » sera définitivement supprimé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          if (!hasTransactions)
            FilledButton(
              style: AppButtonStyles.destructive(context),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(AccountDeleted(account));
    }
  }
}

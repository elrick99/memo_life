import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/sync_status_chip.dart';
import '../../security/presentation/change_password_page.dart';
import '../../security/presentation/edit_profile_page.dart';
import '../../security/presentation/two_factor_setup_page.dart';
import '../bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AuthBloc>().state;
    final user = state.user;

    return Scaffold(
      appBar: AppHeader(
        title: 'Profil',
        icon: Icons.person_outline_rounded,
        actions: const [SyncStatusChip()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      state.isGuest
                          ? Icons.person_off_outlined
                          : Icons.person_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isGuest ? 'Invité' : (user?.name ?? ''),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          state.isGuest ? 'Aucun compte' : (user?.email ?? ''),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.isGuest) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Vos données restent sur cet appareil',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Créez un compte pour les sauvegarder et les retrouver sur un autre appareil.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    onPressed: () => context.push('/register'),
                    child: const Text('Créer un compte'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (!state.isGuest) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Modifier le profil'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditProfilePage(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Mot de passe'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Authentification à deux facteurs'),
                    subtitle: Text(
                      (user?.hasTwoFactorEnabled ?? false)
                          ? 'Activée'
                          : 'Désactivée',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TwoFactorSetupPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          OutlinedButton.icon(
            onPressed: () => _logout(context, isGuest: state.isGuest),
            icon: const Icon(Icons.logout_rounded),
            label: Text(
              state.isGuest ? 'Quitter le mode local' : 'Se déconnecter',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, {required bool isGuest}) async {
    if (isGuest) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quitter le mode local ?'),
          content: const Text(
            'Vos notes, rappels et données de budget créés en local seront définitivement supprimés de cet appareil.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer et quitter'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
    }
    if (context.mounted) {
      context.read<AuthBloc>().add(const AuthLoggedOut());
    }
  }
}

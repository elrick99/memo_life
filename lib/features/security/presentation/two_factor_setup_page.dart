import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../data/security_remote_data_source.dart';
import '../data/security_repository.dart';

enum _Step { intro, awaitingConfirmation, recoveryCodes }

class TwoFactorSetupPage extends StatefulWidget {
  const TwoFactorSetupPage({super.key});

  @override
  State<TwoFactorSetupPage> createState() => _TwoFactorSetupPageState();
}

class _TwoFactorSetupPageState extends State<TwoFactorSetupPage> {
  final _repository = getIt<SecurityRepository>();
  final _codeController = TextEditingController();
  _Step _step = _Step.intro;
  TwoFactorSecret? _secret;
  List<String> _recoveryCodes = const [];
  bool _isBusy = false;
  String? _error;

  bool get _isEnabled =>
      context.read<AuthBloc>().state.user?.hasTwoFactorEnabled ?? false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final secret = await _repository.enableTwoFactor();
      setState(() {
        _secret = secret;
        _step = _Step.awaitingConfirmation;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _confirm() async {
    if (_codeController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final codes = await _repository.confirmTwoFactor(
        _codeController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      final user = context.read<AuthBloc>().state.user;
      if (user != null) {
        context.read<AuthBloc>().add(
          AuthUserRefreshed(user.copyWith(hasTwoFactorEnabled: true)),
        );
      }
      setState(() {
        _recoveryCodes = codes;
        _step = _Step.recoveryCodes;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _disable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Désactiver la double authentification ?'),
        content: const Text(
          'Votre compte sera protégé uniquement par votre mot de passe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await _repository.disableTwoFactor();
      if (!mounted) {
        return;
      }
      final user = context.read<AuthBloc>().state.user;
      if (user != null) {
        context.read<AuthBloc>().add(
          AuthUserRefreshed(user.copyWith(hasTwoFactorEnabled: false)),
        );
      }
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Double authentification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
          ],
          if (_step == _Step.intro) _buildIntro(context),
          if (_step == _Step.awaitingConfirmation)
            _buildAwaitingConfirmation(context),
          if (_step == _Step.recoveryCodes) _buildRecoveryCodes(context),
        ],
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    if (_isEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            leading: Icon(Icons.verified_user_rounded, color: Colors.green),
            title: Text('Double authentification activée'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _isBusy ? null : _disable,
            child: const Text('Désactiver'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ajoutez une couche de sécurité supplémentaire : un code temporaire généré par une application '
          'd\'authentification (Google Authenticator, Authy…) sera requis en plus de votre mot de passe.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isBusy ? null : _enable,
          child: _isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Activer'),
        ),
      ],
    );
  }

  Widget _buildAwaitingConfirmation(BuildContext context) {
    final secret = _secret!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scannez ce code avec votre application d\'authentification :',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(data: secret.url, size: 200),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ou saisissez cette clé manuellement :',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        SelectableText(
          secret.secretKey,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Code à 6 chiffres'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isBusy ? null : _confirm,
          child: _isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmer'),
        ),
      ],
    );
  }

  Widget _buildRecoveryCodes(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListTile(
          leading: Icon(Icons.verified_user_rounded, color: Colors.green),
          title: Text('Double authentification activée'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        Text(
          'Conservez ces codes de récupération dans un endroit sûr : chacun ne peut être utilisé qu\'une fois '
          'pour vous connecter si vous perdez l\'accès à votre application d\'authentification.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _recoveryCodes
                .map(
                  (code) =>
                      Text(code, style: Theme.of(context).textTheme.titleSmall),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _recoveryCodes.join('\n')));
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Codes copiés.')));
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copier les codes'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Terminé'),
        ),
      ],
    );
  }
}

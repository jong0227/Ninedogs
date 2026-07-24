import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/credential.dart';
import '../../providers/vault_providers.dart';

/// 계정 정보 입력 시트. 금고가 열려 있을 때만 부른다.
Future<void> showCredentialEditor(
  BuildContext context,
  String subscriptionId,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: _CredentialEditor(subscriptionId: subscriptionId),
      ),
    ),
  ),
);

class _CredentialEditor extends ConsumerStatefulWidget {
  const _CredentialEditor({required this.subscriptionId});

  final String subscriptionId;

  @override
  ConsumerState<_CredentialEditor> createState() => _CredentialEditorState();
}

class _CredentialEditorState extends ConsumerState<_CredentialEditor> {
  final _loginId = TextEditingController();
  final _password = TextEditingController();
  final _memo = TextEditingController();

  LoginMethod _method = LoginMethod.email;
  bool _obscure = true;
  bool _loaded = false;

  @override
  void dispose() {
    _loginId.dispose();
    _password.dispose();
    _memo.dispose();
    super.dispose();
  }

  /// 기존 값이 있으면 채워 넣는다. 시트가 뜬 뒤 한 번만 한다.
  void _prefill(Credential credential) {
    if (_loaded) return;
    _loaded = true;
    _loginId.text = credential.loginId;
    _password.text = credential.password;
    _memo.text = credential.memo ?? '';
    _method = credential.loginMethod;
  }

  Future<void> _save(Credential base) async {
    final crypto = ref.read(vaultProvider.notifier).crypto;
    if (crypto == null) return; // 저장 도중 잠겼다면 아무것도 하지 않는다

    await ref
        .read(storedCredentialsProvider.notifier)
        .save(
          base.copyWith(
            loginId: _loginId.text.trim(),
            password: _password.text,
            loginMethod: _method,
            memo: _memo.text.trim(),
          ),
          crypto,
        );

    ref.invalidate(credentialProvider(widget.subscriptionId));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref
        .read(storedCredentialsProvider.notifier)
        .removeFor(widget.subscriptionId);

    ref.invalidate(credentialProvider(widget.subscriptionId));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credential = ref.watch(credentialProvider(widget.subscriptionId));
    final hasSaved = ref.watch(hasCredentialProvider(widget.subscriptionId));

    final value = credential.value;
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    _prefill(value);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('계정 정보', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '저장할 때 이 기기에서 암호화돼요. 서버에는 암호문만 올라가요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.labelMedium?.color,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        Text('로그인 방식', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final method in LoginMethod.values)
              _MethodChip(
                label: method.label,
                active: method == _method,
                onTap: () => setState(() => _method = method),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        TextField(
          controller: _loginId,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: '아이디'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _password,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '비밀번호',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _memo,
          decoration: const InputDecoration(
            labelText: '메모',
            hintText: '예: 프로필 2번, 아내 명의',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        FilledButton(onPressed: () => _save(value), child: const Text('저장')),
        if (hasSaved)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: const Text('계정 정보 삭제'),
          ),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active ? AppColors.accent : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.accent : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/vault_providers.dart';

/// 마스터 암호를 처음 정하는 시트.
Future<bool> showVaultSetupSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SheetFrame(child: _VaultSetupForm()),
  );
  return result ?? false;
}

/// 잠긴 금고를 여는 시트.
Future<bool> showVaultUnlockSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SheetFrame(child: _VaultUnlockForm()),
  );
  return result ?? false;
}

/// 키보드가 올라와도 내용이 가리지 않도록 감싸는 틀.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom,
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: child,
      ),
    ),
  );
}

class _VaultSetupForm extends ConsumerStatefulWidget {
  const _VaultSetupForm();

  @override
  ConsumerState<_VaultSetupForm> createState() => _VaultSetupFormState();
}

class _VaultSetupFormState extends ConsumerState<_VaultSetupForm> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _working = false;
  String? _error;

  static const _minLength = 8;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;

    if (password.length < _minLength) {
      setState(() => _error = '$_minLength자 이상으로 정해주세요');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = '두 번 입력한 값이 서로 달라요');
      return;
    }

    setState(() {
      _error = null;
      _working = true;
    });

    await ref.read(vaultProvider.notifier).setUp(password);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('마스터 암호 정하기', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '계정 정보는 이 암호로 잠긴 채 저장돼요. 배우자와 같은 암호를 쓰면 '
          '서로의 기록을 함께 볼 수 있어요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.labelMedium?.color,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 복구가 불가능하다는 점은 반드시 정하기 전에 보여준다.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.negative.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.negative,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '이 암호를 잊으면 저장한 계정 정보를 되살릴 방법이 없어요. '
                  '앱도, 서버도 암호를 모르기 때문이에요.',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        TextField(
          controller: _password,
          obscureText: _obscure,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '마스터 암호',
            errorText: _error,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _confirm,
          obscureText: _obscure,
          decoration: const InputDecoration(labelText: '한 번 더 입력'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xl),

        FilledButton(
          onPressed: _working ? null : _submit,
          child: _working
              ? const _WorkingIndicator()
              : const Text('설정하고 잠금 해제'),
        ),
      ],
    );
  }
}

class _VaultUnlockForm extends ConsumerStatefulWidget {
  const _VaultUnlockForm();

  @override
  ConsumerState<_VaultUnlockForm> createState() => _VaultUnlockFormState();
}

class _VaultUnlockFormState extends ConsumerState<_VaultUnlockForm> {
  final _password = TextEditingController();

  bool _obscure = true;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _working = true;
    });

    final opened = await ref.read(vaultProvider.notifier).unlock(_password.text);

    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _working = false;
        _error = '암호가 맞지 않아요';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('잠금 해제', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '마스터 암호를 입력하면 계정 정보를 볼 수 있어요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.labelMedium?.color,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _password,
          obscureText: _obscure,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '마스터 암호',
            errorText: _error,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _working ? null : _submit,
          child: _working ? const _WorkingIndicator() : const Text('열기'),
        ),
      ],
    );
  }
}

/// 키를 만드는 동안(PBKDF2) 잠깐 도는 표시.
class _WorkingIndicator extends StatelessWidget {
  const _WorkingIndicator();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: Theme.of(context).colorScheme.onPrimary,
    ),
  );
}

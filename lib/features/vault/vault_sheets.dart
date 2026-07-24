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

/// 마스터 암호를 바꾸는 시트. 저장된 계정 정보를 전부 새 키로 다시 암호화한다.
Future<bool> showVaultChangePasswordSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SheetFrame(child: _VaultChangePasswordForm()),
  );
  return result ?? false;
}

class _VaultChangePasswordForm extends ConsumerStatefulWidget {
  const _VaultChangePasswordForm();

  @override
  ConsumerState<_VaultChangePasswordForm> createState() =>
      _VaultChangePasswordFormState();
}

class _VaultChangePasswordFormState
    extends ConsumerState<_VaultChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _working = false;
  String? _error;

  static const _minLength = 8;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length < _minLength) {
      setState(() => _error = '새 암호는 $_minLength자 이상이어야 해요');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = '새 암호를 두 번 입력한 값이 서로 달라요');
      return;
    }

    setState(() {
      _error = null;
      _working = true;
    });

    final changed = await ref
        .read(vaultProvider.notifier)
        .changePassword(_current.text, _next.text);

    if (!mounted) return;
    if (changed) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _working = false;
        _error = '지금 쓰는 암호가 맞지 않아요';
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
        Text('마스터 암호 변경', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '저장된 계정 정보를 모두 새 암호로 다시 암호화해요. '
          '배우자도 새 암호를 알아야 열 수 있어요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.labelMedium?.color,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _current,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '지금 쓰는 암호',
            errorText: _error,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _next,
          obscureText: true,
          decoration: const InputDecoration(labelText: '새 암호'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: '새 암호 한 번 더'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _working ? null : _submit,
          child: _working ? const _WorkingIndicator() : const Text('변경'),
        ),
      ],
    );
  }
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

    if (!mounted) return;
    await maybeOfferBiometrics(context, ref);
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
  void initState() {
    super.initState();

    // 생체인증을 켜뒀으면 시트가 열리자마자 바로 물어본다.
    // 암호를 칠 준비를 하다가 뒤늦게 지문 창이 뜨면 흐름이 끊긴다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await ref.read(biometricEnabledProvider.future)) {
        if (mounted) _tryBiometrics();
      }
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _tryBiometrics() async {
    setState(() => _working = true);
    final opened = await ref.read(vaultProvider.notifier).unlockWithBiometrics();

    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop(true);
    } else {
      // 취소했을 수도 있으니 오류로 몰아붙이지 않는다. 암호로 넘어가면 된다.
      setState(() => _working = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _working = true;
    });

    final opened = await ref.read(vaultProvider.notifier).unlock(_password.text);

    if (!mounted) return;
    if (opened) {
      await maybeOfferBiometrics(context, ref);
      if (mounted) Navigator.of(context).pop(true);
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
        // 생체인증이 실패하거나 취소됐을 때 다시 시도할 수 있게 남겨둔다
        if (ref.watch(biometricEnabledProvider).value ?? false)
          TextButton.icon(
            onPressed: _working ? null : _tryBiometrics,
            icon: const Icon(Icons.fingerprint, size: 18),
            label: const Text('지문으로 열기'),
          ),
      ],
    );
  }
}

/// 암호로 연 직후, 다음부터는 지문으로 열지 물어본다.
///
/// 처음부터 묻지 않는 이유: 마스터 암호를 한 번도 안 쳐본 사람에게
/// 생체인증을 권하면 무엇을 여는 열쇠인지 감이 오지 않는다.
Future<void> maybeOfferBiometrics(BuildContext context, WidgetRef ref) async {
  final available = await ref.read(biometricAvailableProvider.future);
  final enabled = await ref.read(biometricEnabledProvider.future);
  if (!available || enabled || !context.mounted) return;

  final accepted =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('다음부터 지문으로 열까요?'),
          content: const Text(
            '마스터 암호 대신 지문이나 얼굴로 바로 열 수 있어요. '
            '열쇠는 이 기기 안에만 저장되고 밖으로 나가지 않아요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('나중에'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('사용할게요'),
            ),
          ],
        ),
      ) ??
      false;

  if (accepted) await ref.read(vaultProvider.notifier).enableBiometrics();
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/credential.dart';
import '../../providers/vault_providers.dart';
import 'credential_editor.dart';
import 'vault_sheets.dart';

/// 구독 상세 화면의 계정 정보 영역.
///
/// 금고 상태에 따라 세 가지 모습을 가진다.
/// 미설정 → 마스터 암호 만들기 / 잠김 → 잠금 해제 / 열림 → 내용 표시.
class CredentialSection extends ConsumerWidget {
  const CredentialSection({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vault = ref.watch(vaultProvider).value;
    final hasSaved = ref.watch(hasCredentialProvider(subscriptionId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  vault is VaultUnlocked ? Icons.lock_open : Icons.lock_outline,
                  size: 18,
                  color: theme.textTheme.labelMedium?.color,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('계정 정보', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (vault is VaultUnlocked)
                  TextButton(
                    onPressed: () => ref.read(vaultProvider.notifier).lock(),
                    child: const Text('잠그기'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            switch (vault) {
              VaultUnlocked() => _UnlockedBody(subscriptionId: subscriptionId),
              VaultLocked() => _LockedBody(hasSaved: hasSaved),
              _ => _SetupBody(subscriptionId: subscriptionId),
            },
          ],
        ),
      ),
    );
  }
}

class _SetupBody extends ConsumerWidget {
  const _SetupBody({required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '아이디와 비밀번호를 암호화해서 보관할 수 있어요. '
          '먼저 마스터 암호를 정해주세요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.labelMedium?.color,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () async {
            final done = await showVaultSetupSheet(context);
            if (done && context.mounted) {
              await showCredentialEditor(context, subscriptionId);
            }
          },
          child: const Text('마스터 암호 정하기'),
        ),
      ],
    );
  }
}

class _LockedBody extends ConsumerWidget {
  const _LockedBody({required this.hasSaved});

  final bool hasSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasSaved ? '저장된 계정 정보가 있어요.' : '아직 저장된 계정 정보가 없어요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.labelMedium?.color,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => showVaultUnlockSheet(context),
          child: const Text('잠금 해제'),
        ),
      ],
    );
  }
}

class _UnlockedBody extends ConsumerWidget {
  const _UnlockedBody({required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final credential = ref.watch(credentialProvider(subscriptionId));

    return credential.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => Text(
        '계정 정보를 불러오지 못했어요',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.negative,
        ),
      ),
      data: (value) {
        if (value == null || value.isEmpty) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showCredentialEditor(context, subscriptionId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('계정 정보 추가'),
            ),
          );
        }
        return _CredentialDetails(
          credential: value,
          subscriptionId: subscriptionId,
        );
      },
    );
  }
}

class _CredentialDetails extends StatelessWidget {
  const _CredentialDetails({
    required this.credential,
    required this.subscriptionId,
  });

  final Credential credential;
  final String subscriptionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '${credential.loginMethod.label} 로그인',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (credential.loginId.isNotEmpty)
          _SecretRow(label: '아이디', value: credential.loginId),
        if (credential.password.isNotEmpty)
          _SecretRow(label: '비밀번호', value: credential.password, masked: true),
        if (credential.memo != null && credential.memo!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(credential.memo!, style: theme.textTheme.labelMedium),
        ],
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => showCredentialEditor(context, subscriptionId),
            child: const Text('편집'),
          ),
        ),
      ],
    );
  }
}

/// 값 한 줄. 비밀번호는 기본으로 가리고, 눈 아이콘으로만 잠깐 보여준다.
class _SecretRow extends StatefulWidget {
  const _SecretRow({
    required this.label,
    required this.value,
    this.masked = false,
  });

  final String label;
  final String value;
  final bool masked;

  @override
  State<_SecretRow> createState() => _SecretRowState();
}

class _SecretRowState extends State<_SecretRow> {
  late bool _hidden = widget.masked;

  /// 복사한 비밀번호를 클립보드에 계속 두지 않는다.
  static const _clipboardLifetime = Duration(seconds: 60);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.masked
                ? '${widget.label}을(를) 복사했어요 · 1분 뒤 지워져요'
                : '${widget.label}을(를) 복사했어요',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (!widget.masked) return;

    // 다른 걸 복사했다면 건드리지 않는다. 내가 넣은 값일 때만 지운다.
    Future.delayed(_clipboardLifetime, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == widget.value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(widget.label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              _hidden ? '•' * widget.value.length.clamp(4, 12) : widget.value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.masked)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _hidden ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy, size: 16),
            onPressed: _copy,
          ),
        ],
      ),
    );
  }
}

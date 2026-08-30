import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/subscription_providers.dart';
import '../../providers/vault_providers.dart';

class ResetConfirmDialog extends ConsumerStatefulWidget {
  const ResetConfirmDialog({super.key});

  @override
  ConsumerState<ResetConfirmDialog> createState() => ResetConfirmDialogState();
}

class ResetConfirmDialogState extends ConsumerState<ResetConfirmDialog> {
  final _input = TextEditingController();

  /// 손이 미끄러져서 눌리는 일이 없도록 직접 입력하게 하는 문구.
  static const _phrase = '초기화';

  bool get _matches => _input.text.trim() == _phrase;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptions = ref.watch(allSubscriptionsProvider);
    final credentialCount =
        ref.watch(storedCredentialsProvider).value?.length ?? 0;

    return AlertDialog(
      title: const Text('모든 데이터를 지울까요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('아래 항목이 모두 사라지고 되돌릴 수 없어요.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          _Bullet('구독 ${subscriptions.length}개와 지금까지의 누적 지출 기록'),
          if (credentialCount > 0) _Bullet('저장한 계정 정보 $credentialCount개'),
          const _Bullet('마스터 암호 설정'),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "계속하려면 아래에 '$_phrase'라고 입력해주세요.",
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _input,
            autocorrect: false,
            decoration: const InputDecoration(hintText: _phrase),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.negative,
            disabledForegroundColor: theme.disabledColor,
          ),
          child: const Text('영구 삭제'),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('· '),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

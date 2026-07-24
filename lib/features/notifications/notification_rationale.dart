import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 시스템 알림 권한을 묻기 **전에** 왜 필요한지 먼저 설명한다.
///
/// 안드로이드 기본 권한 창은 "알림을 허용하시겠어요?" 한 줄뿐이라, 왜 필요한지
/// 모른 채 거절하기 쉽다. 이 앱이 알림을 쓰는 이유(결제 예정 안내)와 쓰지 않는
/// 것(광고·마케팅 없음)을 먼저 알려 안심시킨 뒤 시스템 창으로 넘어간다.
///
/// 반환값: 사용자가 계속하기를 눌렀으면 true. 이때만 시스템 권한을 요청한다.
Future<bool> showNotificationRationale(BuildContext context) async {
  final theme = Theme.of(context);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.notifications_active_outlined,
        color: AppColors.accent,
        size: 32,
      ),
      title: const Text('결제 전에 미리 알려드릴까요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '구독 결제일이 다가오면 며칠 전에 알림을 보내드려요. '
            '깜빡하고 빠져나가는 돈을 막을 수 있어요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Point(
            icon: Icons.event_available_outlined,
            text: '결제 예정일 알림만 보내요',
          ),
          const _Point(
            icon: Icons.phone_android_outlined,
            text: '알림은 이 기기에서만 만들어져요',
          ),
          const _Point(
            icon: Icons.block_outlined,
            text: '광고나 마케팅 알림은 전혀 없어요',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '다음 화면에서 "허용"을 눌러주세요. 나중에 설정에서 언제든 끌 수 있어요.',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('좋아요'),
        ),
      ],
    ),
  );

  return result ?? false;
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

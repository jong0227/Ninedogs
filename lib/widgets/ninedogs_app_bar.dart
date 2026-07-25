import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// 모든 탭에서 같은 자리에 앱 아이콘과 이름을 보여주는 앱바.
///
/// 예전엔 구독 탭에만 아이콘이 있어서 탭을 옮기면 어떤 앱인지 표시가
/// 사라졌다. 아이콘과 'Ninedogs' 를 항상 띄우고, 그 아래 작은 글씨로
/// 지금 보고 있는 화면 이름을 붙인다.
class NinedogsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NinedogsAppBar({super.key, required this.section, this.actions});

  /// 지금 화면 이름. 예: '결제 캘린더'
  final String section;

  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      toolbarHeight: kToolbarHeight + 8,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ninedogs'),
              Text(
                section,
                style: theme.textTheme.labelMedium?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      actions: actions,
    );
  }
}

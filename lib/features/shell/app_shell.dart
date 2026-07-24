import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/notification_providers.dart';
import '../../providers/subscription_providers.dart';
import '../calendar/calendar_screen.dart';
import '../home/home_screen.dart';
import '../stats/stats_screen.dart';

/// 앱의 기본 뼈대. 아래 탭으로 구독과 통계를 오간다.
///
/// [IndexedStack] 이라 탭을 옮겨도 각 화면의 스크롤 위치와 상태가 유지된다.
/// 통계를 보고 돌아왔는데 구독 목록이 맨 위로 튀면 답답하다.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();

    // 알림 권한은 앱을 처음 제대로 쓰기 시작할 때 한 번 묻는다.
    // 온보딩 도중에 물으면 뭘 위한 권한인지 알 수 없어 거절당하기 쉽다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationServiceProvider).requestPermission();
      if (mounted) _reschedule();
    });
  }

  /// 구독이나 설정이 바뀌면 예약을 전부 다시 건다.
  /// 금액·결제일이 바뀐 채로 남은 예약은 틀린 내용을 알려주게 된다.
  void _reschedule() {
    ref
        .read(notificationServiceProvider)
        .rescheduleAll(
          ref.read(allSubscriptionsProvider),
          ref.read(reminderDaysProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen(allSubscriptionsProvider, (_, _) => _reschedule());
    ref.listen(reminderDaysProvider, (_, _) => _reschedule());

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), CalendarScreen(), StatsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions, color: AppColors.accent),
            label: '구독',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppColors.accent),
            label: '캘린더',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_small_outlined),
            selectedIcon: Icon(Icons.donut_small, color: AppColors.accent),
            label: '통계',
          ),
        ],
      ),
    );
  }
}

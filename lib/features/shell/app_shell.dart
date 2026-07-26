import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/subscription_providers.dart';
import '../calendar/calendar_screen.dart';
import '../home/home_screen.dart';
import '../notifications/notification_rationale.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import 'back_exit.dart';

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
  /// 알림 권한을 물어보기 전에 왜 필요한지 설명하는 창을 한 번만 띄운다.
  static const _rationaleShownKey = 'notif_rationale_shown_v1';

  @override
  void initState() {
    super.initState();

    // 알림 권한은 앱을 처음 제대로 쓰기 시작할 때 한 번 묻는다.
    // 온보딩 도중에 물으면 뭘 위한 권한인지 알 수 없어 거절당하기 쉽다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _askNotifications());
  }

  Future<void> _askNotifications() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final service = ref.read(notificationServiceProvider);

    // 처음이라면 시스템 창 전에 이유를 먼저 설명한다. "나중에"를 고르면
    // 이번엔 시스템 창을 띄우지 않고, 설정에서 알림을 켤 때 자연히 요청된다.
    if (!(prefs.getBool(_rationaleShownKey) ?? false)) {
      await prefs.setBool(_rationaleShownKey, true);
      if (!mounted) return;
      final proceed = await showNotificationRationale(context);
      if (proceed) await service.requestPermission();
    } else {
      // 이미 설명은 봤다. 아직 결정 전이면 시스템이 창을 띄우고,
      // 이미 허용/거절했으면 아무 창도 뜨지 않는다.
      await service.requestPermission();
    }

    if (mounted) _reschedule();
  }

  /// 마지막으로 뒤로가기를 누른 시각. 두 번 눌러야 꺼지게 하는 데 쓴다.
  DateTime? _lastBackPressedAt;

  void _handleBack() {
    final action = decideBackAction(
      tabIndex: ref.read(selectedShellTabProvider),
      hasOpenDetail: ref.read(calendarSelectedDayProvider) != null,
      lastBackPressedAt: _lastBackPressedAt,
      now: DateTime.now(),
    );

    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case BackAction.closeDetail:
        ref.read(calendarSelectedDayProvider.notifier).select(null);
        // 상세를 닫은 것도 탭 전환과 마찬가지로 종료 의사가 아니다.
        _lastBackPressedAt = null;

      case BackAction.goToFirstTab:
        ref.read(selectedShellTabProvider.notifier).select(0);
        // 탭만 옮긴 것이지 종료 의사를 밝힌 게 아니다. 여기서 시각을
        // 남기면 다음 한 번에 바로 꺼져버린다.
        _lastBackPressedAt = null;

      case BackAction.warn:
        _lastBackPressedAt = DateTime.now();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('한 번 더 누르면 종료됩니다'),
            duration: Duration(seconds: 2),
          ),
        );

      case BackAction.exit:
        // 앱이 사라진 자리에 안내가 남아 있으면 어색하다.
        messenger.hideCurrentSnackBar();
        SystemNavigator.pop();
    }
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
    final index = ref.watch(selectedShellTabProvider);

    ref.listen(allSubscriptionsProvider, (_, _) => _reschedule());
    ref.listen(reminderDaysProvider, (_, _) => _reschedule());

    return PopScope(
      // 뒤로가기를 시스템에 넘기지 않고 직접 받는다. 그냥 두면 한 번에
      // 앱이 닫힌다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            CalendarScreen(),
            StatsScreen(),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) =>
              ref.read(selectedShellTabProvider.notifier).select(value),
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
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings, color: AppColors.accent),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}

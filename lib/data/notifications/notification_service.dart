import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/subscription.dart';

/// 알림을 받을 수 있는 시점들. 이 셋 중에서 고른다.
abstract final class ReminderOptions {
  static const choices = [7, 3, 1];
  static const defaults = [3];

  static String label(int days) => days == 1 ? '하루 전' : '$days일 전';
}

/// 결제 예정 알림을 예약한다.
///
/// 예약은 **다음 결제 한 번씩만** 걸어둔다. 주기마다 무한히 예약할 수는
/// 없으므로, 앱을 열 때와 구독이 바뀔 때마다 전부 다시 계산해서 건다.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  /// 알림이 뜨는 시각. 아침에 받아야 대응할 시간이 있다.
  static const _hour = 9;

  static const _channel = AndroidNotificationChannel(
    'billing_reminders',
    '결제 예정 알림',
    description: '구독 결제일이 다가오면 미리 알려줘요',
    importance: Importance.defaultImportance,
  );

  Future<void> init() async {
    if (_ready) return;

    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // 기기 시간대를 못 읽으면 서울로 둔다. 알림이 몇 시간 어긋날 뿐
      // 아예 안 오는 것보다는 낫다.
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    _ready = true;
  }

  /// 알림 권한을 요청한다. Android 13 미만은 항상 허용된 것으로 본다.
  Future<bool> requestPermission() async {
    await init();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
  }

  /// 예약을 전부 지우고 다시 건다.
  ///
  /// 금액이나 결제일이 바뀌면 기존 예약은 틀린 내용이 되므로,
  /// 부분 갱신 대신 통째로 다시 만드는 편이 안전하다.
  Future<void> rescheduleAll(
    List<Subscription> subscriptions,
    List<int> defaultDays, {
    DateTime? now,
  }) async {
    await init();
    await _plugin.cancelAll();

    final current = now ?? DateTime.now();

    for (final subscription in subscriptions) {
      if (!subscription.isActive) continue;

      // 무료 체험은 놓치면 바로 돈이 빠져나간다. 일반 결제 알림과 달리
      // 설정과 상관없이 하루 전에 한 번 더 확실히 알린다.
      await _scheduleTrialEnd(subscription, current);

      final billingDate = subscription.nextBillingDate(current);
      if (billingDate == null) continue;

      final days = subscription.effectiveReminderDays(defaultDays);
      for (final daysBefore in days) {
        final when = DateTime(
          billingDate.year,
          billingDate.month,
          billingDate.day - daysBefore,
          _hour,
        );
        // 이미 지난 시점이면 걸어봐야 즉시 뜨거나 무시된다
        if (!when.isAfter(current)) continue;

        await _schedule(subscription, daysBefore, when);
      }
    }
  }

  /// 무료 체험이 끝나기 전에 알린다.
  ///
  /// 체험이 끝나면 그 날 바로 첫 결제가 일어난다. 까먹고 넘어가면 원하지도
  /// 않는 구독료가 나가므로 **3일 전과 하루 전** 두 번 건다.
  Future<void> _scheduleTrialEnd(
    Subscription subscription,
    DateTime current,
  ) async {
    final end = subscription.trialEndsAt;
    if (end == null || !subscription.isInTrial) return;

    for (final daysBefore in _trialReminderDays) {
      final when = DateTime(end.year, end.month, end.day - daysBefore, _hour);
      if (!when.isAfter(current)) continue;

      final amount = subscription.currentPrice.format();
      await _plugin.zonedSchedule(
        id: _trialIdFor(subscription.id, daysBefore),
        title: '${subscription.name} 무료 체험이 곧 끝나요',
        body: daysBefore == 1
            ? '내일부터 $amount 결제돼요. 계속 안 쓸 거면 오늘 해지하세요'
            : '$daysBefore일 뒤부터 $amount 결제돼요',
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _schedule(
    Subscription subscription,
    int daysBefore,
    DateTime when,
  ) async {
    final amount = subscription.currentPrice.format();
    final body = daysBefore == 1
        ? '내일 $amount 결제돼요'
        : '$daysBefore일 뒤 $amount 결제돼요';

    await _plugin.zonedSchedule(
      id: _idFor(subscription.id, daysBefore),
      title: subscription.name,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // 정확한 알람은 Android 12+ 에서 별도 권한이 필요하다.
      // 결제 알림은 몇 분 늦어도 상관없으니 권한 없이 되는 쪽을 쓴다.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// 무료 체험 종료를 알릴 시점들.
  static const _trialReminderDays = [3, 1];

  /// 구독 id 와 며칠 전인지로 예약 번호를 만든다.
  /// 같은 구독의 7일 전과 1일 전이 서로 덮어쓰지 않아야 한다.
  static int _idFor(String subscriptionId, int daysBefore) {
    final base = subscriptionId.hashCode & 0x00FFFFFF;
    return base * 10 + daysBefore % 10;
  }

  /// 체험 종료 알림용 예약 번호.
  ///
  /// 결제 알림([_idFor])과 겹치면 서로 덮어쓴다. 앞자리를 음수로 갈라
  /// 같은 구독의 '3일 전 결제'와 '3일 전 체험 종료'가 공존하게 한다.
  static int _trialIdFor(String subscriptionId, int daysBefore) =>
      -_idFor(subscriptionId, daysBefore);
}

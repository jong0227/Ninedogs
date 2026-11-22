import 'dart:ui';

import '../../core/theme/app_colors.dart';

/// 구독의 주인이 될 수 있는 사람들. 부부 두 칸(`a`, `b`)으로 고정한다.
///
/// 칸이 고정이라 색도 칸에 붙는다(a=파랑, b=빨강 계열). 이름만 바꿀 수 있다.
/// 공동·미지정 구독은 [Subscription.owner] 가 null 이다.
class People {
  const People({required this.names});

  static const slots = ['a', 'b'];
  static const defaults = People(names: {'a': '나', 'b': '배우자'});

  final Map<String, String> names;

  String nameOf(String key) => names[key] ?? defaults.names[key] ?? key;

  static Color colorOf(String key) =>
      key == 'b' ? AppColors.personB : AppColors.personA;

  People withName(String key, String name) =>
      People(names: {...names, key: name.trim()});

  Map<String, Object?> toJson() => {'names': names};

  factory People.fromJson(Map<String, Object?>? json) {
    final raw = json?['names'];
    if (raw is! Map) return defaults;
    final names = <String, String>{...defaults.names};
    for (final key in slots) {
      final value = raw[key];
      if (value is String && value.trim().isNotEmpty) names[key] = value.trim();
    }
    return People(names: names);
  }
}

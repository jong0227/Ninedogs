import 'package:flutter/material.dart';

import '../../data/catalog/catalog_service.dart';

/// 분야별 색.
///
/// 순위가 아니라 **분야에 고정**이다. 영상은 언제나 빨강, 음악은 언제나
/// 초록이라 화면을 다시 열어도 같은 색으로 읽힌다.
///
/// 톤을 맞춘 이유: 다들 채도가 비슷한 중간 밝기라 검정 배경에서도, 흰
/// 배경에서도 묻히지 않는다. 하나만 쨍하면 그 분야가 실제보다 커 보인다.
abstract final class CategoryColors {
  static const _palette = <ServiceCategory, Color>{
    // 영상은 브랜드 색과 같은 빨강. 가장 지출이 큰 분야일 때가 많고,
    // 앱 강조색과 이어져서 자연스럽다.
    ServiceCategory.video: Color(0xFFE5484D),
    ServiceCategory.music: Color(0xFF35C08E),
    ServiceCategory.membership: Color(0xFFF2A93B),
    ServiceCategory.productivity: Color(0xFF5B8DEF),
    ServiceCategory.cloud: Color(0xFF3FC8D9),
    ServiceCategory.reading: Color(0xFFA97BE8),
    ServiceCategory.gaming: Color(0xFFF2725C),
    ServiceCategory.mobility: Color(0xFF8A93A6),
  };

  /// 카탈로그에 없는 서비스(기타)는 무채색으로 둔다.
  /// 색을 주면 실제 분야처럼 보인다.
  static const _other = Color(0xFF6E7480);

  static Color of(ServiceCategory? category) =>
      category == null ? _other : _palette[category] ?? _other;
}

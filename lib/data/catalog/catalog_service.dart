import '../models/billing_cycle.dart';
import '../models/money.dart';

enum ServiceCategory {
  video('영상'),
  music('음악'),
  membership('쇼핑·멤버십'),
  productivity('AI·생산성'),
  cloud('클라우드'),
  reading('독서·콘텐츠'),
  gaming('게임'),
  mobility('자동차·기기');

  const ServiceCategory(this.label);
  final String label;
}

/// 서비스의 요금제. 온보딩에서 탭 한 번으로 고를 수 있게 미리 담아둔다.
class CatalogPlan {
  const CatalogPlan(this.name, this.priceKrw, {this.cycle = BillingCycle.monthly});

  final String name;

  /// 참고용 기본값(원). 실제 청구액은 사용자가 확인·수정한다.
  final int priceKrw;
  final BillingCycle cycle;

  Money get price => Money(priceKrw);
}

/// 앱에 미리 담아둔 인기 구독 서비스.
class CatalogService {
  const CatalogService({
    required this.id,
    required this.name,
    required this.category,
    required this.brandColor,
    required this.plans,
    String? searchTerm,
  }) : searchTerm = searchTerm ?? name;

  final String id;
  final String name;

  /// 앱스토어에서 아이콘을 찾을 때 쓰는 검색어.
  final String searchTerm;
  final ServiceCategory category;

  /// 아이콘을 못 불러왔을 때 쓰는 대체 타일 색상 (ARGB).
  final int brandColor;

  final List<CatalogPlan> plans;

  CatalogPlan get defaultPlan => plans.first;
}

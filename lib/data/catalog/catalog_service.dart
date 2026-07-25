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
    this.includedIn,
    this.pickerHint,
  }) : searchTerm = searchTerm ?? name;

  final String id;
  final String name;

  /// 앱스토어에서 아이콘을 찾을 때 쓰는 검색어.
  final String searchTerm;
  final ServiceCategory category;

  /// 아이콘을 못 불러왔을 때 쓰는 대체 타일 색상 (ARGB).
  final int brandColor;

  final List<CatalogPlan> plans;

  /// 이 서비스를 혜택으로 끼워주는 상위 상품의 id.
  ///
  /// 쿠팡플레이는 와우 멤버십에, Apple Music 은 Apple One 에 딸려온다.
  /// 둘 다 제값으로 등록하면 실제로 내지 않는 돈이 합계에 잡힌다.
  /// 이 값이 있으면 추가할 때 상위 상품을 이미 등록했는지 확인해 안내한다.
  final String? includedIn;

  /// 서비스를 고를 때 헷갈릴 만한 점을 짚어주는 짧은 안내.
  ///
  /// 예: 쿠팡플레이는 스포츠패스가 별도 서비스가 아니라 요금제 중 하나라는 걸
  /// 모르면 따로 찾다가 못 찾을 수 있다. 그리드 타일의 (?) 아이콘을 눌렀을
  /// 때만 보여준다. 없으면 아이콘 자체를 안 그린다.
  final String? pickerHint;

  CatalogPlan get defaultPlan => plans.first;
}

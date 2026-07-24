import '../models/billing_cycle.dart';
import 'catalog_service.dart';

/// 온보딩과 구독 추가 화면에서 쓰는 기본 서비스 목록.
///
/// 가격은 사용자가 빠르게 시작하도록 넣어둔 **참고용 기본값**이다.
/// 실제 청구액은 계정마다 다르므로 화면에서 항상 수정할 수 있게 노출한다.
abstract final class ServiceCatalog {
  static const List<CatalogService> all = [
    // ── 영상 ─────────────────────────────────────────────
    CatalogService(
      id: 'netflix',
      name: '넷플릭스',
      searchTerm: 'Netflix',
      category: ServiceCategory.video,
      brandColor: 0xFFE50914,
      plans: [
        CatalogPlan('광고형 스탠다드', 5500),
        CatalogPlan('스탠다드', 13500),
        CatalogPlan('프리미엄', 17000),
      ],
    ),
    CatalogService(
      id: 'youtube_premium',
      name: '유튜브 프리미엄',
      searchTerm: 'YouTube',
      category: ServiceCategory.video,
      brandColor: 0xFFFF0000,
      plans: [
        CatalogPlan('개인', 14900),
        CatalogPlan('가족', 31900),
      ],
    ),
    CatalogService(
      id: 'disney_plus',
      name: '디즈니+',
      searchTerm: 'Disney+',
      category: ServiceCategory.video,
      brandColor: 0xFF113CCF,
      plans: [CatalogPlan('스탠다드', 9900), CatalogPlan('프리미엄', 13900)],
    ),
    CatalogService(
      id: 'tving',
      name: '티빙',
      searchTerm: 'TVING 티빙',
      category: ServiceCategory.video,
      brandColor: 0xFFFF153C,
      plans: [
        CatalogPlan('광고형 스탠다드', 5500),
        CatalogPlan('스탠다드', 13500),
        CatalogPlan('프리미엄', 17000),
      ],
    ),
    CatalogService(
      id: 'wavve',
      name: '웨이브',
      searchTerm: 'wavve 웨이브',
      category: ServiceCategory.video,
      brandColor: 0xFF1351F9,
      plans: [CatalogPlan('베이직', 7900), CatalogPlan('스탠다드', 10900)],
    ),
    CatalogService(
      id: 'coupang_play',
      name: '쿠팡플레이',
      searchTerm: '쿠팡플레이',
      category: ServiceCategory.video,
      brandColor: 0xFF00A4E4,
      plans: [CatalogPlan('와우 회원 포함', 7890)],
    ),
    CatalogService(
      id: 'watcha',
      name: '왓챠',
      searchTerm: 'WATCHA 왓챠',
      category: ServiceCategory.video,
      brandColor: 0xFFFF0558,
      plans: [CatalogPlan('베이직', 7900), CatalogPlan('프리미엄', 12900)],
    ),
    CatalogService(
      id: 'laftel',
      name: '라프텔',
      searchTerm: '라프텔',
      category: ServiceCategory.video,
      brandColor: 0xFF6C3DF4,
      plans: [CatalogPlan('베이직', 9900)],
    ),
    CatalogService(
      id: 'apple_tv',
      name: 'Apple TV+',
      searchTerm: 'Apple TV',
      category: ServiceCategory.video,
      brandColor: 0xFF1B1B1B,
      plans: [CatalogPlan('개인', 6500)],
    ),

    // ── 음악 ─────────────────────────────────────────────
    CatalogService(
      id: 'spotify',
      name: '스포티파이',
      searchTerm: 'Spotify',
      category: ServiceCategory.music,
      brandColor: 0xFF1DB954,
      plans: [
        CatalogPlan('개인', 10900),
        CatalogPlan('듀오', 16350),
        CatalogPlan('가족', 17000),
      ],
    ),
    CatalogService(
      id: 'melon',
      name: '멜론',
      searchTerm: 'Melon 멜론',
      category: ServiceCategory.music,
      brandColor: 0xFF00CD3C,
      plans: [CatalogPlan('스트리밍 클럽', 10900)],
    ),
    CatalogService(
      id: 'apple_music',
      name: 'Apple Music',
      searchTerm: 'Apple Music',
      category: ServiceCategory.music,
      brandColor: 0xFFFA243C,
      plans: [CatalogPlan('개인', 8900), CatalogPlan('가족', 13500)],
    ),
    CatalogService(
      id: 'genie',
      name: '지니뮤직',
      searchTerm: '지니뮤직',
      category: ServiceCategory.music,
      brandColor: 0xFF3A6DF0,
      plans: [CatalogPlan('무제한 듣기', 10900)],
    ),
    CatalogService(
      id: 'flo',
      name: 'FLO',
      searchTerm: 'FLO 플로 음악',
      category: ServiceCategory.music,
      brandColor: 0xFF3F19DA,
      plans: [CatalogPlan('무제한 듣기', 8900)],
    ),
    CatalogService(
      id: 'vibe',
      name: '바이브',
      searchTerm: 'NAVER VIBE 바이브',
      category: ServiceCategory.music,
      brandColor: 0xFF6E43F5,
      plans: [CatalogPlan('무제한 듣기', 8500)],
    ),

    // ── 쇼핑·멤버십 ───────────────────────────────────────
    CatalogService(
      id: 'coupang_wow',
      name: '쿠팡 와우',
      searchTerm: '쿠팡 Coupang',
      category: ServiceCategory.membership,
      brandColor: 0xFFE52528,
      plans: [CatalogPlan('와우 멤버십', 7890)],
    ),
    CatalogService(
      id: 'naver_plus',
      name: '네이버플러스 멤버십',
      searchTerm: '네이버 NAVER',
      category: ServiceCategory.membership,
      brandColor: 0xFF03C75A,
      plans: [
        CatalogPlan('월간', 4900),
        CatalogPlan('연간', 46800, cycle: BillingCycle.yearly),
      ],
    ),
    CatalogService(
      id: 'baemin_club',
      name: '배민클럽',
      searchTerm: '배달의민족',
      category: ServiceCategory.membership,
      brandColor: 0xFF2AC1BC,
      plans: [CatalogPlan('배민클럽', 3990)],
    ),
    CatalogService(
      id: 'kurly_members',
      name: '컬리멤버스',
      searchTerm: '마켓컬리',
      category: ServiceCategory.membership,
      brandColor: 0xFF5F0080,
      plans: [CatalogPlan('컬리멤버스', 1900)],
    ),
    CatalogService(
      id: 'smile_club',
      name: '스마일클럽',
      searchTerm: 'G마켓',
      category: ServiceCategory.membership,
      brandColor: 0xFF00A66C,
      plans: [CatalogPlan('연간', 30000, cycle: BillingCycle.yearly)],
    ),

    // ── AI·생산성 ─────────────────────────────────────────
    CatalogService(
      id: 'chatgpt',
      name: 'ChatGPT',
      searchTerm: 'ChatGPT',
      category: ServiceCategory.productivity,
      brandColor: 0xFF10A37F,
      plans: [CatalogPlan('Plus', 29000), CatalogPlan('Pro', 290000)],
    ),
    CatalogService(
      id: 'claude',
      name: 'Claude',
      searchTerm: 'Claude by Anthropic',
      category: ServiceCategory.productivity,
      brandColor: 0xFFD97757,
      plans: [CatalogPlan('Pro', 29000), CatalogPlan('Max', 145000)],
    ),
    CatalogService(
      id: 'perplexity',
      name: 'Perplexity',
      searchTerm: 'Perplexity AI',
      category: ServiceCategory.productivity,
      brandColor: 0xFF20808D,
      plans: [CatalogPlan('Pro', 29000)],
    ),
    CatalogService(
      id: 'notion',
      name: 'Notion',
      searchTerm: 'Notion',
      category: ServiceCategory.productivity,
      brandColor: 0xFF000000,
      plans: [CatalogPlan('Plus', 14000), CatalogPlan('Business', 26000)],
    ),
    CatalogService(
      id: 'github_copilot',
      name: 'GitHub Copilot',
      searchTerm: 'GitHub',
      category: ServiceCategory.productivity,
      brandColor: 0xFF24292E,
      plans: [CatalogPlan('Individual', 14000)],
    ),
    CatalogService(
      id: 'figma',
      name: 'Figma',
      searchTerm: 'Figma',
      category: ServiceCategory.productivity,
      brandColor: 0xFFF24E1E,
      plans: [CatalogPlan('Professional', 20000)],
    ),
    CatalogService(
      id: 'adobe_cc',
      name: 'Adobe Creative Cloud',
      searchTerm: 'Adobe Creative Cloud',
      category: ServiceCategory.productivity,
      brandColor: 0xFFFA0F00,
      plans: [CatalogPlan('모든 앱', 68000), CatalogPlan('단일 앱', 24000)],
    ),
    CatalogService(
      id: 'microsoft_365',
      name: 'Microsoft 365',
      searchTerm: 'Microsoft 365',
      category: ServiceCategory.productivity,
      brandColor: 0xFF0078D4,
      plans: [
        CatalogPlan('개인', 8900),
        CatalogPlan('가족', 11900),
      ],
    ),

    // ── 클라우드 ──────────────────────────────────────────
    CatalogService(
      id: 'icloud',
      name: 'iCloud+',
      searchTerm: 'iCloud',
      category: ServiceCategory.cloud,
      brandColor: 0xFF3693F3,
      plans: [
        CatalogPlan('50GB', 1100),
        CatalogPlan('200GB', 3300),
        CatalogPlan('2TB', 11100),
      ],
    ),
    CatalogService(
      id: 'google_one',
      name: 'Google One',
      searchTerm: 'Google One',
      category: ServiceCategory.cloud,
      brandColor: 0xFF4285F4,
      plans: [
        CatalogPlan('100GB', 2400),
        CatalogPlan('200GB', 3700),
        CatalogPlan('2TB', 11900),
      ],
    ),
    CatalogService(
      id: 'dropbox',
      name: 'Dropbox',
      searchTerm: 'Dropbox',
      category: ServiceCategory.cloud,
      brandColor: 0xFF0061FF,
      plans: [CatalogPlan('Plus', 15000)],
    ),

    // ── 독서·콘텐츠 ───────────────────────────────────────
    CatalogService(
      id: 'millie',
      name: '밀리의서재',
      searchTerm: '밀리의 서재',
      category: ServiceCategory.reading,
      brandColor: 0xFF4B48D6,
      plans: [
        CatalogPlan('월간', 9900),
        CatalogPlan('연간', 99000, cycle: BillingCycle.yearly),
      ],
    ),
    CatalogService(
      id: 'ridi_select',
      name: '리디셀렉트',
      searchTerm: '리디 RIDI',
      category: ServiceCategory.reading,
      brandColor: 0xFF1F8CE6,
      plans: [CatalogPlan('월간', 9900)],
    ),
    CatalogService(
      id: 'welaaa',
      name: '윌라',
      searchTerm: '윌라 오디오북',
      category: ServiceCategory.reading,
      brandColor: 0xFFFF5A3D,
      plans: [CatalogPlan('오디오북 무제한', 9900)],
    ),

    // ── 게임 ─────────────────────────────────────────────
    CatalogService(
      id: 'xbox_game_pass',
      name: 'Xbox Game Pass',
      searchTerm: 'Xbox',
      category: ServiceCategory.gaming,
      brandColor: 0xFF107C10,
      plans: [CatalogPlan('Ultimate', 16700)],
    ),
    CatalogService(
      id: 'playstation_plus',
      name: 'PlayStation Plus',
      searchTerm: 'PlayStation App',
      category: ServiceCategory.gaming,
      brandColor: 0xFF0070D1,
      plans: [CatalogPlan('에센셜', 8900), CatalogPlan('디럭스', 14400)],
    ),
    CatalogService(
      id: 'nintendo_online',
      name: 'Nintendo Switch Online',
      searchTerm: 'Nintendo Switch Online',
      category: ServiceCategory.gaming,
      brandColor: 0xFFE60012,
      plans: [
        CatalogPlan('개인 (연간)', 19900, cycle: BillingCycle.yearly),
      ],
    ),
  ];

  static final Map<String, CatalogService> _byId = {
    for (final service in all) service.id: service,
  };

  static CatalogService? byId(String id) => _byId[id];

  static List<CatalogService> byCategory(ServiceCategory category) =>
      all.where((s) => s.category == category).toList();

  /// 온보딩 그리드용. 카테고리 순서대로 묶어서 돌려준다.
  static Map<ServiceCategory, List<CatalogService>> get grouped => {
    for (final category in ServiceCategory.values)
      category: byCategory(category),
  };

  static List<CatalogService> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.searchTerm.toLowerCase().contains(q) ||
              s.id.contains(q),
        )
        .toList();
  }
}

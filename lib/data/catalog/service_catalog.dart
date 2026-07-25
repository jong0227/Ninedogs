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
      // 와우 멤버십 회원이면 추가 결제 없이 본다. 기본을 0원으로 두지 않으면
      // 와우와 쿠팡플레이를 모두 등록했을 때 월 7,890원이 두 번 잡힌다.
      includedIn: 'coupang_wow',
      plans: [
        CatalogPlan('와우 멤버십에 포함 (추가 결제 없음)', 0),
        CatalogPlan('따로 결제', 7890),
      ],
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
      includedIn: 'apple_one',
      plans: [
        CatalogPlan('개인', 6500),
        CatalogPlan('Apple One에 포함 (추가 결제 없음)', 0),
      ],
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
      // 단독 가입이 흔해서 기본은 '개인'으로 두고, Apple One 을 이미 등록한
      // 사람에게만 0원 요금제를 권한다.
      includedIn: 'apple_one',
      plans: [
        CatalogPlan('개인', 8900),
        CatalogPlan('가족', 13500),
        CatalogPlan('Apple One에 포함 (추가 결제 없음)', 0),
      ],
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
    CatalogService(
      id: 'geforce_now',
      name: 'GeForce NOW',
      searchTerm: 'GeForce NOW',
      category: ServiceCategory.gaming,
      brandColor: 0xFF76B900,
      plans: [CatalogPlan('프리미엄', 19900), CatalogPlan('얼티밋', 29900)],
    ),

    // ── 자동차·기기 ───────────────────────────────────────
    CatalogService(
      id: 'tesla_fsd',
      name: 'Tesla FSD',
      searchTerm: 'Tesla',
      category: ServiceCategory.mobility,
      brandColor: 0xFFCC0000,
      plans: [CatalogPlan('FSD 구독', 99000)],
    ),
    CatalogService(
      id: 'tesla_connectivity',
      name: '테슬라 프리미엄 커넥티비티',
      searchTerm: 'Tesla',
      category: ServiceCategory.mobility,
      brandColor: 0xFFCC0000,
      plans: [
        CatalogPlan('월간', 9900),
        CatalogPlan('연간', 99000, cycle: BillingCycle.yearly),
      ],
    ),
    CatalogService(
      id: 'hyundai_bluelink',
      name: '현대 블루링크',
      searchTerm: '블루링크',
      category: ServiceCategory.mobility,
      brandColor: 0xFF002C5F,
      plans: [CatalogPlan('스탠다드', 9900)],
    ),
    CatalogService(
      id: 'kia_connect',
      name: '기아 커넥트',
      searchTerm: '기아 커넥트',
      category: ServiceCategory.mobility,
      brandColor: 0xFF05141F,
      plans: [CatalogPlan('스탠다드', 9900)],
    ),
    CatalogService(
      id: 'applecare',
      name: 'AppleCare+',
      searchTerm: 'Apple Support',
      category: ServiceCategory.mobility,
      brandColor: 0xFF555555,
      plans: [CatalogPlan('iPhone', 6900), CatalogPlan('Mac', 12900)],
    ),

    // ── 추가 영상·멤버십 ──────────────────────────────────
    CatalogService(
      id: 'amazon_prime',
      name: 'Amazon Prime Video',
      searchTerm: 'Amazon Prime Video',
      category: ServiceCategory.video,
      brandColor: 0xFF00A8E1,
      plans: [CatalogPlan('프라임 비디오', 5500)],
    ),
    CatalogService(
      id: 'apple_one',
      name: 'Apple One',
      searchTerm: 'Apple One',
      category: ServiceCategory.membership,
      brandColor: 0xFF333333,
      plans: [CatalogPlan('개인', 12900), CatalogPlan('가족', 19900)],
    ),

    // ── 추가 AI·생산성 ────────────────────────────────────
    CatalogService(
      id: 'google_ai_pro',
      name: 'Google AI Pro',
      searchTerm: 'Google Gemini',
      category: ServiceCategory.productivity,
      brandColor: 0xFF4285F4,
      plans: [CatalogPlan('AI Pro', 29000)],
    ),
    CatalogService(
      id: 'cursor',
      name: 'Cursor',
      searchTerm: 'Cursor AI code editor',
      category: ServiceCategory.productivity,
      brandColor: 0xFF2E2E2E,
      plans: [CatalogPlan('Pro', 29000)],
    ),
    CatalogService(
      id: 'midjourney',
      name: 'Midjourney',
      searchTerm: 'Midjourney',
      category: ServiceCategory.productivity,
      brandColor: 0xFF1B1B2F,
      plans: [CatalogPlan('Basic', 14000), CatalogPlan('Standard', 42000)],
    ),
    CatalogService(
      id: 'canva',
      name: 'Canva',
      searchTerm: 'Canva',
      category: ServiceCategory.productivity,
      brandColor: 0xFF00C4CC,
      plans: [CatalogPlan('Pro', 13000)],
    ),
    CatalogService(
      id: 'slack',
      name: 'Slack',
      searchTerm: 'Slack',
      category: ServiceCategory.productivity,
      brandColor: 0xFF4A154B,
      plans: [CatalogPlan('Pro', 11000)],
    ),
    CatalogService(
      id: 'onepassword',
      name: '1Password',
      searchTerm: '1Password',
      category: ServiceCategory.productivity,
      brandColor: 0xFF0572EC,
      plans: [CatalogPlan('개인', 4500), CatalogPlan('가족', 7500)],
    ),
    CatalogService(
      id: 'nordvpn',
      name: 'NordVPN',
      searchTerm: 'NordVPN',
      category: ServiceCategory.productivity,
      brandColor: 0xFF4687FF,
      plans: [CatalogPlan('스탠다드', 6500)],
    ),

    // ── 추가 독서·콘텐츠 ──────────────────────────────────
    CatalogService(
      id: 'kakao_page',
      name: '카카오페이지',
      searchTerm: '카카오페이지',
      category: ServiceCategory.reading,
      brandColor: 0xFFFFCD00,
      plans: [CatalogPlan('이용권', 9900)],
    ),
    CatalogService(
      id: 'naver_webtoon',
      name: '네이버웹툰',
      searchTerm: '네이버 웹툰',
      category: ServiceCategory.reading,
      brandColor: 0xFF00DC64,
      plans: [CatalogPlan('쿠키오븐', 9900)],
    ),
    CatalogService(
      id: 'longblack',
      name: '롱블랙',
      searchTerm: '롱블랙',
      category: ServiceCategory.reading,
      brandColor: 0xFF1A1A1A,
      plans: [
        CatalogPlan('연간', 120000, cycle: BillingCycle.yearly),
      ],
    ),
    CatalogService(
      id: 'class101',
      name: '클래스101',
      searchTerm: '클래스101',
      category: ServiceCategory.reading,
      brandColor: 0xFFFF5C35,
      plans: [CatalogPlan('멤버십', 19900)],
    ),
    CatalogService(
      id: 'duolingo',
      name: 'Duolingo',
      searchTerm: 'Duolingo',
      category: ServiceCategory.reading,
      brandColor: 0xFF58CC02,
      plans: [CatalogPlan('Super', 9900)],
    ),
    CatalogService(
      id: 'speak',
      name: '스픽',
      searchTerm: '스픽 Speak 영어',
      category: ServiceCategory.reading,
      brandColor: 0xFF6B4EFF,
      plans: [
        CatalogPlan('프리미엄 월간', 19900),
        CatalogPlan('프리미엄 연간', 119000, cycle: BillingCycle.yearly),
      ],
    ),
  ];

  /// 서비스별 안드로이드 패키지명.
  ///
  /// "안 쓰는 구독 찾기"에서 폰 사용 기록을 볼 때 쓴다.
  /// **앱으로 쓰는 것이 곧 이용인 서비스만** 넣는다. 쇼핑 멤버십(쿠팡 와우,
  /// 네이버플러스)이나 주로 PC 로 쓰는 것(Adobe, Figma)은 앱을 안 열어도
  /// 잘 쓰고 있는 경우가 많아 일부러 뺐다. 여기 없는 서비스는 사용 기록을
  /// 아예 보지 않는다.
  ///
  /// 여기 있는 값은 **전부 확인을 거쳤다.** 실기기에 깔린 것은 APK 의 앱
  /// 이름까지 읽어(`aapt2 dump badging`) 대조했고, 나머지는 Google Play 주소의
  /// `details?id=` 값으로 확인했다. Play 주소에 패키지명이 그대로 들어가므로
  /// 기기가 없어도 확인할 수 있다.
  ///
  /// 확인하면서 실제로 잡아낸 것들:
  /// - 왓챠는 `com.frograms.wplay` 다. `com.frograms.watcha` 는 앱 이름이
  ///   'WATCHA PEDIA' 인 평점 앱이라 구독과 상관없다. 같은 회사라 헷갈린다.
  /// - 라프텔은 `net.laftel` 이 아니라 `laftel.net.laftel` 이다.
  /// - Apple TV+ 는 폰용 패키지명을 확정하지 못해 아예 뺐다.
  ///
  /// 틀린 패키지명은 조회 결과에 안 잡힐 뿐이라(=아무 말도 안 함) 잘못된
  /// 안내로 이어지지는 않는다. 그래도 확실하지 않으면 넣지 않는 편이 낫다.
  static const androidPackages = <String, String>{
    'netflix': 'com.netflix.mediaclient',
    'youtube_premium': 'com.google.android.youtube',
    'disney_plus': 'com.disney.disneyplus',
    'tving': 'net.cj.cjhv.gs.tving',
    'wavve': 'kr.co.captv.pooqV2', // 웨이브 (옛 POOQ 패키지를 그대로 쓴다)
    'coupang_play': 'com.coupang.mobile.play',
    // 왓챠(스트리밍)는 wplay 다. com.frograms.watcha 는 앱 이름이
    // 'WATCHA PEDIA' 인 평점·리뷰 앱이라 구독과 상관없다. 같은 회사라 헷갈린다.
    'watcha': 'com.frograms.wplay',
    'laftel': 'laftel.net.laftel',
    // apple_tv 는 뺐다. com.apple.atve.androidtv.appletv 는 안드로이드 TV
    // 전용이라 폰에는 깔리지 않는다. 폰용 패키지명을 확인하지 못해, 틀린 값을
    // 두느니 아예 조회하지 않는 쪽을 골랐다.
    'amazon_prime': 'com.amazon.avod.thirdpartyclient',
    'spotify': 'com.spotify.music',
    'melon': 'com.iloen.melon',
    'apple_music': 'com.apple.android.music',
    'genie': 'com.ktmusic.geniemusic',
    'flo': 'skplanet.musicmate',
    'vibe': 'com.naver.vibe',
    'millie': 'kr.co.millie.millieshelf',
    'ridibooks': 'com.initialcoms.ridi',
    'yes24_ebook': 'com.yes24.ebook.fourth',
    'kakaopage': 'com.kakao.page',
    'naver_webtoon': 'com.nhn.android.webtoon',
    'chatgpt': 'com.openai.chatgpt',
    'claude': 'com.anthropic.claude',
    'perplexity': 'ai.perplexity.app.android',
    'notion': 'notion.id',
  };

  /// 사용 기록을 볼 수 있는 서비스인지. 없으면 null.
  static String? packageOf(String? serviceId) =>
      serviceId == null ? null : androidPackages[serviceId];

  /// 서비스별 대표 도메인.
  ///
  /// App Store 검색이 실패했을 때 파비콘으로 로고를 가져오는 데 쓴다.
  /// 첫 글자만 덩그러니 보여주는 것보다 훨씬 알아보기 쉽다.
  static const domains = <String, String>{
    'netflix': 'netflix.com',
    'youtube_premium': 'youtube.com',
    'disney_plus': 'disneyplus.com',
    'tving': 'tving.com',
    'wavve': 'wavve.com',
    'coupang_play': 'coupangplay.com',
    'watcha': 'watcha.com',
    'laftel': 'laftel.net',
    'apple_tv': 'tv.apple.com',
    'amazon_prime': 'primevideo.com',
    'spotify': 'spotify.com',
    'melon': 'melon.com',
    'apple_music': 'music.apple.com',
    'genie': 'genie.co.kr',
    'flo': 'music-flo.com',
    'vibe': 'vibe.naver.com',
    'coupang_wow': 'coupang.com',
    'naver_plus': 'naver.com',
    'baemin_club': 'baemin.com',
    'kurly_members': 'kurly.com',
    'smile_club': 'gmarket.co.kr',
    'apple_one': 'apple.com',
    'chatgpt': 'openai.com',
    'claude': 'claude.ai',
    'perplexity': 'perplexity.ai',
    'notion': 'notion.so',
    'github_copilot': 'github.com',
    'figma': 'figma.com',
    'adobe_cc': 'adobe.com',
    'microsoft_365': 'microsoft.com',
    'google_ai_pro': 'gemini.google.com',
    'cursor': 'cursor.com',
    'midjourney': 'midjourney.com',
    'canva': 'canva.com',
    'slack': 'slack.com',
    'onepassword': '1password.com',
    'nordvpn': 'nordvpn.com',
    'icloud': 'icloud.com',
    'google_one': 'one.google.com',
    'dropbox': 'dropbox.com',
    'millie': 'millie.co.kr',
    'ridi_select': 'ridibooks.com',
    'welaaa': 'welaaa.com',
    'kakao_page': 'page.kakao.com',
    'naver_webtoon': 'comic.naver.com',
    'longblack': 'longblack.co',
    'class101': 'class101.net',
    'duolingo': 'duolingo.com',
    'speak': 'speak.com',
    'xbox_game_pass': 'xbox.com',
    'playstation_plus': 'playstation.com',
    'nintendo_online': 'nintendo.co.kr',
    'geforce_now': 'nvidia.com',
    'tesla_fsd': 'tesla.com',
    'tesla_connectivity': 'tesla.com',
    'hyundai_bluelink': 'hyundai.com',
    'kia_connect': 'kia.com',
    'applecare': 'apple.com',
  };

  static String? domainOf(String? serviceId) =>
      serviceId == null ? null : domains[serviceId];

  static final Map<String, CatalogService> _byId = {
    for (final service in all) service.id: service,
  };

  static CatalogService? byId(String id) => _byId[id];

  /// [service] 를 혜택으로 끼워주는 상위 상품. 묶여 있지 않으면 null.
  static CatalogService? parentOf(CatalogService service) {
    final parentId = service.includedIn;
    return parentId == null ? null : byId(parentId);
  }

  /// 상위 상품에 포함될 때 고르는 0원 요금제. 없으면 null.
  ///
  /// 상위 상품을 이미 등록한 사람에게 이 요금제를 권해서, 실제로 내지 않는
  /// 돈이 합계에 잡히지 않게 한다.
  static CatalogPlan? includedPlanOf(CatalogService service) {
    for (final plan in service.plans) {
      if (plan.priceKrw == 0) return plan;
    }
    return null;
  }

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

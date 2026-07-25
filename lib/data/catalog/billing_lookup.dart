/// 서비스별로 "내가 언제부터 구독했는지" 알아내는 방법.
///
/// 가입일을 기억하는 사람은 거의 없다. 대부분 각 서비스의 결제 내역에서
/// 가장 오래된 항목을 보고 역추적해야 하는데, 그 화면이 어디 있는지도
/// 서비스마다 다르다. 그 경로를 대신 알려준다.
///
/// 여기 적힌 경로와 URL은 공식 도움말에서 확인한 것만 넣는다. 확인되지
/// 않은 딥링크는 넣지 않고 [url] 을 비워 로그인 홈으로만 보낸다 —
/// 죽은 링크로 보내는 게 안내가 없는 것보다 나쁘다.
class BillingLookup {
  const BillingLookup({
    required this.path,
    this.url,
    required this.historyRange,
    this.caveat,
  });

  /// 어디를 눌러야 하는지. 예: '계정 → 멤버십 → 결제 내역'
  final String path;

  /// 결제 내역 페이지로 바로 가는 주소. 공식 문서로 확인된 것만 넣는다.
  final String? url;

  /// 과거 결제를 얼마나 거슬러 볼 수 있는지. 보존 기간이 짧으면
  /// 결제 내역만으로는 최초 가입일을 알 수 없어서 미리 알려줘야 한다.
  final String historyRange;

  /// 결제 경로가 갈리는 경우 등의 예외. 없으면 null.
  final String? caveat;
}

/// 확인된 서비스만 담는다. 없는 서비스는 서비스 홈으로 보낸다.
const billingLookups = <String, BillingLookup>{
  'netflix': BillingLookup(
    path: '계정 → 멤버십 → 결제 내역',
    url: 'https://www.netflix.com/billingactivity',
    historyRange: '최근 1년',
    caveat: '1년보다 오래된 결제는 카드사 명세서나 가입 확인 메일을 찾아보세요.',
  ),
  'youtube_premium': BillingLookup(
    path: '프로필 → 유료 멤버십 → 결제 내역',
    url: 'https://www.youtube.com/paid_memberships',
    historyRange: '전체 (Google Pay 활동에서)',
    caveat: 'Apple로 가입했다면 Apple 구독에서 확인해야 해요.',
  ),
  'disney_plus': BillingLookup(
    path: '계정 → 청구 내역',
    url: 'https://www.disneyplus.com/commerce/billing-history',
    historyRange: '최근 2년',
    caveat: '청구 내역이 비어 있다면 앱스토어나 통신사로 결제한 거예요.',
  ),
  'watcha': BillingLookup(
    path: '나의 왓챠 → 결제 수단 관리',
    url: 'https://watcha.com/my',
    historyRange: '다음 결제일 위주',
    caveat: '결제 정보는 PC 웹에서만 보여요.',
  ),
  'coupang_play': BillingLookup(
    path: '쿠팡 앱 → 마이쿠팡 → 와우 멤버십',
    historyRange: '다음 결제 예정일만',
    caveat: '쿠팡플레이 가입일은 와우 멤버십 시작일과 같아요.',
  ),
  'wavve': BillingLookup(
    path: 'MY → 이용권 내역',
    url: 'https://www.wavve.com/my',
    historyRange: '이용권 단위',
    caveat: '통신사 제휴 이용권은 해당 통신사에서 확인해야 해요.',
  ),
  'tving': BillingLookup(
    path: 'MY → 이용권 목록 → 구매 내역',
    url: 'https://www.tving.com/my/account',
    historyRange: '이용권 단위',
    caveat: '통신사 제휴나 앱스토어 결제는 해당 채널에서 확인해야 해요.',
  ),
  'spotify': BillingLookup(
    path: '계정 → 결제 내역',
    url: 'https://www.spotify.com/account/payment-history/',
    historyRange: '최근 2년',
    caveat: '통신사나 앱스토어로 결제했다면 그쪽에서 확인해야 해요.',
  ),
  'apple_music': BillingLookup(
    path: 'Apple 계정 → 미디어 및 구입 항목 → 구입 항목',
    url: 'https://reportaproblem.apple.com',
    historyRange: '전체 구입 내역',
    caveat: '금액으로 검색하면 정체를 모르는 청구도 찾을 수 있어요.',
  ),
  'notion': BillingLookup(
    path: '설정 → 청구 → 인보이스 보기',
    historyRange: '전체 인보이스',
    caveat: '워크스페이스 소유자·관리자만 볼 수 있어요.',
  ),
  'google_one': BillingLookup(
    path: 'Google Pay → 활동',
    url: 'https://pay.google.com/gp/w/u/0/home/activity',
    historyRange: '전체 거래',
    caveat: 'Google Play로 가입했다면 Play 정기결제에서도 확인해야 해요.',
  ),
  'microsoft_365': BillingLookup(
    path: '계정 → 결제 및 청구 → 주문 내역',
    url: 'https://account.microsoft.com/billing/orders',
    historyRange: '전체 (기간 필터 있음)',
    caveat: '결제한 Microsoft 계정으로 로그인했는지 확인하세요.',
  ),
};

/// 앱스토어·구글플레이로 결제한 경우는 서비스와 무관하게 여기서 본다.
const appStoreSubscriptionsUrl =
    'https://apps.apple.com/account/subscriptions';
const playStoreSubscriptionsUrl =
    'https://play.google.com/store/account/subscriptions';

BillingLookup? billingLookupOf(String? serviceId) =>
    serviceId == null ? null : billingLookups[serviceId];

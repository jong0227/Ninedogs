# Ninedogs — 프로젝트 컨텍스트

구독 관리 앱. 개발자 본인과 배우자가 함께 쓸 목적으로 만든다.
이 문서는 새 세션이나 다른 기기에서 작업을 이어받을 때 읽는 배경 설명이다.

## 무엇을 만들고 있나

일상에서 구독하는 서비스가 너무 많아 뭘 구독 중인지 파악이 안 되는 문제를 푼다.
원래 요구사항 8가지:

1. 내 구독 목록 관리
2. 앱 아이콘을 고화질로 받아와서 예쁘게 보여주기
3. 심플한 디자인 — 스포티파이 첫 가입처럼 탭해서 구독을 골라나가는 온보딩
4. 클릭 몇 번으로 기록이 끝나는 편의성
5. 가격 변동 반영, 구독 시작일 / 이용 권한 만료일 / 카드 결제일 기록
6. 앱별 누적 지출 + 전체 누적 지출
7. 부부가 같은 데이터를 공유
8. 서비스별 아이디/비밀번호 기록

## 기술 스택

- Flutter 3.44.6 / Dart 3.12.2
- 상태 관리: **Riverpod 3** (코드 생성 없이 손으로 쓴 provider)
- 로컬 저장: SharedPreferences (JSON)
- 암호화: `cryptography` 패키지 (PBKDF2 + AES-GCM)
- 네비게이션: 기본 `Navigator` — 화면이 적어 go_router는 뺐다

의도적으로 **코드 생성(build_runner/freezed/riverpod_generator)을 쓰지 않는다.**
초기에 넣어봤으나 `custom_lint`/`riverpod_lint` 버전 충돌이 났고, 이 규모에서는
손으로 쓴 모델이 마찰이 더 적다고 판단했다.

## 구조

```
lib/
  core/theme/          디자인 토큰 (색/간격/테마)
  core/format/         날짜·기간 포맷
  data/models/         Money, BillingCycle, Subscription, Credential
  data/catalog/        기본 서비스 목록 38종 + 요금제
  data/icons/          App Store 검색으로 아이콘 URL 찾기
  data/security/       VaultCrypto — 암호화 핵심
  data/repository/     저장소 인터페이스 + 로컬 구현
  data/update/         새 버전 확인
  providers/           Riverpod provider 모음
  features/            화면별 (onboarding/home/detail/add/edit/vault/settings)
  widgets/             공용 위젯
```

## 꼭 알아야 할 설계 결정

### 돈은 정수로 다룬다
`Money`는 통화의 최소 단위를 `int`로 담는다 (KRW는 원, USD는 센트).
double로 누적 합계를 내면 오차가 쌓인다. 통화가 다른 금액끼리는 연산하지 않고
`_sumByCurrency`로 통화별로 나눠 합산한다.

### 누적 지출은 가격 이력에서 계산한다
`Subscription.priceHistory`는 시점별 가격 목록이다. `totalSpentUntil()`은
시작일부터 결제일을 하나씩 짚어가며 **그 시점에 유효했던 가격**을 더한다.
현재 가격 × 개월수가 아니다.

말일 처리: 1월 31일 구독은 2월에 28일로 당겨지고 3월에 다시 31일로 돌아온다
(`addMonths`).

### 가격 인상과 오타 정정을 구분한다
편집 화면에서 금액을 바꾸면 그냥 덮어쓰지 않고 물어본다.
- **요금이 올랐다** → 이력에 새 항목 추가, 이전 결제는 옛 금액 유지
- **잘못 적었다** → 마지막 항목 교체, 처음부터 새 금액으로 재계산

이 구분이 없으면 누적 지출이 틀어진다. 둘 다 테스트로 검증돼 있다.

### 아이콘은 App Store 검색 API로 받는다
파비콘은 32~64px이라 화질이 나쁘다. `itunes.apple.com/search`는 키 없이
512px 원본을 준다. 찾은 URL은 30일간 로컬 캐시. 실패하면 브랜드색 타일에
첫 글자를 얹는다. 카탈로그에 없는 서비스도 입력한 이름으로 검색한다.

국내 서비스(티빙/웨이브/배민 등)는 검색어가 잘 맞는지 실기기 확인이 필요하다.

### 계정 정보는 평문으로 저장하지 않는다
`VaultCrypto`가 마스터 암호에서 PBKDF2-HMAC-SHA256(12만 회)로 키를 뽑고
AES-GCM 256으로 암호화한다. 키는 메모리에만 둔다.

- **부부 공유 원리**: 같은 마스터 암호 + 같은 salt → 같은 키. salt는 비밀이
  아니라 메타데이터로 함께 저장한다.
- 서버(나중의 Firestore)에는 암호문·nonce·MAC만 올라간다. 평문으로 남는 건
  "어떤 구독의 것인지"(subscriptionId)뿐이다.
- `verifier`(고정 문구를 암호화해 둔 값)로 전체 복호화 없이 암호 일치를 판별한다.
- **마스터 암호를 잊으면 복구 불가.** 설정 화면에서 정하기 전에 경고를 띄운다.

### 카탈로그 가격은 참고용 기본값이다
`ServiceCatalog`의 요금제 가격은 빠른 시작을 돕는 대략값이고 실제와 다를 수 있다.
UI에서 항상 수정 가능하게 노출한다. 사실로 단정하지 말 것.

## 코드 컨벤션

- 주석과 UI 문자열은 **한국어**. 주석은 "무엇"이 아니라 **"왜"**를 적는다.
- provider 본문은 결정적이어야 한다. (실제로 `credentialProvider`가 rebuild마다
  새 UUID를 만들어 상태가 안 잡히는 버그가 있었다. id는 subscriptionId에서 유도.)
- 저장소는 인터페이스로 분리한다. 로컬 구현 → Firestore 구현 교체가 목표.
- 저장 데이터가 깨져도 덮어쓰지 않는다. 읽기만 포기한다.
- 모든 단계에서 `flutter analyze`와 `flutter test`를 돌린다.

## 진행 상황

**완료**
- 디자인 시스템, 데이터 모델, 서비스 카탈로그 38종, 아이콘 파이프라인
- 온보딩(탭해서 고르기 → 요금제 확인), 홈 대시보드, 구독 상세
- 구독 추가/편집 (가격 인상 vs 정정 구분 포함)
- 계정 정보 암호화 계층 + 마스터 암호 설정/해제/변경 UI
- 설정 화면 + 업데이트 확인
- 테스트 70개

**남은 것**
1. **생체인증 잠금 해제** — `VaultNotifier.unlockWithKeyBytes()` 경로는 이미
   구현·테스트 완료. `local_auth` 추가 + MainActivity를 `FlutterFragmentActivity`로
   바꾸고, 유도한 키를 `flutter_secure_storage`에 넣으면 된다.
2. **Firebase 동기화 (부부 공유)** — 요구사항 7번. Firebase 콘솔에서 프로젝트
   생성은 사용자가 직접 해야 한다. `SubscriptionRepository`와
   `CredentialRepository`의 Firestore 구현을 추가하는 형태.
3. 업데이트 확인의 릴리즈 소스 — 저장소가 비공개라 인증 없이 GitHub Releases를
   읽을 수 없다. 공개 저장소로 릴리즈를 내보내거나 다른 호스팅이 필요하다.
   토큰을 앱에 심는 방식은 쓰지 않는다.
4. 자동 잠금(백그라운드 진입 시), 구독 통계·차트

## 개발 환경

### 노트북 (주 개발·릴리즈 환경, 목표)
릴리즈 서명 키는 여기에만 둔다. 절차는 [RELEASE.md](RELEASE.md) 참고.

### Windows 데스크톱 PC (임시 개발용)
- Flutter `C:\dev\flutter`, Android SDK `C:\Android\sdk`,
  JDK 17 `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot`
- **Gradle이 AF_UNIX 소켓 문제로 실패하는 기기라** 빌드 전 매번 필요:
  ```powershell
  $env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"
  $env:Path = "C:\dev\flutter\bin;$env:JAVA_HOME\bin;C:\Android\sdk\platform-tools;$env:Path"
  $env:_JAVA_OPTIONS = "-Djdk.net.unixdomain.tmpdir=C:\Android\tmp"
  ```
- 릴리즈 키스토어가 없어서 릴리즈 빌드도 디버그 키로 서명된다(테스트 전용).
- 이 PC의 `gh` CLI는 다른 계정(배우자)으로 표시되지만 `git push`는 정상 동작한다.
  `gh` 명령이 필요하면 사용자 터미널에서 직접 실행하게 안내할 것.

## 자주 쓰는 명령

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter build apk --release --split-per-abi
```

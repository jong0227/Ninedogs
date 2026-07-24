# Ninedogs — 프로젝트 컨텍스트

구독 관리 앱. 개발자 본인과 배우자가 함께 쓸 목적으로 만든다.
이 문서는 새 세션이나 다른 기기에서 작업을 이어받을 때 읽는 배경 설명이다.

## 무엇을 만들고 있나

일상에서 구독하는 서비스가 너무 많아 뭘 구독 중인지 파악이 안 되는 문제를 푼다.
원래 요구사항 8가지 — **모두 구현됨**:

1. 내 구독 목록 관리 ✅
2. 앱 아이콘을 고화질로 받아와서 예쁘게 ✅
3. 심플한 디자인, 스포티파이식 온보딩 ✅
4. 클릭 몇 번으로 기록이 끝나는 편의성 ✅
5. 가격 변동, 시작일 / 이용 권한 만료일 / 카드 결제일 ✅
6. 앱별 누적 지출 + 전체 누적 지출 ✅
7. 부부가 같은 데이터를 공유 ✅ (Firebase 설정 필요, 아래 참고)
8. 서비스별 아이디/비밀번호 기록 ✅ (암호화)

이후 추가된 것: 분야별 통계, 결제 캘린더, 결제 예정 알림, 백업/복원,
생체인증, 앱 아이콘.

## 기술 스택

- Flutter 3.44.6 / Dart 3.12.2
- 상태 관리: **Riverpod 3** (코드 생성 없이 손으로 쓴 provider)
- 로컬 저장: SharedPreferences (JSON)
- 원격 저장: Firebase Auth + Cloud Firestore (선택 기능)
- 암호화: `cryptography` (PBKDF2 + AES-GCM)
- 알림: `flutter_local_notifications` + `timezone`
- 생체인증: `local_auth` + `flutter_secure_storage`
- 네비게이션: 기본 `Navigator` — 화면이 적어 go_router는 뺐다

의도적으로 **코드 생성(build_runner/freezed/riverpod_generator)을 쓰지 않는다.**
초기에 넣어봤으나 `custom_lint`/`riverpod_lint` 버전 충돌이 났고, 이 규모에서는
손으로 쓴 모델이 마찰이 더 적다.

`file_picker`는 넣지 않는다. `share_plus`/`package_info_plus`와 win32 버전이
충돌해 2021년 버전으로만 해석된다. 파일을 받는 건 Android 인텐트로 처리한다.

## 구조

```
lib/
  core/theme/          디자인 토큰 (색/간격/타이포/분야 색)
  core/format/         날짜·기간 포맷
  data/models/         Money, BillingCycle, Subscription, Credential
  data/catalog/        기본 서비스 59종 + 요금제 + 도메인
  data/icons/          아이콘 URL 조회, 가장자리 색 추출
  data/security/       VaultCrypto(암호화), BiometricGate(지문)
  data/notifications/  결제 예정 알림 예약
  data/backup/         백업 파일 형식, 인텐트 수신 채널
  data/sync/           Household, SyncService (Firebase)
  data/repository/     저장소 인터페이스 + 로컬/Firestore 구현
  providers/           Riverpod provider 모음
  features/            화면별
    shell/             하단 탭 (구독 / 캘린더 / 통계)
    onboarding/ home/ calendar/ stats/ detail/ add/ edit/
    vault/ notifications/ backup/ sync/ settings/
  widgets/             ServiceIcon, ServiceBrowser
```

## 꼭 알아야 할 설계 결정

### 돈은 정수로 다룬다
`Money`는 통화의 최소 단위를 `int`로 담는다 (KRW는 원, USD는 센트).
double로 누적 합계를 내면 오차가 쌓인다. 통화가 다르면 합치지 않고
통화별로 나눠 집계한다.

### 누적 지출은 가격 이력에서 계산한다
`priceHistory`는 시점별 가격 목록이다. `totalSpentUntil()`은 시작일부터
결제일을 하나씩 짚어가며 **그 시점에 유효했던 가격**을 더한다.
현재 가격 × 개월수가 아니다.

말일 처리: 1월 31일 구독은 2월에 28일로 당겨지고 3월에 다시 31일로 돌아온다
(`addMonths`).

### 가격 인상과 오타 정정을 구분한다
금액을 바꾸면 그냥 덮어쓰지 않고 물어본다.
- **요금이 올랐다** → 이력에 추가, 이전 결제는 옛 금액 유지
- **잘못 적었다** → 마지막 항목 교체, 처음부터 새 금액으로 재계산

이 구분이 없으면 누적 지출이 틀어진다. 둘 다 테스트로 검증돼 있다.

### 아이콘은 잘리지 않고 이음매도 없다
아이콘 **가장자리 픽셀의 평균색**을 뽑아 원 전체를 그 색으로 칠하고,
그 위에 아이콘 원본을 `BoxFit.contain`으로 얹는다. 클립을 걸지 않는다.
바깥 색이 아이콘 테두리와 같아 경계가 안 보이고, 아이콘은 잘리지 않는다.
정사각형이 원에 들어가는 한계가 1/√2라 70%만 쓴다.

아이콘 출처는 3단계: App Store 검색(512px) → 도메인 파비콘 → 첫 글자.

### 분야 색은 분야에 고정이다
순위에 따라 색을 주면 화면을 다시 열 때마다 같은 분야가 다른 색이 된다.
채도·밝기를 맞춰서 하나만 튀지 않게 했다. (`core/theme/category_colors.dart`)

### 분야 칩은 필터가 아니라 목차다
누르면 그 구간으로 스크롤만 하고 다른 분야는 그대로 남는다.
스크롤하면 현재 분야가 칩에 표시된다. 그리드가 지연 생성이라 위치를
물어볼 수 없어서, 4열 고정 비율을 이용해 직접 계산한다.
(`widgets/service_browser.dart`)

### 계정 정보는 평문으로 저장하지 않는다
`VaultCrypto`가 마스터 암호에서 PBKDF2-HMAC-SHA256(12만 회)로 키를 뽑고
AES-GCM 256으로 암호화한다. 키는 메모리에만 둔다.

- **부부 공유 원리**: 같은 마스터 암호 + 같은 salt → 같은 키.
  salt는 비밀이 아니라 메타데이터로 함께 저장한다.
- 서버·백업에는 암호문·nonce·MAC만 올라간다. 평문으로 남는 건
  "어떤 구독의 것인지"(subscriptionId)뿐이다.
- 앱이 백그라운드로 가면 자동으로 잠근다. 복사한 비밀번호는 1분 뒤
  클립보드에서 지운다.
- **마스터 암호를 잊으면 복구 불가.** 최소 길이는 4자 —
  사용자가 짧게 요청했다. 짧은 암호는 암호문을 손에 넣은 사람이
  오프라인에서 대입 공격하기 쉽다는 점을 알린 뒤 반영했다.

### AsyncNotifier 는 build 완료를 기다린 뒤 바꾼다
`build()`가 비동기라, 저장소 로딩이 끝나기 전에 state를 바꾸면
뒤늦게 끝난 build 결과가 덮어쓴다. 온보딩에서 실제로 이 버그가 났다
(고른 구독이 전부 사라짐). `_mutate`는 `await future`로 시작한다.
회귀 테스트 있음.

### 동기화는 옵트인이다
앱을 깔기만 해서는 아무와도 묶이지 않는다. 설정에서 직접 연결해야
household가 생긴다. 같은 APK를 친구에게 줘도 서로 섞이지 않는다.

연결할 때 **로컬 데이터를 합친다.** 그냥 연결하면 비어 있는 서버 목록이
내려와 로컬을 지운다. id가 UUID라 양쪽을 더하면 둘 다 산다.
연결을 끊을 때는 서버 내용을 기기에 내려받아 둔다.

초대 코드는 `inviteCodes/{코드}` 문서로 둔다. household를 코드로 검색하면
로그인한 누구나 전체 목록을 훑을 수 있어 남의 코드가 노출된다.
코드를 문서 id로 쓰면 `get`만 열고 `list`는 막을 수 있다.

### 카탈로그 가격은 참고용 기본값이다
`ServiceCatalog`의 요금제 가격은 대략값이고 실제와 다를 수 있다.
UI에서 항상 수정 가능하게 노출한다. 사실로 단정하지 말 것.

## 코드 컨벤션

- 주석과 UI 문자열은 **한국어**. 주석은 "무엇"이 아니라 **"왜"**를 적는다.
- provider 본문은 결정적이어야 한다. (`credentialProvider`가 rebuild마다
  새 UUID를 만들어 상태가 안 잡히던 버그가 있었다)
- 저장소는 인터페이스로 분리한다. 로컬 ↔ Firestore 교체가 가능해야 한다.
- 저장 데이터가 깨져도 덮어쓰지 않는다. 읽기만 포기한다.
- 모든 단계에서 `flutter analyze`와 `flutter test`를 돌린다.
- **PowerShell로 소스 파일을 쓰지 말 것.** `Set-Content`가 인코딩을 다시 써서
  한글이 전부 깨진 적이 있다. 편집은 편집 도구나 `sed`로 한다.
- PowerShell here-string으로 git 커밋 메시지를 넘길 때 **큰따옴표를 넣지 말 것.**
  네이티브 인자 전달에서 문자열이 끊긴다.

## 진행 상황

**완료** (테스트 97개)
- 디자인 시스템, 데이터 모델, 카탈로그 59종, 아이콘 파이프라인
- 온보딩(한 단계, 기본값 자동), 홈, 캘린더, 통계, 상세
- 구독 추가/편집, 상세에서 값 하나만 바로 고치기
- 계정 정보 암호화 + 마스터 암호 + 생체인증
- 결제 예정 알림 (7/3/1일 전, 전체·구독별 설정)
- 백업 내보내기(카톡 공유) / 복원(파일 열기)
- 앱 아이콘, 설정 화면, 데이터 초기화

**남은 것**
1. **Firebase 설정 파일** — 아래 참고. 이게 있어야 부부 공유가 켜진다.
2. **릴리즈 서명 키** — [RELEASE.md](RELEASE.md) 참고
3. 업데이트 확인의 릴리즈 소스 — 저장소가 비공개라 인증 없이 GitHub
   Releases를 읽을 수 없다. 공개 저장소로 릴리즈를 내보내거나 다른 호스팅이
   필요하다. 토큰을 앱에 심는 방식은 쓰지 않는다.
4. 위젯 테스트가 없다. 로직은 97개로 덮여 있지만 화면은 컴파일만 검증된다.
5. 결제 알림 파싱(카드사 알림에서 금액 자동 감지)은 **하지 않기로 했다.**
   카드사마다 형식이 달라 유지보수 부담이 크다.

## Firebase 설정 (부부 공유를 켜려면)

기존 Firebase 프로젝트가 있으면 **앱만 추가**하면 된다. 새로 만들어도 된다.

1. Firebase 콘솔 → 프로젝트 설정 → 앱 추가 → Android
2. 패키지 이름: `com.jong0227.ninedogs`
3. `google-services.json` 다운로드 → `android/app/` 에 넣기
4. `android/settings.gradle.kts` 의 plugins 블록에 추가:
   ```kotlin
   id("com.google.gms.google-services") version "4.4.2" apply false
   ```
5. `android/app/build.gradle.kts` 의 plugins 블록에 추가:
   ```kotlin
   id("com.google.gms.google-services")
   ```
6. 콘솔에서 **Authentication → 이메일/비밀번호** 사용 설정
7. 콘솔에서 **Firestore Database** 만들기
8. [firestore.rules](firestore.rules) 내용을 Firestore 규칙에 붙여넣고 게시

> Auth 사용자 풀은 프로젝트 단위로 공유된다. 기존 앱에 로그인한 계정이
> 이 앱에도 보인다. 본인·배우자만 쓴다면 문제없다.

**설정 파일이 없어도 앱은 그대로 동작한다.** `Firebase.initializeApp()` 실패를
잡아내고 로컬 저장소만 쓴다. 실기기에서 확인함.

## 개발 환경

### 노트북 (주 개발·릴리즈 환경)
릴리즈 서명 키는 여기에만 둔다. 절차는 [RELEASE.md](RELEASE.md).

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
- 이 PC의 `gh` CLI는 다른 계정으로 표시되지만 `git push`는 정상 동작한다.

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

앱 아이콘을 새 이미지로 바꾸려면 `assets/icon/source_dog.png` 를 교체하고:

```bash
powershell -File tool/crop_icon.ps1 && dart run flutter_launcher_icons
```

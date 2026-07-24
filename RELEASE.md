# 노트북에서 릴리즈 빌드하기

서명 키는 이 저장소에 들어 있지 않다. 빌드하는 기기에서 한 번 만들고
그 기기에만 둔다.

---

## 1. 개발 환경 준비

필요한 것:

- **Flutter SDK** (3.44 이상) — https://docs.flutter.dev/get-started/install
- **Android Studio** 또는 Android SDK + 플랫폼 도구
- **JDK 17** (Eclipse Temurin 권장)

설치 후 확인:

```bash
flutter doctor
```

`Android toolchain` 항목에 체크가 뜨면 된다. 라이선스 동의가 안 됐다면:

```bash
flutter doctor --android-licenses
```

## 2. 저장소 받기

```bash
git clone https://github.com/jong0227/Ninedogs.git
```

```bash
cd Ninedogs && flutter pub get
```

커밋 작성자를 이 저장소에서만 따로 지정하려면 (전역 설정은 건드리지 않는다):

```bash
git config --local user.name "jong0227"
```

```bash
git config --local user.email "본인이메일"
```

## 3. 릴리즈 키스토어 만들기 (최초 한 번)

`keytool`은 JDK에 들어 있다. 홈 디렉터리처럼 **저장소 밖**에 만든다.

macOS / Linux:

```bash
keytool -genkey -v -keystore ~/ninedogs-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ninedogs
```

Windows (PowerShell):

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\ninedogs-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ninedogs
```

물어보는 것들:
- **키스토어 비밀번호** — 기억할 것. 분실하면 복구 불가.
- 이름/조직/도시 등 — 대충 적어도 되지만 스토어에 공개되진 않는다.
- 키 비밀번호 — 키스토어 비밀번호와 같게 해도 된다 (Enter로 넘김)

> ### ⚠️ 이 파일을 잃어버리면 앱을 영원히 업데이트할 수 없다
>
> Google Play는 같은 키로 서명된 APK만 같은 앱의 업데이트로 인정한다.
> 키를 잃으면 새 앱으로 다시 올려야 하고 기존 사용자·리뷰·설치 수를 모두 잃는다.
>
> `.jks` 파일과 비밀번호를 **암호 관리자나 안전한 백업**에 따로 보관할 것.
> 저장소에는 절대 넣지 않는다 (`.gitignore`에 이미 막아뒀다).

## 4. key.properties 만들기

저장소 루트의 `android/` 폴더 안에 `key.properties`를 만든다.
정확히 `android/key.properties` 위치여야 한다.

```properties
storePassword=위에서_정한_키스토어_비밀번호
keyPassword=위에서_정한_키_비밀번호
keyAlias=ninedogs
storeFile=/Users/본인계정/ninedogs-release.jks
```

Windows면 `storeFile`에 백슬래시를 두 번 쓰거나 슬래시를 쓴다:

```properties
storeFile=C:/Users/본인계정/ninedogs-release.jks
```

이 파일은 `.gitignore`에 있어서 커밋되지 않는다. 확인:

```bash
git status --short
```

`key.properties`가 안 보이면 정상이다.

## 4.5. Firebase 설정 (부부 공유를 쓸 거면)

부부 공유 동기화를 켜려면 `google-services.json` 이 필요하다.
없으면 앱은 이 기기 저장소만 쓰며 정상 동작한다.

절차는 [CLAUDE.md](CLAUDE.md) 의 "Firebase 설정" 항목을 그대로 따르면 된다.
요약하면: 콘솔에서 Android 앱 추가(`com.jong0227.ninedogs`) → json 을
`android/app/` 에 넣기 → gradle 플러그인 두 줄 추가 → Authentication 의
이메일/비밀번호 켜기 → Firestore 만들고 `firestore.rules` 붙여넣기.

## 5. 빌드

`android/app/build.gradle.kts`가 `key.properties`가 있으면 자동으로 그 키를
쓰고, 없으면 디버그 키로 서명하도록 이미 설정돼 있다. **코드를 고칠 필요 없다.**

### Play 스토어용 (AAB)

```bash
flutter build appbundle --release
```

결과: `build/app/outputs/bundle/release/app-release.aab`

### 직접 설치용 (APK)

**`--split-per-abi`를 쓰지 않는다.** ABI별로 쪼개면 파일이 여러 개가 되고,
사용자가 자기 기기에 맞는 걸 골라야 해서 헷갈린다. 앱 내 업데이트 확인도
릴리즈 자산 중 `.apk`로 끝나는 **첫 번째 파일**을 그냥 받아오므로, 파일이
여러 개면 엉뚱한 아키텍처용을 받을 수 있다. 파일 하나(범용 APK)로 둔다.

```bash
flutter build apk --release
```

결과: `build/app/outputs/flutter-apk/app-release.apk` (용량이 크지만 모든
기기에서 그대로 설치된다)

### 서명이 제대로 됐는지 확인

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

소유자(Owner)에 키스토어 만들 때 입력한 이름이 나오면 성공이다.
`Android Debug`라고 나오면 `key.properties`를 못 읽은 것이다.

## 6. 버전 올리기

`pubspec.yaml`의 `version:`을 고친다.

```yaml
version: 1.1.0+2
```

- `1.1.0` = 사용자에게 보이는 버전 (`versionName`)
- `+2` = 빌드 번호 (`versionCode`). 스토어에 올릴 때마다 **반드시 증가**해야 한다.

---

## 주의: 테스트 APK와 서명이 다르다

Windows 데스크톱 PC에서 만든 테스트 APK는 **디버그 키**로 서명돼 있다.
여기서 만든 진짜 릴리즈 APK와는 서명이 다르므로 덮어쓰기 설치가 안 된다.

폰에 테스트 버전이 깔려 있다면 **먼저 삭제**해야 한다.
지금은 데이터가 기기에만 저장되므로 **삭제하면 입력한 구독 정보도 사라진다.**
Firebase 동기화가 붙으면 이 문제는 없어진다.

## 앱 내 업데이트 확인에 대해

설정 화면의 "업데이트 확인"은 GitHub Releases를 본다.
저장소가 **비공개**라 인증 없이는 읽을 수 없어서 지금은 확인에 실패한다.

쓰려면 셋 중 하나가 필요하다:
1. 저장소를 공개로 전환
2. 릴리즈 배포용 공개 저장소를 따로 만들고
   `UpdateChecker.defaultReleasesUrl`을 그쪽으로 변경
3. 다른 곳에 버전 정보 JSON을 올리고 그 주소를 사용

접근 토큰을 앱에 심는 방식은 쓰지 않는다. APK를 뜯으면 토큰이 노출된다.

릴리즈를 올릴 때는 태그를 `v1.1.0` 형태로 달고 APK를 자산으로 첨부하면
앱이 바로 내려받기 주소를 잡는다.

```bash
gh release create v1.1.0 build/app/outputs/flutter-apk/app-arm64-v8a-release.apk --notes "변경 내용"
```

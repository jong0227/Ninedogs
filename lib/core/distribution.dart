/// 이 빌드가 어느 경로로 배포되는지.
///
/// GitHub Release 사이드로드 빌드는 자체 업데이트 확인·설치 기능을 쓴다.
/// Play 스토어 빌드는 그 기능이 아예 없다 — Play 는 자기 업데이트
/// 메커니즘 외의 방법으로 앱이 스스로를 갱신하는 걸 정책으로 금지한다.
///
/// 빌드 시 `--dart-define=DISTRIBUTION=playstore` 로 넘긴다. 안 넘기면
/// 지금까지 쓰던 github 빌드와 동일하게 동작한다.
const _distribution = String.fromEnvironment(
  'DISTRIBUTION',
  defaultValue: 'github',
);

/// GitHub Release 에서 받은 APK 로 자체 업데이트하는 빌드인지.
const isGithubDistribution = _distribution == 'github';

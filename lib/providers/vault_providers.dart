import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/credential.dart';
import '../data/repository/credential_repository.dart';
import '../data/security/biometric_gate.dart';
import '../data/security/vault_crypto.dart';
import 'app_providers.dart';

/// 금고의 잠금 상태.
sealed class VaultState {
  const VaultState();
}

/// 마스터 암호를 아직 정하지 않음. 처음 계정 정보를 저장할 때 설정한다.
class VaultUninitialized extends VaultState {
  const VaultUninitialized();
}

/// 마스터 암호는 있지만 잠겨 있음. 키가 메모리에 없다.
class VaultLocked extends VaultState {
  const VaultLocked();
}

/// 열려 있음. [crypto] 가 살아 있는 동안만 복호화할 수 있다.
class VaultUnlocked extends VaultState {
  const VaultUnlocked(this.crypto);
  final VaultCrypto crypto;
}

final credentialRepositoryProvider = Provider<CredentialRepository>(
  (ref) => LocalCredentialRepository(ref.watch(sharedPreferencesProvider)),
);

final biometricGateProvider = Provider<BiometricGate>((ref) => BiometricGate());

/// 이 기기에서 지문·얼굴을 쓸 수 있는지.
final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricGateProvider).isAvailable(),
);

/// 생체인증으로 열도록 설정해 뒀는지.
/// 켜고 끌 때 invalidate 해서 화면이 따라오게 한다.
final biometricEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricGateProvider).isEnabled(),
);

/// PBKDF2 반복 횟수. 키 유도를 일부러 느리게 만들어 무차별 대입을 막는다.
/// 테스트에서는 낮은 값으로 override 해서 실행 시간을 줄인다.
final vaultIterationsProvider = Provider<int>(
  (ref) => VaultCrypto.iterations,
);

class VaultNotifier extends AsyncNotifier<VaultState> {
  CredentialRepository get _repository => ref.read(credentialRepositoryProvider);

  int get _iterations => ref.read(vaultIterationsProvider);

  VaultMetadata? _metadata;

  @override
  Future<VaultState> build() async {
    _metadata = await _repository.loadMetadata();
    return _metadata == null ? const VaultUninitialized() : const VaultLocked();
  }

  /// 지금 열려 있으면 암복호화에 쓸 객체, 아니면 null.
  VaultCrypto? get crypto => switch (state.value) {
    VaultUnlocked(:final crypto) => crypto,
    _ => null,
  };

  /// 마스터 암호를 처음 정한다. 새 salt 와 확인용 값을 만들어 저장한다.
  Future<void> setUp(String password) async {
    if (_metadata != null) {
      throw StateError('이미 마스터 암호가 설정되어 있습니다');
    }

    final salt = VaultCrypto.newSalt();
    final crypto = await VaultCrypto.fromPassword(
      password,
      salt,
      iterations: _iterations,
    );
    final metadata = VaultMetadata(
      salt: salt,
      verifier: await crypto.createVerifier(),
      createdAt: DateTime.now(),
    );

    await _repository.saveMetadata(metadata);
    _metadata = metadata;
    state = AsyncData(VaultUnlocked(crypto));
  }

  /// 마스터 암호로 연다. 틀리면 false 를 주고 상태는 잠긴 채로 둔다.
  Future<bool> unlock(String password) async {
    final metadata = _metadata;
    if (metadata == null) return false;

    final crypto = await VaultCrypto.fromPassword(
      password,
      metadata.salt,
      iterations: _iterations,
    );
    if (!await crypto.matchesVerifier(metadata.verifier)) return false;

    state = AsyncData(VaultUnlocked(crypto));
    return true;
  }

  /// 생체인증 뒤 기기 보안 저장소에서 꺼낸 키로 연다.
  Future<bool> unlockWithKeyBytes(List<int> keyBytes) async {
    final metadata = _metadata;
    if (metadata == null) return false;

    final crypto = VaultCrypto.fromKeyBytes(keyBytes);
    if (!await crypto.matchesVerifier(metadata.verifier)) return false;

    state = AsyncData(VaultUnlocked(crypto));
    return true;
  }

  /// 키를 메모리에서 버린다. 앱을 백그라운드로 보낼 때도 부른다.
  void lock() {
    if (_metadata != null) state = const AsyncData(VaultLocked());
  }

  /// 지문·얼굴로 연다. 인증을 취소하거나 설정해 두지 않았으면 false.
  Future<bool> unlockWithBiometrics() async {
    final keyBytes = await ref.read(biometricGateProvider).unlock();
    if (keyBytes == null) return false;

    return unlockWithKeyBytes(keyBytes);
  }

  /// 지금 열려 있는 키를 기기 보안 저장소에 넣어 다음부터 생체인증으로 열게 한다.
  Future<bool> enableBiometrics() async {
    final current = crypto;
    if (current == null) return false;

    await ref
        .read(biometricGateProvider)
        .enable(await current.exportKeyBytes());
    ref.invalidate(biometricEnabledProvider);
    return true;
  }

  Future<void> disableBiometrics() async {
    await ref.read(biometricGateProvider).disable();
    ref.invalidate(biometricEnabledProvider);
  }

  /// 마스터 암호 변경. 저장된 계정 정보를 전부 새 키로 다시 암호화한다.
  /// 하나라도 실패하면 아무것도 바꾸지 않는다.
  Future<bool> changePassword(String current, String next) async {
    final metadata = _metadata;
    if (metadata == null) return false;

    final oldCrypto = await VaultCrypto.fromPassword(
      current,
      metadata.salt,
      iterations: _iterations,
    );
    if (!await oldCrypto.matchesVerifier(metadata.verifier)) return false;

    final salt = VaultCrypto.newSalt();
    final newCrypto = await VaultCrypto.fromPassword(
      next,
      salt,
      iterations: _iterations,
    );

    final reEncrypted = <StoredCredential>[];
    for (final stored in await _repository.load()) {
      final plain = await stored.decrypt(oldCrypto);
      reEncrypted.add(await plain.encrypt(newCrypto));
    }

    final newMetadata = VaultMetadata(
      salt: salt,
      verifier: await newCrypto.createVerifier(),
      createdAt: metadata.createdAt,
    );

    await _repository.save(reEncrypted);
    await _repository.saveMetadata(newMetadata);
    _metadata = newMetadata;
    state = AsyncData(VaultUnlocked(newCrypto));

    ref.invalidate(storedCredentialsProvider);
    return true;
  }
}

final vaultProvider = AsyncNotifierProvider<VaultNotifier, VaultState>(
  VaultNotifier.new,
);

/// 암호화된 채로 들고 있는 계정 정보. 잠겨 있어도 목록 자체는 볼 수 있다.
class StoredCredentialsNotifier extends AsyncNotifier<List<StoredCredential>> {
  CredentialRepository get _repository => ref.read(credentialRepositoryProvider);

  @override
  Future<List<StoredCredential>> build() => _repository.load();

  /// 구독 하나에 계정 정보 하나. 이미 있으면 덮어쓴다.
  Future<void> save(Credential credential, VaultCrypto crypto) async {
    final encrypted = await credential.encrypt(crypto);

    // 불러오기가 끝나기 전에 바꾸면 뒤늦은 build 결과에 덮어써진다
    final current = await future;

    final next = [
      for (final stored in current)
        if (stored.subscriptionId != credential.subscriptionId) stored,
      encrypted,
    ];

    state = AsyncData(next);
    await _repository.save(next);
  }

  Future<void> removeFor(String subscriptionId) async {
    final next = (await future)
        .where((c) => c.subscriptionId != subscriptionId)
        .toList();

    state = AsyncData(next);
    await _repository.save(next);
  }

  StoredCredential? forSubscription(String subscriptionId) {
    for (final stored in state.value ?? const <StoredCredential>[]) {
      if (stored.subscriptionId == subscriptionId) return stored;
    }
    return null;
  }
}

final storedCredentialsProvider =
    AsyncNotifierProvider<StoredCredentialsNotifier, List<StoredCredential>>(
      StoredCredentialsNotifier.new,
    );

/// 구독에 저장된 계정 정보가 있는지. 잠금 상태와 무관하게 알 수 있다.
final hasCredentialProvider = Provider.family<bool, String>((ref, id) {
  final stored = ref.watch(storedCredentialsProvider).value ?? const [];
  return stored.any((c) => c.subscriptionId == id);
});

/// 복호화된 계정 정보. 금고가 잠겨 있으면 null.
final credentialProvider = FutureProvider.family<Credential?, String>((
  ref,
  subscriptionId,
) async {
  final vault = ref.watch(vaultProvider).value;
  if (vault is! VaultUnlocked) return null;

  final stored = ref.watch(storedCredentialsProvider).value ?? const [];
  for (final entry in stored) {
    if (entry.subscriptionId == subscriptionId) {
      return entry.decrypt(vault.crypto);
    }
  }

  // 아직 저장한 적 없으면 빈 값으로 시작한다.
  //
  // id 는 subscriptionId 에서 그대로 유도한다. 여기서 난수 id 를 만들면
  // provider 가 rebuild 될 때마다 다른 값이 나와서 상태가 안정되지 않는다.
  // 계정 정보는 구독당 하나뿐이라 이 id 로 충분하다.
  return Credential(
    id: 'cred:$subscriptionId',
    subscriptionId: subscriptionId,
  );
});

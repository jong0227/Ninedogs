import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/credential.dart';
import 'package:ninedogs/data/repository/credential_repository.dart';
import 'package:ninedogs/providers/vault_providers.dart';

class FakeCredentialRepository implements CredentialRepository {
  VaultMetadata? metadata;
  List<StoredCredential> stored = [];

  @override
  Future<VaultMetadata?> loadMetadata() async => metadata;

  @override
  Future<void> saveMetadata(VaultMetadata value) async => metadata = value;

  @override
  Future<List<StoredCredential>> load() async => stored;

  @override
  Future<void> save(List<StoredCredential> credentials) async =>
      stored = credentials;
}

void main() {
  late FakeCredentialRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeCredentialRepository();
    container = ProviderContainer.test(
      overrides: [
        credentialRepositoryProvider.overrideWithValue(repository),
        // 실제 앱은 12만 회를 쓴다. 테스트에서는 속도를 위해 낮춘다.
        vaultIterationsProvider.overrideWithValue(1000),
      ],
    );
  });

  Future<VaultNotifier> vault() async {
    await container.read(vaultProvider.future);
    return container.read(vaultProvider.notifier);
  }

  VaultState currentState() => container.read(vaultProvider).value!;

  test('처음에는 마스터 암호가 없는 상태다', () async {
    await vault();
    expect(currentState(), isA<VaultUninitialized>());
  });

  test('마스터 암호를 정하면 바로 열린 상태가 된다', () async {
    final notifier = await vault();
    await notifier.setUp('우리집비밀번호');

    expect(currentState(), isA<VaultUnlocked>());
    expect(repository.metadata, isNotNull);
  });

  test('마스터 암호를 두 번 설정할 수 없다', () async {
    final notifier = await vault();
    await notifier.setUp('우리집비밀번호');

    expect(() => notifier.setUp('다른암호'), throwsStateError);
  });

  test('앱을 다시 켜면 잠긴 상태로 시작한다', () async {
    final first = await vault();
    await first.setUp('우리집비밀번호');

    // 저장소만 남기고 컨테이너를 새로 만든다 = 앱 재시작
    final restarted = ProviderContainer.test(
      overrides: [
        credentialRepositoryProvider.overrideWithValue(repository),
        // 실제 앱은 12만 회를 쓴다. 테스트에서는 속도를 위해 낮춘다.
        vaultIterationsProvider.overrideWithValue(1000),
      ],
    );
    await restarted.read(vaultProvider.future);

    expect(restarted.read(vaultProvider).value, isA<VaultLocked>());
  });

  test('맞는 암호로는 열리고 틀린 암호로는 안 열린다', () async {
    final notifier = await vault();
    await notifier.setUp('우리집비밀번호');
    notifier.lock();
    expect(currentState(), isA<VaultLocked>());

    expect(await notifier.unlock('틀린암호'), isFalse);
    expect(currentState(), isA<VaultLocked>());

    expect(await notifier.unlock('우리집비밀번호'), isTrue);
    expect(currentState(), isA<VaultUnlocked>());
  });

  test('잠그면 키가 메모리에서 사라진다', () async {
    final notifier = await vault();
    await notifier.setUp('우리집비밀번호');
    expect(notifier.crypto, isNotNull);

    notifier.lock();
    expect(notifier.crypto, isNull);
  });

  test('생체인증 경로: 저장해 둔 키로 암호 없이 열린다', () async {
    final notifier = await vault();
    await notifier.setUp('우리집비밀번호');

    final keyBytes = await notifier.crypto!.exportKeyBytes();
    notifier.lock();

    expect(await notifier.unlockWithKeyBytes(keyBytes), isTrue);
    expect(currentState(), isA<VaultUnlocked>());
  });

  test('엉뚱한 키로는 열리지 않는다', () async {
    final notifier = await vault();
    await notifier.setUp('우리집비밀번호');
    notifier.lock();

    expect(await notifier.unlockWithKeyBytes(List.filled(32, 7)), isFalse);
    expect(currentState(), isA<VaultLocked>());
  });

  group('계정 정보 저장', () {
    test('저장하면 암호문으로 남고 열었을 때 원래 값이 나온다', () async {
      final notifier = await vault();
      await notifier.setUp('우리집비밀번호');

      final credentials = container.read(storedCredentialsProvider.notifier);
      await container.read(storedCredentialsProvider.future);
      await credentials.save(
        const Credential(
          id: 'c1',
          subscriptionId: 'netflix-1',
          loginId: 'me@example.com',
          password: 'hunter2',
        ),
        notifier.crypto!,
      );

      expect(repository.stored.length, 1);

      final decrypted = await container.read(
        credentialProvider('netflix-1').future,
      );
      expect(decrypted!.loginId, 'me@example.com');
      expect(decrypted.password, 'hunter2');
    });

    test('잠겨 있으면 복호화된 값을 주지 않는다', () async {
      final notifier = await vault();
      await notifier.setUp('우리집비밀번호');

      final credentials = container.read(storedCredentialsProvider.notifier);
      await container.read(storedCredentialsProvider.future);
      await credentials.save(
        const Credential(
          id: 'c1',
          subscriptionId: 'netflix-1',
          loginId: 'me@example.com',
          password: 'hunter2',
        ),
        notifier.crypto!,
      );

      notifier.lock();
      expect(
        await container.read(credentialProvider('netflix-1').future),
        isNull,
      );

      // 잠겨 있어도 '저장된 게 있다'는 사실은 알 수 있다
      expect(container.read(hasCredentialProvider('netflix-1')), isTrue);
    });

    test('같은 구독에 다시 저장하면 덮어쓴다', () async {
      final notifier = await vault();
      await notifier.setUp('우리집비밀번호');

      final credentials = container.read(storedCredentialsProvider.notifier);
      await container.read(storedCredentialsProvider.future);

      await credentials.save(
        const Credential(
          id: 'c1',
          subscriptionId: 'netflix-1',
          loginId: '첫번째',
        ),
        notifier.crypto!,
      );
      await credentials.save(
        const Credential(
          id: 'c1',
          subscriptionId: 'netflix-1',
          loginId: '두번째',
        ),
        notifier.crypto!,
      );

      expect(repository.stored.length, 1);
      final decrypted = await container.read(
        credentialProvider('netflix-1').future,
      );
      expect(decrypted!.loginId, '두번째');
    });
  });

  group('마스터 암호 변경', () {
    test('저장된 계정 정보가 새 암호로 다시 암호화된다', () async {
      final notifier = await vault();
      await notifier.setUp('예전암호');

      final credentials = container.read(storedCredentialsProvider.notifier);
      await container.read(storedCredentialsProvider.future);
      await credentials.save(
        const Credential(
          id: 'c1',
          subscriptionId: 'netflix-1',
          loginId: 'me@example.com',
          password: 'hunter2',
        ),
        notifier.crypto!,
      );

      expect(await notifier.changePassword('예전암호', '새암호'), isTrue);

      // changePassword 가 저장 목록을 무효화하므로 다시 읽힐 때까지 기다린다
      await container.read(storedCredentialsProvider.future);

      notifier.lock();
      expect(await notifier.unlock('예전암호'), isFalse);
      expect(await notifier.unlock('새암호'), isTrue);

      final decrypted = await container.read(
        credentialProvider('netflix-1').future,
      );
      expect(decrypted!.password, 'hunter2');
    });

    test('현재 암호가 틀리면 아무것도 바뀌지 않는다', () async {
      final notifier = await vault();
      await notifier.setUp('예전암호');
      final before = repository.metadata;

      expect(await notifier.changePassword('틀린암호', '새암호'), isFalse);
      expect(repository.metadata, same(before));
    });
  });
}

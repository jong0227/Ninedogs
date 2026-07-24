import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/backup/backup_file.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/credential.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:ninedogs/data/repository/credential_repository.dart';
import 'package:ninedogs/data/repository/subscription_repository.dart';
import 'package:ninedogs/data/security/vault_crypto.dart';
import 'package:ninedogs/providers/backup_providers.dart';
import 'package:ninedogs/providers/subscription_providers.dart';
import 'package:ninedogs/providers/vault_providers.dart';

class FakeSubscriptionRepository implements SubscriptionRepository {
  FakeSubscriptionRepository([this.stored = const []]);
  List<Subscription> stored;

  @override
  Future<List<Subscription>> load() async => stored;

  @override
  Future<void> save(List<Subscription> subscriptions) async =>
      stored = subscriptions;
}

class FakeCredentialRepository implements CredentialRepository {
  FakeCredentialRepository({this.metadata, this.stored = const []});
  VaultMetadata? metadata;
  List<StoredCredential> stored;

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

Subscription sub(String id, {int price = 10000}) => Subscription(
  id: id,
  name: id,
  cycle: BillingCycle.monthly,
  startedAt: DateTime(2026, 1, 1),
  priceHistory: [
    PricePoint(effectiveFrom: DateTime(2026, 1, 1), amount: Money(price)),
  ],
);

VaultMetadata metadataWith(List<int> salt) => VaultMetadata(
  salt: salt,
  verifier: const EncryptedPayload(nonce: [1], cipherText: [2], mac: [3]),
  createdAt: DateTime(2026, 1, 1),
);

StoredCredential credential(String subscriptionId) => StoredCredential(
  id: 'c-$subscriptionId',
  subscriptionId: subscriptionId,
  payload: const EncryptedPayload(nonce: [9], cipherText: [8], mac: [7]),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('백업 파일 형식', () {
    test('내보낸 걸 그대로 다시 읽는다', () {
      final backup = BackupFile(
        exportedAt: DateTime(2026, 7, 24, 19, 5),
        subscriptions: [sub('netflix'), sub('spotify')],
      );

      final restored = BackupFile.decode(backup.encode());

      expect(restored.subscriptions.length, 2);
      expect(restored.subscriptions.first.id, 'netflix');
      expect(restored.exportedAt, backup.exportedAt);
      expect(restored.includesCredentials, isFalse);
    });

    test('계정 정보는 암호문 그대로 담기고 평문이 안 보인다', () {
      final backup = BackupFile(
        exportedAt: DateTime(2026, 7, 24),
        subscriptions: [sub('netflix')],
        vaultMetadata: metadataWith([1, 2, 3]),
        credentials: [credential('netflix')],
      );

      final encoded = backup.encode();
      expect(encoded, isNot(contains('password')));

      final restored = BackupFile.decode(encoded);
      expect(restored.includesCredentials, isTrue);
      expect(restored.vaultMetadata, isNotNull);
    });

    test('파일 이름에 날짜가 들어간다', () {
      final backup = BackupFile(
        exportedAt: DateTime(2026, 7, 24, 9, 5),
        subscriptions: const [],
      );
      expect(backup.suggestedFileName, 'ninedogs-backup-20260724-0905.json');
    });

    test('다른 파일이면 알아보고 거부한다', () {
      expect(
        () => BackupFile.decode('{"hello":"world"}'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupFile.decode('그냥 텍스트'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('더 새로운 버전은 거부한다', () {
      const future = '{"format":"ninedogs.backup","version":99,'
          '"exportedAt":"2026-07-24T00:00:00.000","subscriptions":[]}';
      expect(
        () => BackupFile.decode(future),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('가져오기', () {
    late FakeSubscriptionRepository subscriptions;
    late FakeCredentialRepository credentials;
    late ProviderContainer container;

    setUp(() {
      subscriptions = FakeSubscriptionRepository([sub('netflix', price: 13500)]);
      credentials = FakeCredentialRepository();
      container = ProviderContainer.test(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(subscriptions),
          credentialRepositoryProvider.overrideWithValue(credentials),
        ],
      );
    });

    test('없던 구독은 추가하고 기존 것은 지우지 않는다', () async {
      final result = await container.read(backupServiceProvider).import(
        BackupFile(
          exportedAt: DateTime(2026, 7, 24),
          subscriptions: [sub('spotify')],
        ),
      );

      expect(result.added, 1);
      expect(result.replaced, 0);
      expect(subscriptions.stored.length, 2);
    });

    test('같은 id 는 백업 내용으로 갱신한다', () async {
      final result = await container.read(backupServiceProvider).import(
        BackupFile(
          exportedAt: DateTime(2026, 7, 24),
          subscriptions: [sub('netflix', price: 17000)],
        ),
      );

      expect(result.replaced, 1);
      expect(result.added, 0);
      expect(subscriptions.stored.single.currentPrice, const Money(17000));
    });

    test('금고가 없던 기기면 백업의 금고를 그대로 가져온다', () async {
      final result = await container.read(backupServiceProvider).import(
        BackupFile(
          exportedAt: DateTime(2026, 7, 24),
          subscriptions: [sub('netflix')],
          vaultMetadata: metadataWith([1, 2, 3]),
          credentials: [credential('netflix')],
        ),
      );

      expect(result.credentialsRestored, 1);
      expect(result.credentialsSkippedReason, isNull);
      expect(credentials.metadata, isNotNull);
      expect(credentials.stored.length, 1);
    });

    test('salt 가 다르면 계정 정보를 건드리지 않고 이유를 알려준다', () async {
      // 열 수 없는 항목이 섞여 들어가면 나중에 원인을 알기 어렵다
      credentials.metadata = metadataWith([9, 9, 9]);
      credentials.stored = [credential('spotify')];

      final result = await container.read(backupServiceProvider).import(
        BackupFile(
          exportedAt: DateTime(2026, 7, 24),
          subscriptions: const [],
          vaultMetadata: metadataWith([1, 2, 3]),
          credentials: [credential('netflix')],
        ),
      );

      expect(result.credentialsRestored, 0);
      expect(result.credentialsSkippedReason, isNotNull);
      expect(credentials.stored.single.subscriptionId, 'spotify');
    });

    test('salt 가 같으면 계정 정보를 합친다', () async {
      credentials.metadata = metadataWith([1, 2, 3]);
      credentials.stored = [credential('spotify')];

      final result = await container.read(backupServiceProvider).import(
        BackupFile(
          exportedAt: DateTime(2026, 7, 24),
          subscriptions: const [],
          vaultMetadata: metadataWith([1, 2, 3]),
          credentials: [credential('netflix')],
        ),
      );

      expect(result.credentialsRestored, 1);
      expect(credentials.stored.length, 2);
    });
  });
}

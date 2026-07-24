import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/credential.dart';
import 'package:ninedogs/data/security/vault_crypto.dart';

/// 테스트에서는 반복 횟수를 낮춘다. 실제 앱은 VaultCrypto.iterations 를 쓴다.
const _testIterations = 1000;

Future<VaultCrypto> unlock(String password, List<int> salt) =>
    VaultCrypto.fromPassword(password, salt, iterations: _testIterations);

void main() {
  final salt = VaultCrypto.newSalt();

  group('암호화', () {
    test('암호화한 값을 같은 키로 다시 풀 수 있다', () async {
      final crypto = await unlock('우리집비밀번호', salt);
      final payload = await crypto.encrypt('netflix-password-1234');

      expect(await crypto.decrypt(payload), 'netflix-password-1234');
    });

    test('암호문에 평문이 남아 있지 않다', () async {
      final crypto = await unlock('우리집비밀번호', salt);
      final payload = await crypto.encrypt('netflix-password-1234');

      final serialized = jsonEncode(payload.toJson());
      expect(serialized, isNot(contains('netflix')));
      expect(serialized, isNot(contains('1234')));
    });

    test('같은 값을 두 번 암호화해도 암호문이 다르다', () async {
      final crypto = await unlock('우리집비밀번호', salt);
      final first = await crypto.encrypt('같은값');
      final second = await crypto.encrypt('같은값');

      // nonce 가 매번 달라야 같은 비밀번호를 쓰는 서비스가 드러나지 않는다
      expect(first.nonce, isNot(second.nonce));
      expect(first.cipherText, isNot(second.cipherText));
    });

    test('JSON 으로 왕복해도 풀린다', () async {
      final crypto = await unlock('우리집비밀번호', salt);
      final payload = await crypto.encrypt('비밀');

      final restored = EncryptedPayload.fromJson(
        jsonDecode(jsonEncode(payload.toJson())) as Map<String, Object?>,
      );
      expect(await crypto.decrypt(restored), '비밀');
    });
  });

  group('마스터 암호', () {
    test('다른 암호로는 풀리지 않는다', () async {
      final mine = await unlock('우리집비밀번호', salt);
      final payload = await mine.encrypt('비밀');

      final wrong = await unlock('틀린암호', salt);
      expect(
        () => wrong.decrypt(payload),
        throwsA(isA<VaultUnlockException>()),
      );
    });

    test('같은 암호와 salt 면 상대방 기기에서도 풀린다', () async {
      final myPhone = await unlock('우리집비밀번호', salt);
      final payload = await myPhone.encrypt('넷플릭스 비번');

      // 아내 폰: 같은 마스터 암호를 입력하면 같은 키가 나온다
      final herPhone = await unlock('우리집비밀번호', salt);
      expect(await herPhone.decrypt(payload), '넷플릭스 비번');
    });

    test('salt 가 다르면 같은 암호라도 열 수 없다', () async {
      final mine = await unlock('우리집비밀번호', salt);
      final payload = await mine.encrypt('비밀');

      final other = await unlock('우리집비밀번호', VaultCrypto.newSalt());
      expect(
        () => other.decrypt(payload),
        throwsA(isA<VaultUnlockException>()),
      );
    });

    test('확인용 값으로 암호가 맞는지 판별한다', () async {
      final crypto = await unlock('우리집비밀번호', salt);
      final verifier = await crypto.createVerifier();

      expect(await crypto.matchesVerifier(verifier), isTrue);

      final wrong = await unlock('틀린암호', salt);
      expect(await wrong.matchesVerifier(verifier), isFalse);
    });
  });

  group('변조 감지', () {
    test('암호문이 한 바이트라도 바뀌면 복호화가 실패한다', () async {
      final crypto = await unlock('우리집비밀번호', salt);
      final payload = await crypto.encrypt('비밀');

      final tampered = EncryptedPayload(
        nonce: payload.nonce,
        cipherText: [...payload.cipherText]..[0] ^= 0xFF,
        mac: payload.mac,
      );

      expect(
        () => crypto.decrypt(tampered),
        throwsA(isA<VaultUnlockException>()),
      );
    });
  });

  group('생체인증용 키 재사용', () {
    test('키 원본으로 복원하면 같은 값을 풀 수 있다', () async {
      final crypto = await unlock('우리집비밀번호', salt);
      final payload = await crypto.encrypt('비밀');

      // 기기 보안 저장소에 넣어둔 키로 암호 입력 없이 여는 경로
      final restored = VaultCrypto.fromKeyBytes(await crypto.exportKeyBytes());
      expect(await restored.decrypt(payload), '비밀');
    });

    test('키 길이가 32바이트가 아니면 거부한다', () {
      expect(
        () => VaultCrypto.fromKeyBytes(List.filled(16, 0)),
        throwsArgumentError,
      );
    });
  });

  group('Credential', () {
    test('암호화하면 아이디와 비밀번호가 드러나지 않는다', () async {
      final crypto = await unlock('우리집비밀번호', salt);
      const credential = Credential(
        id: 'c1',
        subscriptionId: 'netflix-1',
        loginId: 'jong0227@example.com',
        password: 'hunter2',
        loginMethod: LoginMethod.google,
      );

      final stored = await credential.encrypt(crypto);
      final serialized = jsonEncode(stored.toJson());

      expect(serialized, isNot(contains('jong0227')));
      expect(serialized, isNot(contains('hunter2')));
      // 어떤 구독의 것인지만 평문으로 남는다
      expect(serialized, contains('netflix-1'));
    });

    test('복호화하면 원래 값이 그대로 돌아온다', () async {
      final crypto = await unlock('우리집비밀번호', salt);
      const original = Credential(
        id: 'c1',
        subscriptionId: 'netflix-1',
        loginId: 'jong0227@example.com',
        password: 'hunter2',
        loginMethod: LoginMethod.google,
        memo: '프로필 2번',
      );

      final restored = await (await original.encrypt(crypto)).decrypt(crypto);

      expect(restored.loginId, original.loginId);
      expect(restored.password, original.password);
      expect(restored.loginMethod, LoginMethod.google);
      expect(restored.memo, '프로필 2번');
    });

    test('toString 에 비밀번호가 섞이지 않는다', () {
      const credential = Credential(
        id: 'c1',
        subscriptionId: 'netflix-1',
        loginId: 'jong0227@example.com',
        password: 'hunter2',
      );

      expect(credential.toString(), isNot(contains('hunter2')));
      expect(credential.toString(), isNot(contains('jong0227')));
    });
  });
}

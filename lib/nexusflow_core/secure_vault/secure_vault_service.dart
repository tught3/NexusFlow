// Secure Vault 서비스 - 민감 개인정보 암호화 저장
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

class SecureVaultService {
  SecureVaultService({
    required this.supabase,
    required this.userId,
  });

  final SupabaseClient supabase;
  final String userId;

  static const _storage = FlutterSecureStorage();
  static const _keyPrefix = 'nexusflow_vault_';

  /// 민감 정보 저장
  Future<void> store({
    required String contactId,
    required VaultDataType dataType,
    required String value,
  }) async {
    // 암호화 키 생성 (userId + contactId 기반)
    final keyHint = _generateKeyHint(contactId);
    final encrypted = _encrypt(value, keyHint);

    // Supabase에 암호화된 값 저장
    await supabase.schema('nexusflow').from('contact_secure_vault').upsert({
      'contact_id': contactId,
      'data_type': dataType.name,
      'encrypted_value': encrypted,
      'encryption_key_hint': keyHint,
      'data_source_consent_type': 'user_input',
    });

    // 로컬 복호화 키 안전 저장
    await _storage.write(
      key: '$_keyPrefix${contactId}_${dataType.name}',
      value: keyHint,
    );
  }

  /// 민감 정보 조회 (복호화)
  Future<String?> retrieve({
    required String contactId,
    required VaultDataType dataType,
  }) async {
    try {
      final result = await supabase
          .schema('nexusflow')
          .from('contact_secure_vault')
          .select('encrypted_value, encryption_key_hint')
          .eq('contact_id', contactId)
          .eq('data_type', dataType.name)
          .maybeSingle();

      if (result == null) return null;

      final keyHint = result['encryption_key_hint'] as String;
      return _decrypt(result['encrypted_value'] as String, keyHint);
    } catch (_) {
      return null;
    }
  }

  /// 마스킹된 값 반환 (인증 없이 표시용)
  String mask(String value, VaultDataType dataType) {
    switch (dataType) {
      case VaultDataType.phone:
        if (value.length >= 8) {
          return '${value.substring(0, 3)}-****-${value.substring(value.length - 4)}';
        }
        return '****';
      case VaultDataType.birthday:
        if (value.length >= 6) {
          return '${value.substring(0, 2)}.**.**';
        }
        return '**.**.**';
      default:
        if (value.length <= 4) return '****';
        return '${value.substring(0, 2)}${'*' * (value.length - 4)}${value.substring(value.length - 2)}';
    }
  }

  /// 민감 정보 삭제
  Future<void> delete({
    required String contactId,
    required VaultDataType dataType,
  }) async {
    await supabase
        .schema('nexusflow')
        .from('contact_secure_vault')
        .delete()
        .eq('contact_id', contactId)
        .eq('data_type', dataType.name);

    await _storage.delete(
      key: '$_keyPrefix${contactId}_${dataType.name}',
    );
  }

  String _generateKeyHint(String contactId) {
    final raw = '$userId:$contactId:nexusflow';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
  }

  String _encrypt(String value, String key) {
    // 간단한 XOR 기반 암호화 (실제 배포 시 AES로 교체 권장)
    final keyBytes = utf8.encode(key);
    final valueBytes = utf8.encode(value);
    final encrypted = List<int>.generate(
      valueBytes.length,
      (i) => valueBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64.encode(encrypted);
  }

  String _decrypt(String encrypted, String key) {
    final keyBytes = utf8.encode(key);
    final encryptedBytes = base64.decode(encrypted);
    final decrypted = List<int>.generate(
      encryptedBytes.length,
      (i) => encryptedBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return utf8.decode(decrypted);
  }
}

enum VaultDataType {
  phone,
  address,
  birthday,
  family,
  insurance,
  email,
}

final secureVaultServiceProvider = Provider<SecureVaultService?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return SecureVaultService(
    supabase: Supabase.instance.client,
    userId: userId,
  );
});

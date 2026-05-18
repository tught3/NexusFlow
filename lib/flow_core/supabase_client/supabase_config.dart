// Supabase 설정 - NexusFlow schema 기반 클라이언트
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;

  // nexusflow schema 테이블 접근 헬퍼
  static dynamic nexusflow(String table) =>
      client.schema('nexusflow').from(table);

  // planflow schema 테이블 접근 헬퍼 (PlanFlow 연동용)
  static dynamic planflow(String table) =>
      client.schema('planflow').from(table);

  // shared schema 테이블 접근 헬퍼
  static dynamic shared(String table) =>
      client.schema('shared').from(table);

  // 현재 로그인 유저 ID
  static String? get currentUserId =>
      client.auth.currentUser?.id;

  // 인증 상태 스트림
  static Stream<AuthState> get authStream =>
      client.auth.onAuthStateChange;

  // Google 로그인
  static Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(OAuthProvider.google);
  }

  // 로그아웃
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

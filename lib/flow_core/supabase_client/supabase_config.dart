// Supabase configuration helpers for NexusFlow.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;

  static dynamic nexusflow(String table) =>
      client.schema('nexusflow').from(table);

  static dynamic planflow(String table) =>
      client.schema('planflow').from(table);

  static dynamic shared(String table) =>
      client.schema('shared').from(table);

  static String? get currentUserId => client.auth.currentUser?.id;

  static Stream<AuthState> get authStream => client.auth.onAuthStateChange;

  static Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(OAuthProvider.google);
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// 거래처/담당자 데이터 프로바이더 — 화면은 직접 Supabase를 호출하지 않는다
// (테스트에서 provider override로 가짜 데이터 주입 가능 구조).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_provider.dart';

/// 거래처 목록 검색어
final accountsSearchProvider = StateProvider<String>((ref) => '');

/// 계정 데이터 갱신 트리거 — 증가시 accountsProvider/accountDetailProvider 재평가.
final refreshAccountDataProvider = StateProvider<int>((ref) => 0);

/// 거래처/담당자 Supabase 접근 리포지토리 (화면의 쓰기 액션도 여기를 경유).
class AccountRepository {
  AccountRepository({required this.supabase, this.userId});

  final SupabaseClient supabase;
  final String? userId;

  /// 액션 아이템 완료/복원
  Future<void> setActionItemStatus(
    String actionItemId, {
    required String status,
  }) async {
    final uid = userId;
    if (uid == null) throw StateError('로그인이 필요합니다');
    await supabase
        .from('action_items')
        .update({'status': status})
        .eq('id', actionItemId)
        .eq('user_id', uid);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    supabase: ref.watch(supabaseProvider),
    userId: ref.watch(currentUserIdProvider),
  );
});

/// 쿼리 실패 시 빈 리스트로 폴백 (스키마 컬럼/테이블 불일치 허용).
Future<List<Map<String, dynamic>>> _safeRows(
  Future<List<Map<String, dynamic>>> Function() run,
) async {
  try {
    return await run();
  } catch (_) {
    return [];
  }
}

/// 거래처 요약 목록 (이름 오름차순)
final accountsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  ref.watch(refreshAccountDataProvider);
  if (userId == null) return [];

  final supabase = ref.watch(supabaseProvider);
  final rows = await supabase
      .from('accounts')
      .select(
          'id,name,industry_mode,health_score,health_grade,health_updated_at')
      .eq('user_id', userId)
      .order('name');
  return List<Map<String, dynamic>>.from(rows);
});

/// 거래처 상세 묶음 모델
class AccountDetail {
  const AccountDetail({
    required this.account,
    required this.contacts,
    required this.interactionEvents,
    required this.actionItems,
    required this.activeSignals,
    required this.memories,
  });

  final Map<String, dynamic> account;
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> interactionEvents;
  final List<Map<String, dynamic>> actionItems;
  final List<Map<String, dynamic>> activeSignals;
  final List<Map<String, dynamic>> memories;
}

/// 거래처 상세 (계정 행 + 하위 리소스)
final accountDetailProvider =
    FutureProvider.family<AccountDetail, String>((ref, accountId) async {
  final userId = ref.watch(currentUserIdProvider);
  ref.watch(refreshAccountDataProvider);
  if (userId == null) throw StateError('로그인이 필요합니다');

  final supabase = ref.watch(supabaseProvider);
  final account = await supabase
      .from('accounts')
      .select()
      .eq('id', accountId)
      .eq('user_id', userId)
      .maybeSingle();
  if (account == null) throw StateError('거래처를 찾을 수 없습니다');

  final contacts = await _safeRows(() => supabase
      .from('contacts')
      .select('id,name,role')
      .eq('account_id', accountId)
      .eq('user_id', userId)
      .order('name'));
  final interactionEvents = await _safeRows(() => supabase
      .from('interaction_events')
      .select()
      .eq('account_id', accountId)
      .eq('user_id', userId)
      .order('occurred_at', ascending: false)
      .limit(50));
  final actionItems = await _safeRows(() => supabase
      .from('action_items')
      .select()
      .eq('account_id', accountId)
      .eq('user_id', userId)
      .order('status'));
  final activeSignals = await _safeRows(() => supabase
      .from('active_signals')
      .select('id,signal_type,signal_content')
      .eq('account_id', accountId)
      .eq('user_id', userId)
      .eq('is_active', true));
  final memories = await _safeRows(() => supabase
      .from('confirmed_memories')
      .select()
      .eq('account_id', accountId)
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(10));

  return AccountDetail(
    account: account,
    contacts: contacts,
    interactionEvents: interactionEvents,
    actionItems: actionItems,
    activeSignals: activeSignals,
    memories: memories,
  );
});

/// 담당자 상세 묶음 모델
class ContactDetail {
  const ContactDetail({
    required this.contact,
    required this.account,
    required this.interactionEvents,
    required this.availabilitySlots,
  });

  final Map<String, dynamic> contact;
  final Map<String, dynamic>? account;
  final List<Map<String, dynamic>> interactionEvents;
  final List<Map<String, dynamic>> availabilitySlots;
}

/// 담당자 상세 (담당자 행 + 소속 거래처 + 관련 이벤트)
final contactDetailProvider =
    FutureProvider.family<ContactDetail, String>((ref, contactId) async {
  final userId = ref.watch(currentUserIdProvider);
  ref.watch(refreshAccountDataProvider);
  if (userId == null) throw StateError('로그인이 필요합니다');

  final supabase = ref.watch(supabaseProvider);
  final contact = await supabase
      .from('contacts')
      .select()
      .eq('id', contactId)
      .eq('user_id', userId)
      .maybeSingle();
  if (contact == null) throw StateError('담당자를 찾을 수 없습니다');

  // interaction_events에 contact_id 컬럼이 없을 수 있다 —
  // account 기반 최근 목록을 먼저 확보한 뒤 contact 필터를 시도한다.
  final accountId = contact['account_id']?.toString();
  List<Map<String, dynamic>> events = [];
  Map<String, dynamic>? account;
  if (accountId != null && accountId.isNotEmpty) {
    account = await _safeSingle(() => supabase
        .from('accounts')
        .select('id,name,industry_mode')
        .eq('id', accountId)
        .eq('user_id', userId)
        .maybeSingle());
    events = await _safeRows(() => supabase
        .from('interaction_events')
        .select()
        .eq('account_id', accountId)
        .eq('user_id', userId)
        .order('occurred_at', ascending: false)
        .limit(50));
    try {
      final byContact = await supabase
          .from('interaction_events')
          .select()
          .eq('contact_id', contactId)
          .eq('user_id', userId)
          .order('occurred_at', ascending: false)
          .limit(50);
      events = List<Map<String, dynamic>>.from(byContact);
    } catch (_) {
      // contact_id 컬럼 없음 → account 이벤트 폴백 유지
    }
  }

  final availabilitySlots = await _safeRows(() => supabase
      .from('contact_availability_slots')
      .select()
      .eq('contact_id', contactId)
      .eq('user_id', userId)
      .order('created_at'));

  return ContactDetail(
    contact: contact,
    account: account,
    interactionEvents: events,
    availabilitySlots: availabilitySlots,
  );
});

/// 단일 행 조회 실패 시 null 폴백.
Future<Map<String, dynamic>?> _safeSingle(
  Future<Map<String, dynamic>?> Function() run,
) async {
  try {
    return await run();
  } catch (_) {
    return null;
  }
}

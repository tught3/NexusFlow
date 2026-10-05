// 인사이트 데이터 프로바이더 — 화면은 직접 Supabase를 호출하지 않는다
// (테스트에서 provider override로 가짜 데이터 주입 가능 구조).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_provider.dart';

/// 인사이트 목록 — 우선순위 desc, 생성 최신순.
/// 만료(expires_at null 또는 미래) 행만, 'suppressed' 상태는 제외.
/// 미로그인 시 빈 리스트. 쿼리 실패는 화면의 에러 상태(재시도)로 전달된다.
final insightsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final supabase = ref.watch(supabaseProvider);
  final rows = await supabase
      .from('insights')
      .select(
          'id,account_id,insight_type,content,status,priority_score,created_at')
      .eq('user_id', userId)
      .neq('status', 'suppressed')
      .or('expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}')
      .order('priority_score', ascending: false)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
});

/// 인사이트 상세 (인사이트 행 + 관련 거래처명)
class InsightDetail {
  const InsightDetail({required this.insight, this.accountName});

  final Map<String, dynamic> insight;
  final String? accountName;

  String? get accountId => insight['account_id']?.toString();
  String get id => insight['id']?.toString() ?? '';
  String get insightType => insight['insight_type']?.toString() ?? '';
  String get content => insight['content']?.toString() ?? '';
  String? get status => insight['status']?.toString();
}

/// 인사이트 상세 — 인사이트 행 + 거래처명(maybeSingle 폴백).
final insightDetailProvider =
    FutureProvider.family<InsightDetail, String>((ref, insightId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('로그인이 필요합니다');

  final supabase = ref.watch(supabaseProvider);
  final row = await supabase
      .from('insights')
      .select(
          'id,account_id,insight_type,content,status,priority_score,created_at')
      .eq('id', insightId)
      .eq('user_id', userId)
      .maybeSingle();
  if (row == null) throw StateError('인사이트를 찾을 수 없습니다');

  String? accountName;
  final accountId = row['account_id']?.toString();
  if (accountId != null && accountId.isNotEmpty) {
    try {
      final account = await supabase
          .from('accounts')
          .select('name')
          .eq('id', accountId)
          .maybeSingle();
      accountName = account?['name']?.toString();
    } catch (_) {
      // 거래처 조회 실패해도 인사이트 자체는 표시한다
    }
  }
  return InsightDetail(insight: row, accountName: accountName);
});

/// 인사이트 유형 필터 — 'all'|'today_action'|'opportunity'|'risk'|'visit_timing'
final insightFilterProvider = StateProvider<String>((ref) => 'all');

/// 인사이트 Supabase 접근 리포지토리 (화면의 쓰기 액션은 여기를 경유).
class InsightRepository {
  InsightRepository({required this.supabase, this.userId});

  final SupabaseClient supabase;
  final String? userId;

  /// 인사이트 7일간 그만 보기 (삭제가 아니라 억제)
  Future<void> suppressInsight(String insightId) async {
    final uid = userId;
    if (uid == null) throw StateError('로그인이 필요합니다');
    await supabase
        .from('insights')
        .update({
          'suppressed_until': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String(),
        })
        .eq('id', insightId)
        .eq('user_id', uid);
  }

  /// 피드백 저장. insight_feedback 스키마가 확정 전이라 insert 실패는
  /// 기록만 남기고, insights.status는 'reviewed'로 갱신한다.
  Future<void> sendFeedback(
    String insightId, {
    required bool helpful,
  }) async {
    final uid = userId;
    if (uid == null) throw StateError('로그인이 필요합니다');
    try {
      await supabase
          .from('insight_feedback')
          .insert({
            'user_id': uid,
            'insight_id': insightId,
            'helpful': helpful,
          });
    } catch (e) {
      debugPrint('insight_feedback insert failed: $e');
    }
    await supabase
        .from('insights')
        .update({'status': 'reviewed'})
        .eq('id', insightId)
        .eq('user_id', uid);
  }
}

final insightRepositoryProvider = Provider<InsightRepository>((ref) {
  return InsightRepository(
    supabase: ref.watch(supabaseProvider),
    userId: ref.watch(currentUserIdProvider),
  );
});

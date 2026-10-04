// 홈 화면 4존 요약 데이터 프로바이더 — 화면은 직접 Supabase를 호출하지 않는다.
// 개별 조회 실패는 각각 빈 값으로 폴백한다 (홈은 에러 화면이 되지 않는다).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_provider.dart';
import 'auth_provider.dart';

/// 홈 4존에 필요한 데이터 묶음.
class HomeSummary {
  const HomeSummary({
    required this.dueActions,
    required this.topAccounts,
    required this.recentInsights,
    this.lastInteractionText,
  });

  /// 마감 임박 팔로업 (status='pending', due_date <= 오늘+3일, 최대 5개)
  /// account_name 클라이언트 매핑됨.
  final List<Map<String, dynamic>> dueActions;

  /// 건강 점수 상위 거래처 (null 점수 제외, 최대 5개)
  final List<Map<String, dynamic>> topAccounts;

  /// 새 인사이트 (status='new', priority desc, 최대 5개)
  /// account_name 클라이언트 매핑됨.
  final List<Map<String, dynamic>> recentInsights;

  /// 최근 상호작용 요약 1건 (없으면 null)
  final String? lastInteractionText;

  static const HomeSummary empty = HomeSummary(
    dueActions: [],
    topAccounts: [],
    recentInsights: [],
  );
}

final homeSummaryProvider = FutureProvider<HomeSummary>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  ref.watch(refreshAccountDataProvider);
  if (userId == null) return HomeSummary.empty;

  final schema = ref.watch(supabaseProvider).schema('nexusflow');

  // 거래처 (last_interaction_at 컬럼 미확정 → 축소 선택 재시도)
  List<Map<String, dynamic>> accountRows;
  try {
    accountRows = List<Map<String, dynamic>>.from(await schema
        .from('accounts')
        .select('id,name,health_score,health_grade,last_interaction_at')
        .eq('user_id', userId));
  } catch (_) {
    try {
      accountRows = List<Map<String, dynamic>>.from(await schema
          .from('accounts')
          .select('id,name,health_score,health_grade')
          .eq('user_id', userId));
    } catch (_) {
      accountRows = const [];
    }
  }

  final accountNames = <String, String>{
    for (final row in accountRows)
      if (row['id'] != null)
        row['id'].toString(): row['name']?.toString() ?? '',
  };

  double healthScoreOf(Map<String, dynamic> row) =>
      num.tryParse(row['health_score']?.toString() ?? '')?.toDouble() ?? -1;

  final topAccounts = accountRows
      .where((row) => healthScoreOf(row) >= 0)
      .toList()
    ..sort((a, b) => healthScoreOf(b).compareTo(healthScoreOf(a)));

  // 마감 임박 팔로업
  List<Map<String, dynamic>> actionRows = const [];
  try {
    actionRows = List<Map<String, dynamic>>.from(await schema
        .from('action_items')
        .select('id,account_id,title,due_date')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .order('due_date')
        .limit(20));
  } catch (_) {}

  final now = DateTime.now();
  final dueLimit = DateTime(now.year, now.month, now.day + 3, 23, 59, 59);
  final dueActions = actionRows
      .where((row) {
        final due = DateTime.tryParse(row['due_date']?.toString() ?? '');
        return due != null && due.isBefore(dueLimit);
      })
      .take(5)
      .map((row) => <String, dynamic>{
            ...row,
            'account_name': accountNames[row['account_id']?.toString()] ?? '',
          })
      .toList();

  // 새 인사이트
  List<Map<String, dynamic>> insightRows = const [];
  try {
    insightRows = List<Map<String, dynamic>>.from(await schema
        .from('insights')
        .select(
            'id,account_id,insight_type,content,status,priority_score,created_at')
        .eq('user_id', userId)
        .eq('status', 'new')
        .order('priority_score', ascending: false)
        .order('created_at', ascending: false)
        .limit(5));
  } catch (_) {}
  final recentInsights = insightRows
      .map((row) => <String, dynamic>{
            ...row,
            'account_name': accountNames[row['account_id']?.toString()] ?? '',
          })
      .toList();

  // 최근 상호작용 1건 (summary 컬럼 미확정 → content 폴백)
  String? lastInteractionText;
  try {
    final row = await schema
        .from('interaction_events')
        .select('summary')
        .eq('user_id', userId)
        .order('occurred_at', ascending: false)
        .limit(1)
        .maybeSingle();
    lastInteractionText = row?['summary']?.toString();
  } catch (_) {
    try {
      final row = await schema
          .from('interaction_events')
          .select('content')
          .eq('user_id', userId)
          .order('occurred_at', ascending: false)
          .limit(1)
          .maybeSingle();
      lastInteractionText = row?['content']?.toString();
    } catch (_) {}
  }
  if (lastInteractionText != null && lastInteractionText.isEmpty) {
    lastInteractionText = null;
  }

  return HomeSummary(
    dueActions: dueActions,
    topAccounts: topAccounts.take(5).toList(),
    recentInsights: recentInsights,
    lastInteractionText: lastInteractionText,
  );
});

// 인사이트 엔진 - 관계 데이터 기반 인사이트 자동 생성
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

class InsightEngine {
  InsightEngine({required this.supabase, required this.userId});

  final SupabaseClient supabase;
  final String userId;

  Future<List<InsightResult>> generateAll() async {
    final insights = <InsightResult>[];
    insights.addAll(await _checkFollowUpDelays());
    insights.addAll(await _checkOpportunitySignals());
    insights.addAll(await _checkRiskSignals());
    insights.addAll(await _checkLongNoContact());
    insights.addAll(await _checkVisitTiming());
    final filtered = await _filterSuppressed(insights);
    for (final insight in filtered) {
      await _saveInsight(insight);
    }
    return filtered;
  }

  Future<List<InsightResult>> _checkFollowUpDelays() async {
    final overdueItems = await supabase
        .schema('nexusflow')
        .from('action_items')
        .select('id, content, due_date, account_id')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .lt('due_date', DateTime.now().toIso8601String());
    return (overdueItems as List).map((item) => InsightResult(
      accountId: item['account_id'] as String?,
      insightType: 'today_action',
      content: 'follow-up 기한이 지났어요: ${item['content']}',
      priorityScore: 1.5,
    )).toList();
  }

  Future<List<InsightResult>> _checkOpportunitySignals() async {
    final signals = await supabase
        .schema('nexusflow')
        .from('active_signals')
        .select('account_id, signal_content')
        .eq('user_id', userId)
        .eq('signal_type', 'opportunity')
        .eq('is_active', true);
    return (signals as List).map((s) => InsightResult(
      accountId: s['account_id'] as String?,
      insightType: 'opportunity',
      content: s['signal_content'] as String,
      priorityScore: 1.3,
    )).toList();
  }

  Future<List<InsightResult>> _checkRiskSignals() async {
    final signals = await supabase
        .schema('nexusflow')
        .from('active_signals')
        .select('account_id, signal_content')
        .eq('user_id', userId)
        .eq('signal_type', 'risk')
        .eq('is_active', true);
    return (signals as List).map((s) => InsightResult(
      accountId: s['account_id'] as String?,
      insightType: 'risk',
      content: s['signal_content'] as String,
      priorityScore: 1.4,
    )).toList();
  }

  Future<List<InsightResult>> _checkLongNoContact() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final accounts = await supabase
        .schema('nexusflow')
        .from('accounts')
        .select('id, name, last_contacted_at')
        .eq('user_id', userId)
        .lt('last_contacted_at', cutoff.toIso8601String())
        .lte('priority', 2);
    return (accounts as List).map((a) {
      final lastContact = DateTime.parse(a['last_contacted_at'] as String);
      final days = DateTime.now().difference(lastContact).inDays;
      return InsightResult(
        accountId: a['id'] as String?,
        insightType: 'risk',
        content: '${a['name']} - ${days}일간 접촉이 없었어요.',
        priorityScore: 1.2,
      );
    }).toList();
  }

  Future<List<InsightResult>> _checkVisitTiming() async {
    final today = DateTime.now().weekday;
    final slots = await supabase
        .schema('nexusflow')
        .from('contact_availability_slots')
        .select('contact_id, time_slot')
        .eq('day_of_week', today)
        .eq('is_available', true);
    return (slots as List).map((_) => InsightResult(
      accountId: null,
      insightType: 'visit_timing',
      content: '오늘 방문 가능한 담당자가 있어요.',
      priorityScore: 1.1,
    )).toList();
  }

  Future<List<InsightResult>> _filterSuppressed(
      List<InsightResult> insights) async {
    final suppressed = await supabase
        .schema('nexusflow')
        .from('insights')
        .select('content')
        .eq('user_id', userId)
        .not('suppressed_until', 'is', null)
        .gt('suppressed_until', DateTime.now().toIso8601String());
    final suppressedContents =
        (suppressed as List).map((s) => s['content'] as String).toSet();
    return insights
        .where((i) => !suppressedContents.contains(i.content))
        .toList();
  }

  Future<void> _saveInsight(InsightResult insight) async {
    final existing = await supabase
        .schema('nexusflow')
        .from('insights')
        .select('id')
        .eq('user_id', userId)
        .eq('content', insight.content)
        .gte('created_at',
            DateTime.now()
                .subtract(const Duration(hours: 24))
                .toIso8601String())
        .maybeSingle();
    if (existing != null) return;
    await supabase.schema('nexusflow').from('insights').insert({
      'user_id': userId,
      'account_id': insight.accountId,
      'insight_type': insight.insightType,
      'content': insight.content,
      'status': 'new',
      'priority_score': insight.priorityScore,
      'expires_at': DateTime.now()
          .add(const Duration(days: 7))
          .toIso8601String(),
    });
  }
}

class InsightResult {
  const InsightResult({
    required this.accountId,
    required this.insightType,
    required this.content,
    required this.priorityScore,
  });

  final String? accountId;
  final String insightType;
  final String content;
  final double priorityScore;
}

final insightEngineProvider = Provider<InsightEngine?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return InsightEngine(
    supabase: Supabase.instance.client,
    userId: userId,
  );
});

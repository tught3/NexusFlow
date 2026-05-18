// Relationship Health Score 계산 서비스
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

class HealthScoreService {
  HealthScoreService({required this.supabase, required this.userId});

  final SupabaseClient supabase;
  final String userId;

  static const int _contactFrequencyMax = 25;
  static const int _responseQualityMax = 25;
  static const int _reliabilityMax = 20;
  static const int _continuityMax = 20;
  static const int _opportunityMax = 10;

  Future<HealthScore> calculate(String accountId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final contactFrequency = await _calcContactFrequency(
      accountId: accountId, since: thirtyDaysAgo);
    final responseQuality = await _calcResponseQuality(accountId: accountId);
    final reliability = await _calcReliability(accountId: accountId);
    final continuity = await _calcContinuity(accountId: accountId);
    final opportunity = await _calcOpportunity(accountId: accountId);

    final total = contactFrequency + responseQuality +
        reliability + continuity + opportunity;
    final grade = _gradeFromScore(total);

    await supabase.schema('nexusflow').from('accounts').update({
      'health_score': total,
      'health_grade': grade,
      'health_contact_score': contactFrequency,
      'health_response_score': responseQuality,
      'health_reliability_score': reliability,
      'health_continuity_score': continuity,
      'health_opportunity_score': opportunity,
      'health_updated_at': now.toIso8601String(),
    }).eq('id', accountId).eq('user_id', userId);

    return HealthScore(
      accountId: accountId,
      total: total,
      grade: grade,
      contactFrequency: contactFrequency,
      responseQuality: responseQuality,
      reliability: reliability,
      continuity: continuity,
      opportunity: opportunity,
      calculatedAt: now,
    );
  }

  Future<void> recalculateAll() async {
    final accounts = await supabase
        .schema('nexusflow')
        .from('accounts')
        .select('id')
        .eq('user_id', userId);
    for (final account in accounts) {
      await calculate(account['id'] as String);
    }
  }

  Future<int> _calcContactFrequency({
    required String accountId,
    required DateTime since,
  }) async {
    final result = await supabase
        .schema('nexusflow')
        .from('interaction_events')
        .select('id')
        .eq('account_id', accountId)
        .eq('user_id', userId)
        .gte('occurred_at', since.toIso8601String());
    final count = (result as List).length;
    if (count >= 4) return _contactFrequencyMax;
    if (count >= 2) return 15;
    if (count >= 1) return 8;
    return 2;
  }

  Future<int> _calcResponseQuality({required String accountId}) async {
    final signals = await supabase
        .schema('nexusflow')
        .from('active_signals')
        .select('signal_type')
        .eq('account_id', accountId)
        .eq('user_id', userId)
        .eq('is_active', true);
    int score = 12;
    for (final signal in signals) {
      final type = signal['signal_type'] as String;
      if (type == 'opportunity') score += 5;
      if (type == 'risk') score -= 5;
    }
    return score.clamp(0, _responseQualityMax);
  }

  Future<int> _calcReliability({required String accountId}) async {
    final allItems = await supabase
        .schema('nexusflow')
        .from('action_items')
        .select('status')
        .eq('account_id', accountId)
        .eq('user_id', userId);
    if ((allItems as List).isEmpty) return 10;
    final doneCount = allItems.where((i) => i['status'] == 'done').length;
    final rate = doneCount / allItems.length;
    if (rate >= 0.8) return _reliabilityMax;
    if (rate >= 0.5) return 12;
    return 4;
  }

  Future<int> _calcContinuity({required String accountId}) async {
    final account = await supabase
        .schema('nexusflow')
        .from('accounts')
        .select('created_at')
        .eq('id', accountId)
        .single();
    final createdAt = DateTime.parse(account['created_at'] as String);
    final days = DateTime.now().difference(createdAt).inDays;
    if (days >= 365) return _continuityMax;
    if (days >= 180) return 12;
    return 8;
  }

  Future<int> _calcOpportunity({required String accountId}) async {
    final opportunities = await supabase
        .schema('nexusflow')
        .from('active_signals')
        .select('id')
        .eq('account_id', accountId)
        .eq('user_id', userId)
        .eq('signal_type', 'opportunity')
        .eq('is_active', true);
    if ((opportunities as List).isNotEmpty) return _opportunityMax;
    final risks = await supabase
        .schema('nexusflow')
        .from('active_signals')
        .select('id')
        .eq('account_id', accountId)
        .eq('user_id', userId)
        .eq('signal_type', 'risk')
        .eq('is_active', true);
    if ((risks as List).isNotEmpty) return 0;
    return 5;
  }

  String _gradeFromScore(int score) {
    if (score >= 80) return 'Strong';
    if (score >= 60) return 'Stable';
    if (score >= 40) return 'Warming';
    if (score >= 20) return 'AtRisk';
    return 'Critical';
  }
}

class HealthScore {
  const HealthScore({
    required this.accountId,
    required this.total,
    required this.grade,
    required this.contactFrequency,
    required this.responseQuality,
    required this.reliability,
    required this.continuity,
    required this.opportunity,
    required this.calculatedAt,
  });

  final String accountId;
  final int total;
  final String grade;
  final int contactFrequency;
  final int responseQuality;
  final int reliability;
  final int continuity;
  final int opportunity;
  final DateTime calculatedAt;

  Color get gradeColor {
    switch (grade) {
      case 'Strong': return const Color(0xFF16A34A);
      case 'Stable': return const Color(0xFF2563EB);
      case 'Warming': return const Color(0xFFF59E0B);
      case 'AtRisk': return const Color(0xFFEA580C);
      default: return const Color(0xFFDC2626);
    }
  }

  String get gradeLabel {
    switch (grade) {
      case 'Strong': return '🟢 Strong';
      case 'Stable': return '🔵 Stable';
      case 'Warming': return '🟡 Warming';
      case 'AtRisk': return '🟠 At Risk';
      default: return '🔴 Critical';
    }
  }
}

final healthScoreServiceProvider = Provider<HealthScoreService?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return HealthScoreService(
    supabase: Supabase.instance.client,
    userId: userId,
  );
});

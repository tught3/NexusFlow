// 업종 모드 서비스 - Dictionary/QuickAction/Prompt 업종별 관리
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

class IndustryModeService {
  IndustryModeService({
    required this.supabase,
    required this.userId,
  });

  final SupabaseClient supabase;
  final String userId;

  // 업종 모드 정보
  static const Map<String, IndustryModeInfo> modeInfos = {
    'pharma': IndustryModeInfo(
      code: 'pharma',
      label: '제약영업',
      description: '병원/의원 담당 MR',
      icon: '💊',
    ),
    'insurance': IndustryModeInfo(
      code: 'insurance',
      label: '보험영업',
      description: '보험설계사',
      icon: '🛡️',
    ),
    'general': IndustryModeInfo(
      code: 'general',
      label: '공통영업',
      description: '일반 B2B 영업사원',
      icon: '💼',
    ),
  };

  /// 현재 업종 모드 정보 반환
  IndustryModeInfo getModeInfo(String mode) {
    return modeInfos[mode] ?? modeInfos['general']!;
  }

  /// 업종별 Dictionary 로드
  Future<List<Map<String, dynamic>>> loadDictionary(String mode) async {
    final result = await supabase
        .schema('nexusflow')
        .from('term_dictionary')
        .select('term, meaning, dict_scope')
        .or('industry_mode.eq.$mode,industry_mode.eq.general')
        .eq('is_active', true)
        .order('dict_scope');
    return List<Map<String, dynamic>>.from(result);
  }

  /// 업종별 Quick Actions 로드
  Future<List<Map<String, dynamic>>> loadQuickActions(String mode) async {
    final result = await supabase
        .schema('nexusflow')
        .from('quick_actions')
        .select('label, action_type')
        .or('industry_mode.eq.$mode,industry_mode.eq.general')
        .order('label');
    return List<Map<String, dynamic>>.from(result);
  }

  /// 사용자 업종 모드 저장
  Future<void> saveUserMode(String mode) async {
    await supabase
        .schema('nexusflow')
        .from('industry_modes')
        .upsert({
          'user_id': userId,
          'mode_type': mode,
          'is_active': true,
        });
  }

  /// 사용자 업종 모드 로드
  Future<String> loadUserMode() async {
    final result = await supabase
        .schema('nexusflow')
        .from('industry_modes')
        .select('mode_type')
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();
    return result?['mode_type'] as String? ?? 'general';
  }

  /// Dictionary 학습 업데이트 (3회 확인 → User 승격)
  Future<void> updateLearning({
    required String term,
    required String meaning,
    required String mode,
  }) async {
    // 기존 learned 항목 확인
    final existing = await supabase
        .schema('nexusflow')
        .from('term_dictionary')
        .select('id, confidence_count, dict_scope')
        .eq('user_id', userId)
        .eq('term', term)
        .maybeSingle();

    if (existing == null) {
      // 신규 learned 항목 생성
      await supabase.schema('nexusflow').from('term_dictionary').insert({
        'user_id': userId,
        'industry_mode': mode,
        'term': term,
        'meaning': meaning,
        'dict_scope': 'learned',
        'confidence_count': 1,
        'is_active': true,
      });
    } else {
      final count = (existing['confidence_count'] as int? ?? 0) + 1;
      final newScope = count >= 3 ? 'user' : 'learned';

      await supabase
          .schema('nexusflow')
          .from('term_dictionary')
          .update({
            'confidence_count': count,
            'dict_scope': newScope,
            'promoted_from': count == 3 ? 'learned' : null,
          })
          .eq('id', existing['id']);
    }
  }
}

class IndustryModeInfo {
  const IndustryModeInfo({
    required this.code,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String code;
  final String label;
  final String description;
  final String icon;
}

final industryModeServiceProvider = Provider<IndustryModeService?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return IndustryModeService(
    supabase: Supabase.instance.client,
    userId: userId,
  );
});

final industryModeInfoProvider = Provider<IndustryModeInfo>((ref) {
  final mode = ref.watch(industryModeProvider);
  return IndustryModeService.modeInfos[mode] ??
      IndustryModeService.modeInfos['general']!;
});

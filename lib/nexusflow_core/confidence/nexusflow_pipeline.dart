import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../industry_modes/industry_mode_service.dart';
import 'nexusflow_ai_service.dart';
import '../../flow_core/voice_input/voice_text_cleanup_service.dart';

/// NexusFlow AI 파이프라인 전체 흐름
/// 입력 → 전처리 → Dictionary 매칭 → AI 구조화 → Confidence Routing → 저장
class NexusflowPipeline {
  NexusflowPipeline({
    required this.supabase,
    required this.userId,
    required this.industryMode,
  }) : _aiService = NexusflowAiService();

  final SupabaseClient supabase;
  final String userId;
  final String industryMode;
  final NexusflowAiService _aiService;

  // Confidence 기준값
  static const double _highThreshold = 0.80;
  static const double _midThreshold = 0.55;

  /// 메인 파이프라인 실행
  Future<NexusflowPipelineResult> process({
    required String rawText,
    required NexusflowInputSource source,
  }) async {
    // STEP 1. 원본 저장
    final rawSourceId = await _saveRawSource(rawText: rawText, source: source);

    // STEP 2. 전처리 (STT 보정)
    final cleanupResult = await _aiService.cleanupVoiceText(rawText);
    final cleanedText = cleanupResult.cleanedText;

    // STEP 3. PII 감지
    final piiFlags = _detectPii(cleanedText);

    // STEP 4. Dictionary 매칭
    final dictionary = await _loadDictionary();
    final dictionaryBonus = _matchDictionary(cleanedText, dictionary);

    // STEP 5. 기존 거래처/담당자 로드
    final accounts = await _loadAccounts();
    final contacts = await _loadContacts();

    // STEP 6. AI 구조화
    final extracted = await _aiService.parseRelationshipData(
      rawText: cleanedText,
      industryMode: industryMode,
      existingAccounts: accounts,
      existingContacts: contacts,
      dictionary: dictionary,
      now: DateTime.now(),
    );

    // STEP 7. Dictionary 보너스 적용
    final boosted = _applyDictionaryBonus(extracted, dictionaryBonus);

    // STEP 8. 종합 Confidence 계산
    final overallConfidence = _calculateOverallConfidence(boosted);

    // STEP 9. Confidence Routing
    final routingLevel = _route(overallConfidence);

    // STEP 10. AI 추출 결과 저장
    final extractionId = await _saveExtraction(
      rawSourceId: rawSourceId,
      extracted: boosted,
      overallConfidence: overallConfidence,
      routingLevel: routingLevel,
    );

    // STEP 11. HIGH면 자동 저장, 아니면 검수 대기
    if (routingLevel == ConfidenceLevel.high) {
      await _autoSave(extracted: boosted, extractionId: extractionId);
    } else {
      await _enqueueValidation(extractionId: extractionId);
    }

    return NexusflowPipelineResult(
      rawSourceId: rawSourceId,
      extractionId: extractionId,
      extracted: boosted,
      overallConfidence: overallConfidence,
      routingLevel: routingLevel,
      cleanedText: cleanedText,
      piiFlags: piiFlags,
    );
  }

  /// STEP 1. raw_sources 저장
  Future<String> _saveRawSource({
    required String rawText,
    required NexusflowInputSource source,
  }) async {
    final result = await supabase
        .from('nexusflow.raw_sources')
        .insert({
          'user_id': userId,
          'source_type': source.name,
          'raw_text': rawText,
          'user_consented_at': DateTime.now().toIso8601String(),
          'processed': false,
        })
        .select('id')
        .single();
    return result['id'] as String;
  }

  /// STEP 3. PII 감지
  Map<String, List<String>> _detectPii(String text) {
    final flags = <String, List<String>>{};

    // 전화번호
    final phones = RegExp(r'01[0-9]-?\d{3,4}-?\d{4}')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
    if (phones.isNotEmpty) flags['phone'] = phones;

    // 이메일
    final emails = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
    if (emails.isNotEmpty) flags['email'] = emails;

    // 금액
    final amounts = RegExp(r'\d+[,\d]*\s*만?\s*원')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
    if (amounts.isNotEmpty) flags['amount'] = amounts;

    return flags;
  }

  /// STEP 4. Dictionary 로드
  Future<List<Map<String, dynamic>>> _loadDictionary() async {
    final result = await supabase
        .schema('nexusflow')
        .from('term_dictionary')
        .select('term, meaning, dict_scope')
        .or('industry_mode.eq.$industryMode,industry_mode.eq.general')
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(result);
  }

  /// STEP 4. Dictionary 매칭 (보너스 계산)
  Map<String, double> _matchDictionary(
    String text,
    List<Map<String, dynamic>> dictionary,
  ) {
    final bonuses = <String, double>{};
    for (final entry in dictionary) {
      final term = entry['term']?.toString() ?? '';
      if (term.isNotEmpty && text.contains(term)) {
        bonuses[term] = 0.15;
      }
    }
    return bonuses;
  }

  /// STEP 5. 기존 거래처 로드
  Future<List<Map<String, dynamic>>> _loadAccounts() async {
    final result = await supabase
        .schema('nexusflow')
        .from('accounts')
        .select('id, name')
        .eq('user_id', userId)
        .limit(100);
    return List<Map<String, dynamic>>.from(result);
  }

  /// STEP 5. 기존 담당자 로드
  Future<List<Map<String, dynamic>>> _loadContacts() async {
    final result = await supabase
        .schema('nexusflow')
        .from('contacts')
        .select('id, name, role')
        .eq('user_id', userId)
        .limit(100);
    return List<Map<String, dynamic>>.from(result);
  }

  /// STEP 7. Dictionary 보너스 적용
  Map<String, dynamic> _applyDictionaryBonus(
    Map<String, dynamic> extracted,
    Map<String, double> bonuses,
  ) {
    if (bonuses.isEmpty) return extracted;
    final boosted = Map<String, dynamic>.from(extracted);
    // 매칭된 Dictionary 있으면 각 항목 confidence 최대 0.15 보너스
    final bonus = bonuses.values.fold(0.0, (a, b) => a + b).clamp(0.0, 0.15);

    for (final key in ['account', 'contact', 'product', 'schedule']) {
      final item = boosted[key];
      if (item is Map<String, dynamic> && item['confidence'] != null) {
        final current = (item['confidence'] as num).toDouble();
        boosted[key] = {
          ...item,
          'confidence': (current + bonus).clamp(0.0, 1.0),
        };
      }
    }
    return boosted;
  }

  /// STEP 8. 종합 Confidence 계산
  double _calculateOverallConfidence(Map<String, dynamic> extracted) {
    final weights = {
      'account': 2.0,
      'contact': 2.0,
      'product': 1.5,
      'schedule': 1.5,
    };

    double totalWeight = 0;
    double weightedSum = 0;

    for (final entry in weights.entries) {
      final item = extracted[entry.key];
      if (item is Map<String, dynamic> && item['confidence'] != null) {
        final confidence = (item['confidence'] as num).toDouble();
        weightedSum += confidence * entry.value;
        totalWeight += entry.value;
      }
    }

    if (totalWeight == 0) return 0.5;
    return (weightedSum / totalWeight).clamp(0.0, 1.0);
  }

  /// STEP 9. Confidence Routing
  ConfidenceLevel _route(double confidence) {
    if (confidence >= _highThreshold) return ConfidenceLevel.high;
    if (confidence >= _midThreshold) return ConfidenceLevel.mid;
    return ConfidenceLevel.low;
  }

  /// STEP 10. ai_extractions 저장
  Future<String> _saveExtraction({
    required String rawSourceId,
    required Map<String, dynamic> extracted,
    required double overallConfidence,
    required ConfidenceLevel routingLevel,
  }) async {
    final account = extracted['account'];
    final contact = extracted['contact'];
    final product = extracted['product'];
    final schedule = extracted['schedule'];

    final result = await supabase
        .schema('nexusflow')
        .from('ai_extractions')
        .insert({
          'raw_source_id': rawSourceId,
          'user_id': userId,
          'extracted_data': jsonEncode(extracted),
          'confidence_score': overallConfidence,
          'confidence_level': routingLevel.name,
          'status': routingLevel == ConfidenceLevel.high
              ? 'confirmed'
              : 'pending',
          'account_confidence':
              (account is Map ? account['confidence'] : null),
          'contact_confidence':
              (contact is Map ? contact['confidence'] : null),
          'product_confidence':
              (product is Map ? product['confidence'] : null),
          'schedule_confidence':
              (schedule is Map ? schedule['confidence'] : null),
        })
        .select('id')
        .single();
    return result['id'] as String;
  }

  /// STEP 11a. HIGH → 자동 저장
  Future<void> _autoSave({
    required Map<String, dynamic> extracted,
    required String extractionId,
  }) async {
    // 거래처 저장/업데이트
    final accountData = extracted['account'];
    String? accountId;
    if (accountData is Map<String, dynamic>) {
      accountId = await _upsertAccount(accountData['name']?.toString() ?? '');
    }

    // 담당자 저장/업데이트
    final contactData = extracted['contact'];
    if (contactData is Map<String, dynamic> && accountId != null) {
      await _upsertContact(
        name: contactData['name']?.toString() ?? '',
        role: contactData['role']?.toString(),
        accountId: accountId,
      );
    }

    // 인터랙션 이벤트 저장
    if (accountId != null) {
      await supabase.schema('nexusflow').from('interaction_events').insert({
        'user_id': userId,
        'account_id': accountId,
        'event_type': 'note',
        'summary': extracted['summary']?.toString() ?? '',
        'raw_source_id': extractionId,
      });
    }

    // 액션 아이템 저장
    final actionItems = extracted['action_items'];
    if (actionItems is List && accountId != null) {
      for (final item in actionItems) {
        if (item is Map<String, dynamic>) {
          await supabase.schema('nexusflow').from('action_items').insert({
            'user_id': userId,
            'account_id': accountId,
            'content': item['content']?.toString() ?? '',
            'due_date': item['due_date'],
            'status': 'pending',
          });
        }
      }
    }

    // 신호 저장
    final signals = extracted['signals'];
    if (signals is List && accountId != null) {
      for (final signal in signals) {
        if (signal is Map<String, dynamic>) {
          await supabase.schema('nexusflow').from('active_signals').insert({
            'user_id': userId,
            'account_id': accountId,
            'signal_type': signal['type']?.toString() ?? 'opportunity',
            'signal_content': signal['content']?.toString() ?? '',
            'is_active': true,
          });
        }
      }
    }
  }

  /// STEP 11b. MID/LOW → 검수 대기열 등록
  Future<void> _enqueueValidation({required String extractionId}) async {
    await supabase.schema('nexusflow').from('validation_queue').insert({
      'user_id': userId,
      'extraction_id': extractionId,
      'queue_status': 'pending',
    });
  }

  /// 거래처 upsert
  Future<String> _upsertAccount(String name) async {
    if (name.isEmpty) return '';
    final existing = await supabase
        .schema('nexusflow')
        .from('accounts')
        .select('id')
        .eq('user_id', userId)
        .eq('name', name)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final result = await supabase
        .schema('nexusflow')
        .from('accounts')
        .insert({
          'user_id': userId,
          'name': name,
          'industry_mode': industryMode,
        })
        .select('id')
        .single();
    return result['id'] as String;
  }

  /// 담당자 upsert
  Future<void> _upsertContact({
    required String name,
    String? role,
    required String accountId,
  }) async {
    if (name.isEmpty) return;
    final existing = await supabase
        .schema('nexusflow')
        .from('contacts')
        .select('id')
        .eq('user_id', userId)
        .eq('name', name)
        .eq('account_id', accountId)
        .maybeSingle();

    if (existing != null) return;

    await supabase.schema('nexusflow').from('contacts').insert({
      'user_id': userId,
      'account_id': accountId,
      'name': name,
      'role': role,
    });
  }
}

/// 입력 소스 타입
enum NexusflowInputSource {
  voice_memo,
  screenshot_ocr,
  sms,
  kakao_notification,
  call_transcript,
  file_upload,
  manual,
}

/// Confidence 레벨
enum ConfidenceLevel {
  high,
  mid,
  low,
}

/// 파이프라인 결과
class NexusflowPipelineResult {
  const NexusflowPipelineResult({
    required this.rawSourceId,
    required this.extractionId,
    required this.extracted,
    required this.overallConfidence,
    required this.routingLevel,
    required this.cleanedText,
    required this.piiFlags,
  });

  final String rawSourceId;
  final String extractionId;
  final Map<String, dynamic> extracted;
  final double overallConfidence;
  final ConfidenceLevel routingLevel;
  final String cleanedText;
  final Map<String, List<String>> piiFlags;
}


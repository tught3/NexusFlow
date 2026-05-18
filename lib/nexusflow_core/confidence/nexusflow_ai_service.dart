import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../flow_core/supabase_client/gpt_service.dart';
import '../../flow_core/voice_input/voice_text_cleanup_service.dart';

class NexusflowAiService {
  NexusflowAiService({
    http.Client? client,
    Uri? endpoint,
  })  : _client = client,
        _endpoint = endpoint ??
            Uri.parse(
                '${const String.fromEnvironment('SUPABASE_URL')}/functions/v1/openai-proxy');

  final http.Client? _client;
  final Uri _endpoint;

  static const String _model = 'gpt-4o-mini';
  static const Map<String, dynamic> _responseFormat = {'type': 'json_object'};

  /// 관계 데이터 추출 (핵심 메서드)
  Future<Map<String, dynamic>> parseRelationshipData({
    required String rawText,
    required String industryMode,
    required List<Map<String, dynamic>> existingAccounts,
    required List<Map<String, dynamic>> existingContacts,
    required List<Map<String, dynamic>> dictionary,
    required DateTime now,
  }) async {
    final systemPrompt = _buildSystemPrompt(
      industryMode: industryMode,
      dictionary: dictionary,
      now: now,
    );

    final userPrompt = _buildUserPrompt(
      rawText: rawText,
      existingAccounts: existingAccounts,
      existingContacts: existingContacts,
    );

    final content = await _requestCompletion(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      responseFormat: _responseFormat,
    );

    final parsed = _decodeJsonMap(content);
    if (parsed == null) {
      return _fallbackResult(rawText);
    }

    return parsed;
  }

  /// 음성 텍스트 보정 (flow_core에서 재사용)
  Future<VoiceTextCleanupResult> cleanupVoiceText(
    String rawText, {
    VoiceTextCleanupContext context = VoiceTextCleanupContext.add,
  }) async {
    final local = VoiceTextCleanupService.cleanLocally(rawText, context: context);
    if (!VoiceTextCleanupService.shouldAskAi(local.cleanedText)) {
      return local;
    }

    final content = await _requestCompletion(
      systemPrompt: _nexusflowVoiceCleanupPrompt,
      userPrompt: jsonEncode({'text': local.cleanedText}),
      responseFormat: _responseFormat,
    );

    final decoded = _decodeJsonMap(content);
    if (decoded == null) return local;

    final cleanedText = decoded['cleaned_text']?.toString().trim() ?? '';
    final changed = decoded['changed'] == true;
    final confidence = (decoded['confidence'] as num?)?.toDouble() ?? 0.0;

    if (!changed || confidence < 0.65 || cleanedText.isEmpty) {
      return local;
    }

    return VoiceTextCleanupResult(
      originalText: rawText.trim(),
      cleanedText: cleanedText,
      changed: true,
      method: VoiceTextCleanupMethod.ai,
      reason: decoded['reason']?.toString() ?? 'ai_cleanup',
      confidence: confidence,
    );
  }

  /// 브리핑 생성 (flow_core에서 재사용)
  Future<String> generateRelationshipBriefing({
    required String rawData,
    required bool isMorning,
  }) async {
    final content = await _requestCompletion(
      systemPrompt: isMorning
          ? _nexusflowMorningBriefingPrompt
          : _nexusflowEveningBriefingPrompt,
      userPrompt: rawData,
    );
    return content?.trim() ?? '';
  }

  String _buildSystemPrompt({
    required String industryMode,
    required List<Map<String, dynamic>> dictionary,
    required DateTime now,
  }) {
    final dictText = dictionary
        .map((d) => '${d['term']}: ${d['meaning']}')
        .join('\n');

    final modeLabel = {
          'pharma': '제약영업',
          'insurance': '보험영업',
          'general': '공통영업',
        }[industryMode] ??
        '공통영업';

    return '''
You are a Korean sales relationship data extractor for $modeLabel mode.
Today is ${now.toIso8601String().substring(0, 10)}, ${_koreanDayOfWeek(now.weekday)}.
Return only a valid JSON object.

Industry Dictionary:
$dictText

Required output keys:
- account: { name: string, confidence: number } or null
- contact: { name: string, role: string, confidence: number } or null
- product: { name: string, confidence: number } or null
- schedule: { date: string (YYYY-MM-DD), time_slot: string (morning/afternoon/evening/null), confidence: number } or null
- action_items: array of { content: string, due_date: string or null, confidence: number }
- signals: array of { type: string (opportunity/risk/followup/data_quality), content: string, confidence: number }
- summary: string (Korean, max 2 sentences)

Rules:
- Use dictionary terms to improve recognition accuracy
- confidence is 0.0 to 1.0
- Do not invent data not present in the input
- For dates, resolve relative expressions (다음주 화요일, 내일 오전) from today
- summary must be concise Korean description of what happened
''';
  }

  String _buildUserPrompt({
    required String rawText,
    required List<Map<String, dynamic>> existingAccounts,
    required List<Map<String, dynamic>> existingContacts,
  }) {
    final accountNames = existingAccounts
        .map((a) => a['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .take(50)
        .join(', ');

    final contactNames = existingContacts
        .map((c) => c['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .take(50)
        .join(', ');

    return jsonEncode({
      'text': rawText,
      'existing_accounts': accountNames,
      'existing_contacts': contactNames,
    });
  }

  Map<String, dynamic> _fallbackResult(String rawText) {
    return {
      'account': null,
      'contact': null,
      'product': null,
      'schedule': null,
      'action_items': [],
      'signals': [],
      'summary': rawText,
    };
  }

  String _koreanDayOfWeek(int weekday) {
    const days = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return days[(weekday - 1) % 7];
  }

  Future<String?> _requestCompletion({
    required String systemPrompt,
    required String userPrompt,
    Map<String, dynamic>? responseFormat,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client.post(
        _endpoint,
        headers: {
          'Authorization':
              'Bearer ${const String.fromEnvironment('SUPABASE_ANON_KEY')}',
          'apikey': const String.fromEnvironment('SUPABASE_ANON_KEY'),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          if (responseFormat != null) 'response_format': responseFormat,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;

      final message = choices.first['message'];
      if (message is! Map<String, dynamic>) return null;

      final content = message['content'];
      return content is String ? content : null;
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  Map<String, dynamic>? _decodeJsonMap(String? content) {
    if (content == null || content.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(content.trim());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(content.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}

const String _nexusflowVoiceCleanupPrompt = '''
You are a Korean STT cleanup assistant for a sales relationship app.
Return only a valid JSON object with these keys:
cleaned_text, changed, reason, confidence.

Task:
- Fix obvious STT errors in Korean sales/medical/insurance terms
- Correct hospital names, doctor names, product names when clearly misrecognized
- Do not change meaning or add new facts
- If unsure, return original with changed false and confidence below 0.65
''';

const String _nexusflowMorningBriefingPrompt = '''
당신은 영업사원의 관계 관리 비서입니다.
오늘 방문 예정 거래처와 follow-up 필요 고객을 자연스러운 한국어로 브리핑하세요.
각 항목은 한 문장으로, 거래처명, 담당자, 핵심 이슈를 포함하세요.
마크다운 없이 자연스러운 구어체로만 작성하세요.
''';

const String _nexusflowEveningBriefingPrompt = '''
당신은 영업사원의 관계 관리 비서입니다.
오늘 방문한 거래처 요약과 내일 준비사항을 자연스러운 한국어로 브리핑하세요.
각 항목은 한 문장으로, 거래처명, 담당자, 핵심 내용을 포함하세요.
마크다운 없이 자연스러운 구어체로만 작성하세요.
''';

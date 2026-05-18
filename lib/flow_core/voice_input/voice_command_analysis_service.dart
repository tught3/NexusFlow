import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/env.dart';
import '../core/event_metadata.dart';
import '../core/local_time.dart';
import 'gpt_service.dart';
import 'remote_config_service.dart';
import 'voice_command_router.dart';
import 'voice_text_cleanup_service.dart';

enum VoiceCommandAnalysisStage {
  partial,
  complete,
}

enum VoiceCommandIntent {
  add,
  edit,
  delete,
  query,
  choose,
}

enum VoiceCommandAnalysisMethod {
  none,
  local,
  ai,
  cache,
}

class VoiceAnalysisRequestBudget {
  VoiceAnalysisRequestBudget({
    required this.maxAiRequests,
  });

  final int maxAiRequests;
  int _usedAiRequests = 0;

  int get usedAiRequests => _usedAiRequests;

  int get remainingAiRequests => maxAiRequests - _usedAiRequests;

  bool get hasRemaining => _usedAiRequests < maxAiRequests;

  bool tryConsume([int amount = 1]) {
    if (amount <= 0) {
      return true;
    }
    if (_usedAiRequests + amount > maxAiRequests) {
      return false;
    }
    _usedAiRequests += amount;
    return true;
  }

  void reset() {
    _usedAiRequests = 0;
  }
}

class VoiceCommandAnalysisResult {
  const VoiceCommandAnalysisResult({
    required this.rawText,
    required this.cleanedText,
    required this.normalizedText,
    required this.intent,
    required this.confidence,
    required this.uncertainFields,
    required this.scheduleFields,
    required this.targetEventHint,
    required this.requestedChanges,
    required this.method,
    required this.stage,
    required this.analysisSignature,
    required this.fromCache,
  });

  final String rawText;
  final String cleanedText;
  final String normalizedText;
  final VoiceCommandIntent intent;
  final double confidence;
  final List<String> uncertainFields;
  final Map<String, dynamic> scheduleFields;
  final Map<String, dynamic>? targetEventHint;
  final List<String> requestedChanges;
  final VoiceCommandAnalysisMethod method;
  final VoiceCommandAnalysisStage stage;
  final String analysisSignature;
  final bool fromCache;

  bool get usedAi =>
      method == VoiceCommandAnalysisMethod.ai ||
      method == VoiceCommandAnalysisMethod.cache;

  bool get isLocalOnly => method == VoiceCommandAnalysisMethod.local;

  VoiceCommandAnalysisResult copyWith({
    String? rawText,
    String? cleanedText,
    String? normalizedText,
    VoiceCommandIntent? intent,
    double? confidence,
    List<String>? uncertainFields,
    Map<String, dynamic>? scheduleFields,
    Map<String, dynamic>? targetEventHint,
    List<String>? requestedChanges,
    VoiceCommandAnalysisMethod? method,
    VoiceCommandAnalysisStage? stage,
    String? analysisSignature,
    bool? fromCache,
  }) {
    return VoiceCommandAnalysisResult(
      rawText: rawText ?? this.rawText,
      cleanedText: cleanedText ?? this.cleanedText,
      normalizedText: normalizedText ?? this.normalizedText,
      intent: intent ?? this.intent,
      confidence: confidence ?? this.confidence,
      uncertainFields: uncertainFields ?? this.uncertainFields,
      scheduleFields: scheduleFields ?? this.scheduleFields,
      targetEventHint: targetEventHint ?? this.targetEventHint,
      requestedChanges: requestedChanges ?? this.requestedChanges,
      method: method ?? this.method,
      stage: stage ?? this.stage,
      analysisSignature: analysisSignature ?? this.analysisSignature,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  Map<String, dynamic> toParsedScheduleMap() {
    final schedule = <String, dynamic>{
      'parse_failed': false,
      'raw_text': rawText,
      'title': scheduleFields['title'] ?? normalizedText,
      'date': scheduleFields['date'],
      'start_at': scheduleFields['start_at'],
      'end_at': scheduleFields['end_at'],
      'location': scheduleFields['location'],
      'location_lat': scheduleFields['location_lat'],
      'location_lng': scheduleFields['location_lng'],
      'travel_origin_lat': scheduleFields['travel_origin_lat'],
      'travel_origin_lng': scheduleFields['travel_origin_lng'],
      'travel_mode': scheduleFields['travel_mode'],
      'memo': scheduleFields['memo'],
      'supplies': scheduleFields['supplies'] ?? <String>[],
      'is_critical': scheduleFields['is_critical'] ?? false,
      'recurrence_rule': scheduleFields['recurrence_rule'],
      'is_all_day': scheduleFields['is_all_day'] ?? false,
      'is_multi_day': scheduleFields['is_multi_day'] ?? false,
      'category': scheduleFields['category'] ?? 'Í∏∞Ì?',
      'pre_actions': scheduleFields['pre_actions'] ?? <Map<String, dynamic>>[],
      'normalized_text': normalizedText,
      'voice_intent': intent.name,
      'confidence': confidence,
      'uncertain_fields': uncertainFields,
    };
    if (targetEventHint != null) {
      schedule['target_event_hint'] = targetEventHint;
    }
    if (requestedChanges.isNotEmpty) {
      schedule['requested_changes'] = requestedChanges;
    }
    return schedule;
  }
}

class VoiceCommandAnalysisService {
  VoiceCommandAnalysisService({
    http.Client? client,
    Uri? endpoint,
    DateTime Function()? now,
    int maxAiRequests = 3,
  })  : _client = client,
        _endpoint = endpoint ??
            Uri.parse('${AppEnv.supabaseUrl}/functions/v1/openai-proxy'),
        _now = now ?? planflowNow,
        _sessionBudget =
            VoiceAnalysisRequestBudget(maxAiRequests: maxAiRequests);

  final http.Client? _client;
  final Uri _endpoint;
  final DateTime Function() _now;
  final VoiceAnalysisRequestBudget _sessionBudget;
  final Map<String, VoiceCommandAnalysisResult> _aiCache =
      <String, VoiceCommandAnalysisResult>{};
  static const VoiceCommandRouter _router = VoiceCommandRouter();

  VoiceCommandAnalysisResult? _latestDraft;

  static const Map<String, dynamic> _responseFormat = <String, dynamic>{
    'type': 'json_object',
  };

  VoiceCommandAnalysisResult? get latestDraft => _latestDraft;

  void resetSession() {
    _aiCache.clear();
    _latestDraft = null;
    _sessionBudget.reset();
  }

  bool shouldRequestAi(
    String rawText, {
    VoiceCommandAnalysisStage stage = VoiceCommandAnalysisStage.partial,
    VoiceTextCleanupContext context = VoiceTextCleanupContext.add,
    Iterable<VoiceTextCleanupCandidate> candidates = const [],
    VoiceCommandAnalysisResult? previousDraft,
  }) {
    final cleanup = VoiceTextCleanupService.cleanLocally(
      rawText,
      context: context,
      candidates: candidates,
    );
    final normalized = cleanup.cleanedText;

    if (stage == VoiceCommandAnalysisStage.complete) {
      return true;
    }
    if (VoiceTextCleanupService.shouldAskAi(normalized)) {
      return true;
    }
    if (_hasCommandCue(normalized) || _hasScheduleCue(normalized)) {
      return true;
    }
    if (previousDraft != null &&
        hasMeaningfulChange(previousDraft.normalizedText, normalized)) {
      return _hasCommandCue(normalized) || _hasScheduleCue(normalized);
    }
    return false;
  }

  Future<VoiceCommandAnalysisResult> analyze(
    String rawText, {
    VoiceCommandAnalysisStage stage = VoiceCommandAnalysisStage.partial,
    VoiceTextCleanupContext context = VoiceTextCleanupContext.add,
    Iterable<VoiceTextCleanupCandidate> candidates = const [],
    VoiceAnalysisRequestBudget? budget,
    VoiceCommandAnalysisResult? previousDraft,
  }) async {
    final cleanup = VoiceTextCleanupService.cleanLocally(
      rawText,
      context: context,
      candidates: candidates,
    );
    final normalized = cleanup.cleanedText;
    final signature = analysisSignatureFor(
      normalized,
      context: context,
      candidates: candidates,
    );
    final effectivePreviousDraft = previousDraft ?? _latestDraft;
    final cacheHit = _aiCache[signature];
    if (cacheHit != null) {
      final cachedResult = cacheHit.copyWith(
        rawText: cleanup.originalText,
        cleanedText: normalized,
        fromCache: true,
        method: VoiceCommandAnalysisMethod.cache,
        stage: stage,
      );
      _latestDraft = cachedResult;
      return cachedResult;
    }

    final localResult = _buildLocalResult(
      cleanup: cleanup,
      stage: stage,
      context: context,
      candidates: candidates,
      signature: signature,
    );

    final shouldRequest = shouldRequestAi(
      rawText,
      stage: stage,
      context: context,
      candidates: candidates,
      previousDraft: effectivePreviousDraft,
    );
    final effectiveBudget = budget ?? _sessionBudget;
    if (!shouldRequest || !effectiveBudget.tryConsume()) {
      _latestDraft = localResult;
      return localResult;
    }

    final candidateLines = candidates.take(12).map((candidate) {
      final startAt = candidate.startAt?.toIso8601String() ?? '?úÍ∞Ñ ÎØ∏Ï†ï';
      final location = candidate.location?.trim();
      return '- ?úÎ™©: ${candidate.title}, ?•ÏÜå: ${location == null || location.isEmpty ? '?ÜÏùå' : location}, ?úÏûë: $startAt';
    }).join('\n');

    final content = await _requestCompletion(
      systemPrompt: _voiceCommandAnalysisPrompt,
      userPrompt: jsonEncode(<String, dynamic>{
        'stage': stage.name,
        'context': context.name,
        'text': normalized,
        'raw_text': cleanup.originalText,
        if (effectivePreviousDraft != null)
          'previous_draft': <String, dynamic>{
            'normalized_text': effectivePreviousDraft.normalizedText,
            'intent': effectivePreviousDraft.intent.name,
            'confidence': effectivePreviousDraft.confidence,
            'schedule_fields': effectivePreviousDraft.scheduleFields,
            if (effectivePreviousDraft.targetEventHint != null)
              'target_event_hint': effectivePreviousDraft.targetEventHint,
            if (effectivePreviousDraft.requestedChanges.isNotEmpty)
              'requested_changes': effectivePreviousDraft.requestedChanges,
          },
        if (candidateLines.isNotEmpty) 'candidate_events': candidateLines,
      }),
      responseFormat: _responseFormat,
    );
    final parsed = _decodeJsonMap(content);
    if (parsed == null) {
      _latestDraft = localResult;
      return localResult;
    }

    final aiResult = _buildAiResult(
      parsed: parsed,
      cleanup: cleanup,
      stage: stage,
      context: context,
      candidates: candidates,
      signature: signature,
      fallback: localResult,
    );
    _aiCache[signature] = aiResult;
    _latestDraft = aiResult;
    return aiResult;
  }

  VoiceCommandAnalysisResult _buildLocalResult({
    required VoiceTextCleanupResult cleanup,
    required VoiceCommandAnalysisStage stage,
    required VoiceTextCleanupContext context,
    required Iterable<VoiceTextCleanupCandidate> candidates,
    required String signature,
  }) {
    final normalized = cleanup.cleanedText;
    final intent = _inferLocalIntent(normalized, context: context);
    final targetEventHint = _buildTargetEventHint(
      normalized,
      candidates,
      context: context,
    );
    final requestedChanges = _inferRequestedChanges(normalized);
    final startAt = GptService(now: _now).inferStartAtFromRawText(normalized);
    final scheduleFields = _normalizeScheduleFields(
      <String, dynamic>{
        'title': _deriveLocalTitle(normalized),
        'date': null,
        'start_at': startAt?.toIso8601String(),
        'end_at': null,
        'location': null,
        'location_lat': null,
        'location_lng': null,
        'travel_origin_lat': null,
        'travel_origin_lng': null,
        'travel_mode': null,
        'memo': null,
        'supplies': <String>[],
        'is_critical': false,
        'recurrence_rule': null,
        'is_all_day': false,
        'is_multi_day': false,
        'category': _inferCategoryFromRawText(normalized),
        'pre_actions': <Map<String, dynamic>>[],
      },
      rawText: cleanup.originalText,
      normalizedText: normalized,
      intent: intent,
      fallbackStartAt: startAt,
    );
    final uncertainFields = _localUncertainFields(
      intent: intent,
      scheduleFields: scheduleFields,
      targetEventHint: targetEventHint,
      requestedChanges: requestedChanges,
      context: context,
    );

    return VoiceCommandAnalysisResult(
      rawText: cleanup.originalText,
      cleanedText: cleanup.cleanedText,
      normalizedText: normalized,
      intent: intent,
      confidence: _localConfidence(
        normalized: normalized,
        intent: intent,
        scheduleFields: scheduleFields,
        targetEventHint: targetEventHint,
      ),
      uncertainFields: uncertainFields,
      scheduleFields: Map<String, dynamic>.unmodifiable(scheduleFields),
      targetEventHint: targetEventHint == null
          ? null
          : Map<String, dynamic>.unmodifiable(targetEventHint),
      requestedChanges: List<String>.unmodifiable(requestedChanges),
      method: VoiceCommandAnalysisMethod.local,
      stage: stage,
      analysisSignature: signature,
      fromCache: false,
    );
  }

  VoiceCommandAnalysisResult _buildAiResult({
    required Map<String, dynamic> parsed,
    required VoiceTextCleanupResult cleanup,
    required VoiceCommandAnalysisStage stage,
    required VoiceTextCleanupContext context,
    required Iterable<VoiceTextCleanupCandidate> candidates,
    required String signature,
    required VoiceCommandAnalysisResult fallback,
  }) {
    final normalizedText = _normalizeText(
      parsed['normalized_text']?.toString(),
      fallback.cleanedText,
    );
    final intent =
        _parseIntent(parsed['intent']?.toString()) ?? fallback.intent;
    final uncertainFields = _normalizeStringList(parsed['uncertain_fields']);
    final requestedChanges = _normalizeStringList(parsed['requested_changes']);
    final scheduleFields = _buildScheduleFieldsFromResponse(
      parsed: parsed,
      rawText: cleanup.originalText,
      normalizedText: normalizedText,
      fallback: fallback,
      intent: intent,
    );
    final targetEventHint = _normalizeTargetEventHint(
      parsed['target_event_hint'],
      fallback: fallback,
      candidates: candidates,
      normalizedText: normalizedText,
      context: context,
    );
    final confidence = _clampConfidence(
      _doubleValue(parsed['confidence']) ?? fallback.confidence,
      fallback.confidence,
    );

    return VoiceCommandAnalysisResult(
      rawText: cleanup.originalText,
      cleanedText: cleanup.cleanedText,
      normalizedText: normalizedText,
      intent: intent,
      confidence: confidence,
      uncertainFields: uncertainFields.isEmpty
          ? _localUncertainFields(
              intent: intent,
              scheduleFields: scheduleFields,
              targetEventHint: targetEventHint,
              requestedChanges: requestedChanges,
              context: context,
            )
          : List<String>.unmodifiable(uncertainFields),
      scheduleFields: Map<String, dynamic>.unmodifiable(scheduleFields),
      targetEventHint: targetEventHint == null
          ? null
          : Map<String, dynamic>.unmodifiable(targetEventHint),
      requestedChanges: List<String>.unmodifiable(requestedChanges),
      method: VoiceCommandAnalysisMethod.ai,
      stage: stage,
      analysisSignature: signature,
      fromCache: false,
    );
  }

  Map<String, dynamic> _buildScheduleFieldsFromResponse({
    required Map<String, dynamic> parsed,
    required String rawText,
    required String normalizedText,
    required VoiceCommandAnalysisResult fallback,
    required VoiceCommandIntent intent,
  }) {
    final rawFields = parsed['schedule_fields'];
    Map<String, dynamic>? source;
    if (rawFields is Map) {
      source = Map<String, dynamic>.from(rawFields);
    } else {
      final allowedKeys = <String>{
        'title',
        'date',
        'start_at',
        'end_at',
        'location',
        'location_lat',
        'location_lng',
        'travel_origin_lat',
        'travel_origin_lng',
        'travel_mode',
        'memo',
        'supplies',
        'is_critical',
        'recurrence_rule',
        'is_all_day',
        'is_multi_day',
        'category',
        'pre_actions',
      };
      source = <String, dynamic>{};
      for (final entry in parsed.entries) {
        if (allowedKeys.contains(entry.key)) {
          source[entry.key] = entry.value;
        }
      }
    }

    return _normalizeScheduleFields(
      source,
      rawText: rawText,
      normalizedText: normalizedText,
      fallback: fallback,
      fallbackStartAt: _parseDateTime(fallback.scheduleFields['start_at']),
      intent: intent,
    );
  }

  Map<String, dynamic> _normalizeScheduleFields(
    Map<String, dynamic>? fields, {
    required String rawText,
    required String normalizedText,
    required VoiceCommandIntent intent,
    DateTime? fallbackStartAt,
    VoiceCommandAnalysisResult? fallback,
  }) {
    final source = fields ?? <String, dynamic>{};
    final gpt = GptService(now: _now);
    final inferredStartAt = _parseDateTime(source['start_at']) ??
        fallbackStartAt ??
        gpt.inferStartAtFromRawText(normalizedText) ??
        gpt.inferStartAtFromRawText(rawText) ??
        _parseDateTime(fallback?.scheduleFields['start_at']);
    final titleSource = _extractContentClause(normalizedText) ??
        _stripExplicitMemoClause(normalizedText);
    final sourceTitle = _normalizeText(source['title']?.toString(), null);
    final title = sourceTitle.isNotEmpty
        ? _deriveLocalTitle(sourceTitle)
        : _deriveLocalTitle(titleSource);
    final normalizedLocationText =
        _normalizeText(source['location']?.toString(), null);
    final inferredLocation = normalizedLocationText.isNotEmpty
        ? normalizedLocationText
        : _extractLeadingLocation(titleSource) ??
            _extractLeadingLocation(title);

    final scheduleFields = <String, dynamic>{
      'title': title.isEmpty ? titleSource : title,
      'date': source['date'],
      'start_at': inferredStartAt?.toIso8601String(),
      'end_at': _normalizeDateTime(source['end_at'])?.toIso8601String(),
      'location': inferredLocation == null
          ? null
          : _normalizeSpacingForSchedule(inferredLocation),
      'location_lat': _doubleValue(source['location_lat']),
      'location_lng': _doubleValue(source['location_lng']),
      'travel_origin_lat': _doubleValue(source['travel_origin_lat']),
      'travel_origin_lng': _doubleValue(source['travel_origin_lng']),
      'travel_mode': _normalizeText(source['travel_mode']?.toString(), null),
      'memo': _extractExplicitMemo(rawText),
      'supplies': _normalizeStringList(source['supplies']),
      'is_critical': source['is_critical'] == true,
      'recurrence_rule': _normalizeText(
        source['recurrence_rule']?.toString(),
        _inferLocalRecurrence(normalizedText),
      ),
      'is_all_day': source['is_all_day'] == true,
      'is_multi_day': source['is_multi_day'] == true,
      'category': _normalizeCategory(
        _normalizeText(
          source['category']?.toString(),
          _inferCategoryFromRawText(normalizedText),
        ),
      ),
      'pre_actions': _normalizePreActions(source['pre_actions']),
      'voice_intent': intent.name,
    };
    _preserveDeliveryContent(scheduleFields, titleSource);
    return scheduleFields;
  }

  Map<String, dynamic>? _normalizeTargetEventHint(
    Object? targetEventHint, {
    required VoiceCommandAnalysisResult fallback,
    required Iterable<VoiceTextCleanupCandidate> candidates,
    required String normalizedText,
    required VoiceTextCleanupContext context,
  }) {
    if (targetEventHint is Map) {
      final hint = Map<String, dynamic>.from(targetEventHint);
      final title = _normalizeText(hint['title']?.toString(), null);
      final location = _normalizeText(hint['location']?.toString(), null);
      final startAt = _parseDateTime(hint['start_at']);
      return <String, dynamic>{
        if (title.isNotEmpty) 'title': title,
        if (location.isNotEmpty) 'location': location,
        if (startAt != null) 'start_at': startAt.toIso8601String(),
        if (hint['candidate_index'] != null)
          'candidate_index': hint['candidate_index'],
        if (hint['score'] != null) 'score': hint['score'],
      };
    }

    if (targetEventHint is String && targetEventHint.trim().isNotEmpty) {
      return <String, dynamic>{'title': targetEventHint.trim()};
    }

    return _buildTargetEventHint(
          normalizedText,
          candidates,
          context: context,
        ) ??
        fallback.targetEventHint;
  }

  Map<String, dynamic>? _buildTargetEventHint(
    String text,
    Iterable<VoiceTextCleanupCandidate> candidates, {
    required VoiceTextCleanupContext context,
  }) {
    return _router.buildTargetEventHint(
      text,
      candidates,
      context: context,
    );
  }

  List<String> _inferRequestedChanges(String text) {
    return _router.extractRequestedChanges(text);
  }

  List<String> _localUncertainFields({
    required VoiceCommandIntent intent,
    required Map<String, dynamic> scheduleFields,
    required Map<String, dynamic>? targetEventHint,
    required List<String> requestedChanges,
    required VoiceTextCleanupContext context,
  }) {
    final fields = <String>{};
    if (intent == VoiceCommandIntent.add &&
        (scheduleFields['start_at'] == null ||
            scheduleFields['start_at'].toString().trim().isEmpty)) {
      fields.add('start_at');
    }
    if (context != VoiceTextCleanupContext.add && targetEventHint == null) {
      fields.add('target_event_hint');
    }
    if (context != VoiceTextCleanupContext.add && requestedChanges.isEmpty) {
      fields.add('requested_changes');
    }
    return fields.toList(growable: false);
  }

  double _localConfidence({
    required String normalized,
    required VoiceCommandIntent intent,
    required Map<String, dynamic> scheduleFields,
    required Map<String, dynamic>? targetEventHint,
  }) {
    var confidence = 0.3;
    if (_hasCommandCue(normalized) || _hasScheduleCue(normalized)) {
      confidence += 0.2;
    }
    if (scheduleFields['start_at'] != null) {
      confidence += 0.2;
    }
    if (targetEventHint != null) {
      confidence += 0.15;
    }
    if (intent != VoiceCommandIntent.add) {
      confidence += 0.1;
    }
    return confidence.clamp(0.05, 0.95).toDouble();
  }

  VoiceCommandIntent _inferLocalIntent(
    String text, {
    required VoiceTextCleanupContext context,
  }) {
    return switch (_router.resolveIntent(text, context: context)) {
      VoiceCommandRouteIntent.add => VoiceCommandIntent.add,
      VoiceCommandRouteIntent.edit => VoiceCommandIntent.edit,
      VoiceCommandRouteIntent.delete => VoiceCommandIntent.delete,
      VoiceCommandRouteIntent.query => VoiceCommandIntent.query,
      VoiceCommandRouteIntent.choose => VoiceCommandIntent.choose,
    };
  }

  VoiceCommandIntent? _parseIntent(String? rawIntent) {
    final normalized = rawIntent?.trim().toLowerCase();
    return switch (normalized) {
      'add' => VoiceCommandIntent.add,
      'edit' => VoiceCommandIntent.edit,
      'delete' => VoiceCommandIntent.delete,
      'query' => VoiceCommandIntent.query,
      'choose' => VoiceCommandIntent.choose,
      _ => null,
    };
  }

  bool _hasCommandCue(String text) {
    final normalized = _normalizeText(text, '');
    return RegExp(
      r'(Ï∂îÍ?|?±Î°ù|?Ä???!?????òÏñ¥|??|?àÎ°ú|Í∏∞Î°ù|Î©îÎ™®|?àÏïΩ|ÎßåÎì§???¥Ï§ò|?¥Ï§Ñ??Î∞îÍøî|?òÏ†ï|Î≥ÄÍ≤???†ú|ÏßÄ??Ï∞æÏïÑ|Í≤Ä???åÎ†§|?¥Îèô)',
    ).hasMatch(normalized);
  }

  bool _hasScheduleCue(String text) {
    final normalized = _normalizeText(text, '');
    return _parseDateTimeHint(normalized) != null ||
        RegExp(r'(?§Îäò|?¥Ïùº|Î™®Î†à|Í∏Ä???¥Î≤àÏ£??§ÏùåÏ£?Îß§Ï£º|Í≤©Ï£º|Îß§Ïõî|Îß§ÎÖÑ)').hasMatch(normalized);
  }

  String _deriveLocalTitle(String text) {
    var title = _normalizeText(_stripExplicitMemoClause(text), '');
    title = title
        .replaceAll(
          RegExp(
            r'(Ï∂îÍ?|?±Î°ù|Í∏∞Î°ù|Î©îÎ™®|?àÏïΩ|ÎßåÎì§???¥Ï§ò|?¥Ï£º?∏Ïöî|Î∞îÍøî|?òÏ†ï|Î≥ÄÍ≤???†ú|ÏßÄ??Ï∞æÏïÑ|Í≤Ä???åÎ†§|?¥Îèô)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'(?:Î©îÎ™®???§Î™Ö???∏Ìä∏Î°?\s*[:Ôº??\s*.+$'),
          ' ',
        )
        .replaceAll(RegExp(r'(?†ÌÉù|?¥Í±∏Î°??¥Í±∞|Í∑∏Í±∏Î°?Í≥®Îùº|Ï≤´Î≤àÏß??êÎ≤àÏß??ãÏß∏)'), ' ')
        .replaceAll(
          RegExp(
            r'(?:(?:\d{4})??s*)?(?:\d{1,2}|[Í∞Ä-??{1,8})??s*(?:\d{1,2}|[Í∞Ä-??{1,8})??,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
              r'(?:(?§Ï†Ñ|?§ÌõÑ|?ÑÏπ®|???êÏã¨|?Ä??Î∞??àÎ≤Ω)\s*)?[Í∞Ä-??-9]{1,8}\s*???:\s*[Í∞Ä-??-9]{1,8}\s*Î∂?|\s*Î∞??'),
          ' ',
        )
        .replaceAll(RegExp(r'\d{1,3}\s*(Î∂??úÍ∞Ñ)\s*(?????àÎã§Í∞Ä|?¥Îî∞)'), ' ')
        .replaceAll(RegExp(r'(?§Îäò|?¥Ïùº|Î™®Î†à|Í∏Ä???¥Î≤àÏ£??§ÏùåÏ£?Îß§Ï£º|Í≤©Ï£º|Îß§Ïõî|Îß§ÎÖÑ)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    title = _stripLeadingLocationPhrase(title);
    return title.isEmpty
        ? _normalizeText(_stripExplicitMemoClause(text), '')
        : title;
  }

  String? _extractExplicitMemo(String rawText) {
    final source = _normalizeText(rawText, '');
    final match = RegExp(
      r'(?:Î©îÎ™®???§Î™Ö???∏Ìä∏Î°?\s*[:Ôº??\s*(.+)$',
    ).firstMatch(source);
    if (match == null) {
      return null;
    }

    final memo = match.group(1)?.trim();
    if (memo == null || memo.isEmpty) {
      return null;
    }

    final cleaned = _normalizeText(memo, '');
    final stripped = _stripExplicitMemoClause(cleaned);
    final normalized = _normalizeSpacingForSchedule(
      _stripScheduleNoise(stripped),
    );
    if (normalized.isEmpty || _looksLikeOnlyScheduleMetadata(normalized)) {
      return null;
    }

    return normalized;
  }

  String _stripExplicitMemoClause(String text) {
    return text
        .replaceFirst(
          RegExp(r'\s*(?:Î©îÎ™®???§Î™Ö???∏Ìä∏Î°?\s*[:Ôº??\s*.+$'),
          ' ',
        )
        .trim();
  }

  String? _extractContentClause(String rawText) {
    final source = _normalizeText(rawText, '');
    final match = RegExp(
      r'(?:?¥Ïö©?Ä|?¥Ïö©\s*[:Ôº?|??s*?ºÏ?|?ºÏ†ï\s*?¥Ïö©?Ä)\s*(.+)$',
    ).firstMatch(source);
    final content = match?.group(1)?.trim();
    if (content == null || content.isEmpty) {
      return null;
    }
    return content.replaceFirst(RegExp(r'^[.??\s]+'), '').trim();
  }

  String _stripScheduleNoise(String text) {
    var cleaned = text.replaceAll(RegExp(r'[\(\)\[\]{}]'), ' ');
    final patterns = <RegExp>[
      RegExp(r'(?:(?:\d{4})\s*??s*)?\d{1,2}\s*??s*\d{1,2}\s*??),
      RegExp(r'(?:ÏßÄÍ∏àÏúºÎ°úÎ???s*)?\d{1,2}\s*(?:Í∞úÏõî|????\s*(?:????'),
      RegExp(r'(?:?§Îäò|?¥Ïùº|Î™®Î†à|Í∏Ä??'),
      RegExp(r'(?:?§Ï†Ñ|?§ÌõÑ|?ÑÏπ®|?êÏã¨|?Ä??Î∞??àÎ≤Ω)'),
      RegExp(r'\d{1,2}\s*???:\s*(?:\d{1,2}\s*Î∂?|Î∞?)?'),
      RegExp(r'\d{1,3}\s*(?:Î∂??úÍ∞Ñ)\s*(?:?????àÎã§Í∞Ä|?¥Îî∞)'),
      RegExp(r'\d{1,2}\s*(?:??Ï£?Í∞úÏõî|??????\s*ÎßàÎã§'),
      RegExp(r'(?:Îß§Ï£º|Îß§Ïõî|Îß§ÎÖÑ|Í≤©Ï£º|Îß§Ïùº)'),
      RegExp(r'(?:Î∞òÎ≥µ|?åÎ¶º|Î¶¨Îßà?∏Îçî|?åÎûå|reminder)'),
      RegExp(r'(?:Î∂Ä??ÍπåÏ?|?ôÏïà|?ïÍ∞Å|?ïÎèÑ|ÏØ?Í≤??àÏ†ï|?àÏïΩ)'),
      RegExp(r'(?:?¥Îëê?úÎ∞ò|?¥Ìïú?úÎ∞ò|?¥ÏãúÎ∞??úÏãúÎ∞??êÏãúÎ∞??∏ÏãúÎ∞??§ÏãúÎ∞?'),
    ];
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, ' ');
    }
    cleaned = cleaned
        .replaceAll(RegExp(r'^\s*(?:??Î°??ºÎ°ú)\s+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _normalizeSpacingForSchedule(cleaned);
  }

  void _preserveDeliveryContent(
    Map<String, dynamic> scheduleFields,
    String contentText,
  ) {
    final split = _splitLeadingMedicalLocation(contentText);
    if (split == null ||
        !RegExp(r'(Í∞ñÎã§\s*Ï£?Í∞Ä?∏Îã§\s*Ï£??ÑÎã¨|Î∞∞ÏÜ°|?©Ìíà)').hasMatch(split.remainder)) {
      return;
    }

    final firstRemainderToken = split.remainder.split(RegExp(r'\s+')).first;
    final currentLocation = scheduleFields['location']?.toString().trim();
    if (currentLocation == null ||
        currentLocation.isEmpty ||
        currentLocation.contains(firstRemainderToken)) {
      scheduleFields['location'] = _normalizeSpacingForSchedule(split.location);
      scheduleFields['location_lat'] = null;
      scheduleFields['location_lng'] = null;
    }

    final currentTitle = scheduleFields['title']?.toString().trim() ?? '';
    if (currentTitle.isEmpty || !currentTitle.contains(firstRemainderToken)) {
      scheduleFields['title'] = _normalizeSpacingForSchedule(split.remainder);
    }

    final supplies = _normalizeStringList(scheduleFields['supplies']);
    if (supplies.isEmpty) {
      final supplyMatch = RegExp(
        r'(?:^|\s)([Í∞Ä-?£A-Za-z0-9]+)\s*(?:Í∞ñÎã§\s*Ï£?Í∞Ä?∏Îã§\s*Ï£??ÑÎã¨|Î∞∞ÏÜ°|?©Ìíà)',
      ).firstMatch(split.remainder);
      final supply = supplyMatch?.group(1)?.trim();
      if (supply != null &&
          supply.isNotEmpty &&
          supply != firstRemainderToken) {
        scheduleFields['supplies'] = <String>[supply];
      }
    }
  }

  _LocationContentSplit? _splitLeadingMedicalLocation(String text) {
    final normalized = _normalizeText(text, '');
    final match = RegExp(
      r'^(.+?(?:?ïÌòï?∏Í≥º|?¥ÎπÑ?∏ÌõÑÍ≥??ºÎ?Í≥??±Ìòï?∏Í≥º|?†Í≤Ω?∏Í≥º|?¥Í≥º|?∏Í≥º|?àÍ≥º|ÏπòÍ≥º|?úÏùò???òÏõê|Î≥ëÏõê|?¥Î¶¨???ΩÍµ≠))\s+(.+)$',
    ).firstMatch(normalized);
    final location = match?.group(1)?.trim();
    final remainder = match?.group(2)?.trim();
    if (location == null ||
        location.isEmpty ||
        remainder == null ||
        remainder.isEmpty) {
      return null;
    }
    return _LocationContentSplit(location: location, remainder: remainder);
  }

  bool _looksLikeOnlyScheduleMetadata(String text) {
    return RegExp(
      r'^(?:?§Îäò|?¥Ïùº|Î™®Î†à|Í∏Ä???§Ï†Ñ|?§ÌõÑ|?ÑÏπ®|?êÏã¨|?Ä??Î∞??àÎ≤Ω|Îß§Ï£º|Îß§Ïõî|Îß§ÎÖÑ|Í≤©Ï£º|Î∞òÎ≥µ|?åÎ¶º|Î¶¨Îßà?∏Îçî|?åÎûå|\d{1,2}\s*??\d{1,3}\s*(?:Î∂??úÍ∞Ñ)\s*(?:?????àÎã§Í∞Ä|?¥Îî∞))*$',
    ).hasMatch(text.replaceAll(RegExp(r'\s+'), ''));
  }

  String _normalizeSpacingForSchedule(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return compact;
    }

    final spaced = compact.replaceAllMapped(
      RegExp(
        r'([Í∞Ä-?£A-Za-z0-9¬∑.]{2,}?)(Ï∂úÎ∞ú|?ÑÏ∞©|ÎØ∏ÌåÖ|?åÏùò|Î∞©Î¨∏|ÏßÑÎ£å|Í≤ÄÏß??ΩÏÜç|Î™®ÏûÑ|?ùÏÇ¨|?òÏóÖ|Í∞ïÏùò|?¥Îèô|?¨Ìñâ|Î≥ëÎ¨∏???ÅÎã¥|Ï∂úÍ∑º|?¥Í∑º|Î∞úÌëú|Î©¥Ï†ë|?àÏïΩ)$',
      ),
      (match) {
        final head = match.group(1);
        final tail = match.group(2);
        if (head == null || tail == null) {
          return match.group(0) ?? '';
        }
        return '$head $tail';
      },
    );
    return spaced.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _extractLeadingLocation(String text) {
    final match = RegExp(
      r'^([Í∞Ä-?£A-Za-z0-9¬∑.]{2,})\s*(?:?êÏÑú|??Î°??ºÎ°ú)\s+(.+)$',
    ).firstMatch(text.trim());
    if (match == null) {
      return null;
    }

    final location = match.group(1)?.trim();
    final remainder = match.group(2)?.trim();
    if (location == null ||
        location.isEmpty ||
        remainder == null ||
        remainder.isEmpty) {
      return null;
    }

    return location;
  }

  String _stripLeadingLocationPhrase(String text) {
    final match = RegExp(
      r'^[Í∞Ä-?£A-Za-z0-9¬∑.]{2,}\s*(?:?êÏÑú|??Î°??ºÎ°ú)\s+(.+)$',
    ).firstMatch(text.trim());
    if (match == null) {
      return text.trim();
    }

    final remainder = match.group(1)?.trim();
    if (remainder == null || remainder.isEmpty) {
      return text.trim();
    }

    return remainder;
  }

  String? _inferLocalRecurrence(String text) {
    final normalized = _normalizeText(text, '');
    final weekday = _weekdayRRuleToken(normalized);

    if (normalized.contains('Í≤©Ï£º')) {
      return 'FREQ=WEEKLY;INTERVAL=2${weekday == null ? '' : ';BYDAY=$weekday'}';
    }
    if (normalized.contains('Îß§Ï£º')) {
      return 'FREQ=WEEKLY${weekday == null ? '' : ';BYDAY=$weekday'}';
    }

    final monthlyOrdinal = RegExp(
      r'Îß§Ïõî\s*(Ï≤?s*Î≤àÏß∏|Ï≤´Ïß∏|??s*Î≤àÏß∏|?òÏß∏|??s*Î≤àÏß∏|?ãÏß∏|??s*Î≤àÏß∏|?∑Ïß∏|ÎßàÏ?Îß?\s*([?îÌôî?òÎ™©Í∏àÌÜ†??)?îÏùº',
    ).firstMatch(normalized);
    if (monthlyOrdinal != null) {
      final ordinal = switch (monthlyOrdinal.group(1)?.replaceAll(' ', '')) {
        'Ï≤´Î≤àÏß? || 'Ï≤´Ïß∏' => '1',
        '?êÎ≤àÏß? || '?òÏß∏' => '2',
        '?∏Î≤àÏß? || '?ãÏß∏' => '3',
        '?§Î≤àÏß? || '?∑Ïß∏' => '4',
        'ÎßàÏ?Îß? => '-1',
        _ => '1',
      };
      final day = _weekdayShortToken(monthlyOrdinal.group(2));
      if (day != null) {
        return 'FREQ=MONTHLY;BYDAY=$ordinal$day';
      }
    }

    final monthlyDay = RegExp(r'Îß§Ïõî\s*(\d{1,2})??).firstMatch(normalized);
    if (monthlyDay != null) {
      return 'FREQ=MONTHLY;BYMONTHDAY=${monthlyDay.group(1)}';
    }

    if (normalized.contains('Îß§Ïõî')) {
      return 'FREQ=MONTHLY';
    }

    final yearly =
        RegExp(r'Îß§ÎÖÑ\s*(\d{1,2})??s*(\d{1,2})??).firstMatch(normalized);
    if (yearly != null) {
      return 'FREQ=YEARLY;BYMONTH=${yearly.group(1)};BYMONTHDAY=${yearly.group(2)}';
    }

    if (normalized.contains('Îß§ÎÖÑ')) {
      return 'FREQ=YEARLY';
    }

    final custom =
        RegExp(r'(\d{1,2})\s*(??Ï£?Í∞úÏõî|??????\s*ÎßàÎã§').firstMatch(normalized);
    if (custom != null) {
      final interval = custom.group(1);
      final unit = custom.group(2);
      final freq = switch (unit) {
        '?? => 'DAILY',
        'Ï£? => 'WEEKLY',
        'Í∞úÏõî' || '?? || '?? => 'MONTHLY',
        '?? => 'YEARLY',
        _ => null,
      };
      if (freq != null && interval != null) {
        return 'FREQ=$freq;INTERVAL=$interval';
      }
    }

    return null;
  }

  String? _weekdayRRuleToken(String text) {
    final match = RegExp(r'([?îÌôî?òÎ™©Í∏àÌÜ†??)?îÏùº').firstMatch(text);
    if (match == null) {
      return null;
    }

    return _weekdayShortToken(match.group(1));
  }

  String? _weekdayShortToken(String? weekday) {
    return switch (weekday) {
      '?? => 'MO',
      '?? => 'TU',
      '?? => 'WE',
      'Î™? => 'TH',
      'Í∏? => 'FR',
      '?? => 'SA',
      '?? => 'SU',
      _ => null,
    };
  }

  String _normalizeCategory(String category) {
    return PlanFlowEventCategories.normalize(category);
  }

  String _inferCategoryFromRawText(String rawText) {
    final text = _normalizeText(rawText, '');
    if (RegExp(r'(Î≥ëÏõê|?òÏõê|ÏπòÍ≥º|?úÏùò??Í≤ÄÏß?Í±¥Í∞ïÍ≤ÄÏß??¥Îèô|?¨Ïä§|?úÏà†|ÏßÑÎ£å|ÏπòÎ£å|Ï≤òÎ∞©|?¥ÏãúÍ≤???s*Î∞?')
        .hasMatch(text)) {
      return PlanFlowEventCategories.health;
    }
    if (RegExp(r'(Í∞ïÏùò|?∏Î????åÌÅ¨???åÌÅ¨??ÍµêÏú°|?∞Ïàò|?òÏóÖ|Í∞ïÏ¢å|?ôÏõê|?ôÍµê|?úÌóò|?§ÌÑ∞??').hasMatch(text)) {
      return PlanFlowEventCategories.education;
    }
    if (RegExp(r'(ÎØ∏ÌåÖ|?åÏùò|Î≥¥Í≥†|Ï∂úÏû•|Í±∞ÎûòÏ≤??ÅÏóÖ|?ÖÎ¨¥|Î©¥Ï†ë|Î∞úÌëú|?úÏïà|Ïª®Ìçº?∞Ïä§)').hasMatch(text)) {
      return PlanFlowEventCategories.work;
    }
    if (RegExp(r'(?ΩÏÜç|Ï∑®Î?|?¨Í?|ÏπúÍµ¨|Í∞ÄÏ°?s*Î™®ÏûÑ|Î™®ÏûÑ|?∞Ïù¥???¨Ìñâ|?¥Í?|?ùÏÇ¨)').hasMatch(text)) {
      return PlanFlowEventCategories.personal;
    }
    return PlanFlowEventCategories.etc;
  }

  List<Map<String, dynamic>> _normalizePreActions(Object? preActions) {
    if (preActions is! List) {
      return <Map<String, dynamic>>[];
    }

    return preActions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['title'] != null && item['offset_hours'] != null)
        .toList(growable: false);
  }

  List<String> _normalizeStringList(Object? value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    return <String>[];
  }

  DateTime? _normalizeDateTime(Object? value) {
    return _parseDateTime(value);
  }

  DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  double? _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  double _clampConfidence(double value, double fallback) {
    if (value.isNaN || value.isInfinite) {
      return fallback;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  String _normalizeText(String? value, String? fallback) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return fallback?.trim() ?? '';
    }
    return VoiceTextCleanupService.normalizeBasic(text);
  }

  bool hasMeaningfulChange(String previousText, String currentText) {
    final previous = VoiceTextCleanupService.normalizeBasic(previousText);
    final current = VoiceTextCleanupService.normalizeBasic(currentText);
    if (previous == current) {
      return false;
    }
    final previousSignature =
        VoiceTextCleanupService.normalizeForSearch(previous);
    final currentSignature =
        VoiceTextCleanupService.normalizeForSearch(current);
    return previousSignature != currentSignature;
  }

  static String analysisSignatureFor(
    String text, {
    VoiceTextCleanupContext context = VoiceTextCleanupContext.add,
    Iterable<VoiceTextCleanupCandidate> candidates = const [],
  }) {
    final normalizedText = VoiceTextCleanupService.normalizeForSearch(text);
    final candidateSignature = candidates.take(12).map((candidate) {
      final location = candidate.location?.trim() ?? '';
      final startAt = candidate.startAt?.toIso8601String() ?? '';
      return [
        VoiceTextCleanupService.normalizeForSearch(candidate.title),
        VoiceTextCleanupService.normalizeForSearch(location),
        startAt,
      ].join('|');
    }).join('||');
    final source = [
      context.name,
      normalizedText,
      candidateSignature,
    ].join('::');
    return _fnv1aHashHex(source);
  }

  static String _fnv1aHashHex(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
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
        headers: <String, String>{
          'Authorization': 'Bearer ${AppEnv.supabaseAnonKey}',
          'apikey': AppEnv.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'model': RemoteConfigService.gptModel,
          'messages': <Map<String, String>>[
            <String, String>{
              'role': 'system',
              'content': systemPrompt,
            },
            <String, String>{
              'role': 'user',
              'content': userPrompt,
            },
          ],
          if (responseFormat != null) 'response_format': responseFormat,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decodedText = utf8.decode(response.bodyBytes);
      final decoded = jsonDecode(decodedText);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        return null;
      }

      final firstChoice = choices.first;
      if (firstChoice is! Map<String, dynamic>) {
        return null;
      }

      final message = firstChoice['message'];
      if (message is! Map<String, dynamic>) {
        return null;
      }

      final content = message['content'];
      if (content is! String) {
        return null;
      }

      return content;
    } catch (_) {
      return null;
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Map<String, dynamic>? _decodeJsonMap(String? content) {
    if (content == null) {
      return null;
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return null;
  }

  DateTime? _parseDateTimeHint(String text) {
    final gpt = GptService(now: _now);
    return gpt.inferStartAtFromRawText(text);
  }
}

class _LocationContentSplit {
  const _LocationContentSplit({
    required this.location,
    required this.remainder,
  });

  final String location;
  final String remainder;
}

const String _voiceCommandAnalysisPrompt = '''
You are a Korean voice command pre-analyzer for schedule input.
Return only a valid JSON object.

Required keys:
- normalized_text: string
- intent: one of "add", "edit", "delete", "query", "choose"
- confidence: number from 0.0 to 1.0
- uncertain_fields: array of strings
- schedule_fields: object or null
- target_event_hint: object or null
- requested_changes: array of strings

Rules:
- normalized_text must keep the user's meaning after cleanup and command interpretation.
- Do not invent audio or data that was not spoken.
- For add intent, fill schedule_fields with parseSchedule-compatible keys:
  title, date, start_at, end_at, location, location_lat, location_lng,
  travel_origin_lat, travel_origin_lng, travel_mode, memo, supplies,
  is_critical, recurrence_rule, is_all_day, is_multi_day, category, pre_actions.
- For edit, delete, and query intents, use target_event_hint and
  requested_changes to identify what should be acted on.
- Use choose when the text is too ambiguous to decide between adding a schedule
  and querying schedules, such as a bare "Ï°∞Ìöå" command.
- Keep uncertain_fields focused on what still needs confirmation.
''';

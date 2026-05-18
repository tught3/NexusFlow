import 'voice_text_cleanup_service.dart';

enum VoiceCommandPipelineIntent {
  add,
  edit,
  delete,
  query,
  choose,
}

class VoiceCommandPlan {
  const VoiceCommandPlan({
    required this.rawText,
    required this.cleanedText,
    required this.normalizedText,
    required this.intent,
    required this.targetText,
    required this.changeText,
    required this.targetQuery,
    required this.requestedChanges,
    required this.requestedFieldValues,
    required this.confidence,
    required this.requiresUserChoice,
    required this.safeDirectApply,
  });

  final String rawText;
  final String cleanedText;
  final String normalizedText;
  final VoiceCommandPipelineIntent intent;
  final String targetText;
  final String changeText;
  final String targetQuery;
  final List<String> requestedChanges;
  final Map<String, String> requestedFieldValues;
  final double confidence;
  final bool requiresUserChoice;
  final bool safeDirectApply;
}

class VoiceCommandPipeline {
  const VoiceCommandPipeline();

  VoiceCommandPlan analyze(
    String rawText, {
    VoiceCommandPipelineIntent? intent,
    VoiceTextCleanupContext context = VoiceTextCleanupContext.add,
    Iterable<VoiceTextCleanupCandidate> candidates = const [],
  }) {
    final cleanup = VoiceTextCleanupService.cleanLocally(
      rawText,
      context: context,
      candidates: candidates,
    );
    final cleanedText = cleanup.cleanedText;
    final normalizedText = normalizeManagementText(cleanedText);
    final resolvedIntent =
        intent ?? resolveIntent(cleanedText, context: context);
    final requestedChanges = extractRequestedChanges(cleanedText);
    final split = splitCommand(
      normalizedText,
      intent: resolvedIntent,
      requestedChanges: requestedChanges,
    );
    final fieldValues = extractRequestedFieldValues(
      split,
      requestedChanges: requestedChanges,
    );
    final targetQuery = buildTargetQuery(
      split.targetText,
      fallbackText: normalizedText,
      intent: resolvedIntent,
    );
    final requiresUserChoice =
        resolvedIntent == VoiceCommandPipelineIntent.choose ||
            resolvedIntent == VoiceCommandPipelineIntent.delete;
    final safeDirectApply = resolvedIntent == VoiceCommandPipelineIntent.edit &&
        !requiresUserChoice &&
        requestedChanges.isNotEmpty &&
        !requestedChanges.contains('location') &&
        !requestedChanges.contains('title') &&
        !requestedChanges.contains('memo');

    return VoiceCommandPlan(
      rawText: cleanup.originalText,
      cleanedText: cleanedText,
      normalizedText: normalizedText,
      intent: resolvedIntent,
      targetText: split.targetText,
      changeText: split.changeText,
      targetQuery: targetQuery,
      requestedChanges: List<String>.unmodifiable(requestedChanges),
      requestedFieldValues: Map<String, String>.unmodifiable(fieldValues),
      confidence: _confidenceFor(
        intent: resolvedIntent,
        split: split,
        requestedChanges: requestedChanges,
      ),
      requiresUserChoice: requiresUserChoice,
      safeDirectApply: safeDirectApply,
    );
  }

  VoiceCommandPipelineIntent resolveIntent(
    String text, {
    VoiceTextCleanupContext context = VoiceTextCleanupContext.add,
  }) {
    final normalized = normalizeManagementText(text);
    if (RegExp(r'(?? œ|ì§€???†ì• |ì·¨ì†Œ|?œê±°)').hasMatch(normalized)) {
      return VoiceCommandPipelineIntent.delete;
    }
    if (RegExp(r'(?˜ì •|ë³€ê²?ë°”ê¿”|ë¯¸ë¤„|?ë‹¹ê²???²¨|?´ë™|ê³ ì³|?¸ì§‘|?°ê¸°|??¶°|?¹ê²¨)')
        .hasMatch(normalized)) {
      return VoiceCommandPipelineIntent.edit;
    }
    if (isAmbiguousFieldAddition(normalized)) {
      return VoiceCommandPipelineIntent.choose;
    }
    if (_hasAddIntentCue(normalized)) {
      return VoiceCommandPipelineIntent.add;
    }
    if (_hasAmbiguousQueryIntentCue(normalized)) {
      return VoiceCommandPipelineIntent.choose;
    }
    if (_hasQueryIntentCue(normalized)) {
      return VoiceCommandPipelineIntent.query;
    }
    return switch (context) {
      VoiceTextCleanupContext.delete => VoiceCommandPipelineIntent.delete,
      VoiceTextCleanupContext.edit => VoiceCommandPipelineIntent.edit,
      VoiceTextCleanupContext.query => VoiceCommandPipelineIntent.query,
      VoiceTextCleanupContext.add => VoiceCommandPipelineIntent.add,
    };
  }

  VoiceCommandSplit splitCommand(
    String normalizedText, {
    required VoiceCommandPipelineIntent intent,
    required List<String> requestedChanges,
  }) {
    if (intent == VoiceCommandPipelineIntent.delete) {
      final target = normalizedText
          .replaceAll(
            RegExp(
              r'(?:?¼ì •|?¤ì?ì¤??½ì†)?\s*(?:?? œ|ì§€???†ì• |ì·¨ì†Œ|?œê±°)(?:?´ì£¼?¸ìš”|??s*ì¤??´ì¤˜|?œì¼œ\s*ì¤??œì¼œì¤????',
            ),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return VoiceCommandSplit(
        targetText: target,
        changeText: '',
      );
    }

    if (intent == VoiceCommandPipelineIntent.edit) {
      if (requestedChanges.contains('location')) {
        final split = _splitLocationChange(normalizedText);
        if (split != null) {
          return split;
        }
      }
      if (requestedChanges.contains('start_at')) {
        final split = _splitDateTimeChange(normalizedText);
        if (split != null) {
          return split;
        }
      }
    }

    return VoiceCommandSplit(targetText: normalizedText, changeText: '');
  }

  String buildTargetQuery(
    String targetText, {
    required String fallbackText,
    required VoiceCommandPipelineIntent intent,
  }) {
    final normalized = targetText.trim().isEmpty ? fallbackText : targetText;
    if (targetText.trim().isEmpty &&
        intent == VoiceCommandPipelineIntent.delete) {
      return '';
    }
    final tokens = searchTokens(normalized);
    if (tokens.isNotEmpty) {
      return tokens.join(' ');
    }
    return normalized;
  }

  List<String> extractRequestedChanges(String text) {
    final normalized = normalizeManagementText(text);
    final changes = <String>{};
    if (RegExp(
      r'(?œê°„|?œê°|?¸ì œ|ëª?s*???¤ì „|?¤í›„|?„ì¹¨|?ì‹¬|?€??ë°??¤ëŠ˜|?´ì¼|ëª¨ë ˆ|ê¸€???´ë²ˆ\s*ì£??¤ìŒ\s*ì£??´ë²ˆì£??¤ìŒì£?[?”í™”?˜ëª©ê¸ˆí† ???”ì¼|?°ê¸°|ë¯¸ë¤„|??²¨|?´ë™|?ë‹¹ê²???¶°|?¹ê²¨|ë°”ê¿”|ë³€ê²??˜ì •)',
    ).hasMatch(normalized)) {
      changes.add('start_at');
    }
    if (RegExp(r'(?¥ì†Œ|?„ì¹˜|?´ë””|ì£¼ì†Œ|ê°€??s*ê¸??¤ì‹œ??s*ê¸?').hasMatch(normalized)) {
      changes.add('location');
    }
    if (RegExp(r'(?œëª©|?´ë¦„|ëª…ì¹­|ë¬´ìŠ¨\s*???´ìš©|?ìŠ¤??').hasMatch(normalized)) {
      changes.add('title');
    }
    if (RegExp(r'(ë©”ëª¨|?¤ëª…|?¸íŠ¸|ë¹„ê³ )').hasMatch(normalized)) {
      changes.add('memo');
    }
    if (RegExp(r'(ë°˜ë³µ|ë§¤ì£¼|ë§¤ì›”|ë§¤ë…„|ê²©ì£¼)').hasMatch(normalized)) {
      changes.add('recurrence_rule');
    }
    if (RegExp(r'(?˜ë£¨\s*ì¢…ì¼|?˜ë£¨ì¢…ì¼|ì¢…ì¼|?¨ì¢…??').hasMatch(normalized)) {
      changes.add('is_all_day');
    }
    return changes.toList(growable: false);
  }

  Map<String, String> extractRequestedFieldValues(
    VoiceCommandSplit split, {
    required List<String> requestedChanges,
  }) {
    final values = <String, String>{};
    if (requestedChanges.contains('location')) {
      final location = _extractRequestedLocation(split.changeText);
      if (location != null) {
        values['location'] = location;
      }
    }
    return values;
  }

  List<String> searchTokens(String text) {
    final normalized = normalizeManagementText(text);
    if (normalized.isEmpty) {
      return <String>[];
    }

    final seen = <String>{};
    final baseTokens = normalized
        .replaceAll(RegExp(r'[^0-9a-zê°€-??s]'), ' ')
        .split(RegExp(r'\s+'))
        .expand(tokenVariants)
        .map(stripKoreanParticles)
        .where(
          (token) =>
              token.length >= 2 &&
              !stopWords.contains(token) &&
              seen.add(token),
        )
        .toList(growable: false);

    if (baseTokens.isNotEmpty) {
      return baseTokens;
    }

    return normalized
        .split(RegExp(r'\s+'))
        .map(stripKoreanParticles)
        .where((token) => token.length >= 2)
        .toList(growable: false);
  }

  bool isAmbiguousFieldAddition(String text) {
    final normalized = normalizeManagementText(text);
    if (!RegExp(
      r'(?¥ì†Œ|?„ì¹˜|ì£¼ì†Œ)\s*(?:ë¥????¼ë¡œ|ë¡??\s*(?:ì¶”ê?|?£ì–´|?…ë ¥|?¤ì •|?±ë¡)',
    ).hasMatch(normalized)) {
      return false;
    }
    return _hasScheduleCue(normalized) ||
        RegExp(r'(?¼ì •|?¤ì?ì¤??½ì†|?Œì˜|?œí—˜|ë°©ë¬¸|ë¯¸íŒ…)').hasMatch(normalized);
  }

  String normalizeManagementText(String text) {
    return VoiceTextCleanupService.normalizeBasic(text).toLowerCase();
  }

  List<String> analysisTokens(String text) {
    final normalized = normalizeManagementText(text);
    if (normalized.isEmpty) {
      return <String>[];
    }
    return normalized
        .replaceAll(RegExp(r'[^0-9a-zê°€-??s]'), ' ')
        .split(RegExp(r'\s+'))
        .map(stripKoreanParticles)
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  List<String> tokenVariants(String rawToken) {
    final token = stripKoreanParticles(rawToken.trim());
    if (token.isEmpty) {
      return const <String>[];
    }
    final variants = <String>{token};
    final withoutSchedule = token.replaceAll(RegExp(r'(?¼ì •|?¤ì?ì¤?$'), '');
    if (withoutSchedule.length >= 2) {
      variants.add(withoutSchedule);
    }
    if (token.endsWith('?„ë‹¬?¼ì •')) {
      variants.add(token.replaceFirst(RegExp(r'?¼ì •$'), ''));
    }
    final withoutQuoteEnding =
        token.replaceAll(RegExp(r'(?´ë¼ê³??¼ê³ |?´ë¼???¼ëŠ”)$'), '');
    if (withoutQuoteEnding.length >= 2) {
      variants.add(withoutQuoteEnding);
    }
    return variants.toList(growable: false);
  }

  String stripKoreanParticles(String token) {
    var value = token.toLowerCase().trim();
    for (final suffix in const <String>[
      '?¼ë¡œ??,
      '?¼ë¡œ??,
      '?ì„œ',
      '?ê²Œ',
      'ê»?,
      'ê¹Œì?',
      'ë¶€??,
      'ì²˜ëŸ¼',
      'ë³´ë‹¤',
      'ë§?,
      '??,
      '?€',
      '??,
      '??,
      'ê°€',
      '??,
      'ë¥?,
      '?€',
      'ê³?,
      '??,
      'ë¡?,
      '??,
      '?¼ê³ ',
      '?´ë¼ê³?,
    ]) {
      if (value.length > suffix.length && value.endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length);
        break;
      }
    }
    return value;
  }

  VoiceCommandSplit? _splitLocationChange(String normalizedText) {
    final operation = RegExp(
      r'(?:?¥ì†Œ|?„ì¹˜|ì£¼ì†Œ)\s*(?:ë¥????¼ë¡œ|ë¡??\s*(?:ì¶”ê?|?£ì–´|?…ë ¥|?¤ì •|?±ë¡|ë³€ê²?ë°”ê¿”|?˜ì •).*?$',
    ).firstMatch(normalizedText);
    if (operation == null) {
      return null;
    }

    final beforeOperation = normalizedText.substring(0, operation.start).trim();
    final operationText = normalizedText.substring(operation.start).trim();
    var targetText = beforeOperation;
    var changePrefix = beforeOperation;

    final boundaries =
        RegExp(r'(?:?¼ì •|?¤ì?ì¤??½ì†)??s+').allMatches(beforeOperation).toList();
    if (boundaries.isNotEmpty) {
      final boundary = boundaries.last;
      targetText = beforeOperation.substring(0, boundary.start + 2).trim();
      changePrefix = beforeOperation.substring(boundary.end).trim();
    }

    final changeText = [changePrefix, operationText]
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (targetText.isEmpty || changeText.isEmpty) {
      return null;
    }
    return VoiceCommandSplit(targetText: targetText, changeText: changeText);
  }

  VoiceCommandSplit? _splitDateTimeChange(String normalizedText) {
    final verbMatches = RegExp(
      r'(?:ë¡??¼ë¡œ)?\s*(?:ë³€ê²?ë°”ê¿”|?˜ì •|??²¨|?´ë™|ë¯¸ë¤„|?°ê¸°|?ë‹¹ê²???¶°|?¹ê²¨).*?$',
    ).allMatches(normalizedText).toList(growable: false);
    if (verbMatches.isEmpty) {
      return null;
    }
    final verb = verbMatches.last;
    final beforeVerb = normalizedText.substring(0, verb.start).trim();
    final valueMatch = _lastDateTimeValueMatch(beforeVerb);
    if (valueMatch == null) {
      return null;
    }
    final targetText = beforeVerb.substring(0, valueMatch.start).trim();
    final changeText = normalizedText.substring(valueMatch.start).trim();
    if (targetText.isEmpty || changeText.isEmpty) {
      return null;
    }
    return VoiceCommandSplit(targetText: targetText, changeText: changeText);
  }

  RegExpMatch? _lastDateTimeValueMatch(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'((?:?´ë²ˆ|?¤ìŒ)\s*ì£?s*)?[?”í™”?˜ëª©ê¸ˆí† ???”ì¼(?:\s*(?:?¤ì „|?¤í›„|?„ì¹¨|???ì‹¬|?€??ë°??ˆë²½)?\s*(?:[0-9]{1,2}|[ê°€-??{1,8})\s*???:\s*(?:[0-9]{1,2}|[ê°€-??{1,8})\s*ë¶?|\s*ë°??)?',
      ),
      RegExp(
        r'(?¤ëŠ˜|?´ì¼|ëª¨ë ˆ|ê¸€??(?:\s*(?:?¤ì „|?¤í›„|?„ì¹¨|???ì‹¬|?€??ë°??ˆë²½)?\s*(?:[0-9]{1,2}|[ê°€-??{1,8})\s*???:\s*(?:[0-9]{1,2}|[ê°€-??{1,8})\s*ë¶?|\s*ë°??)?',
      ),
      RegExp(
        r'(?:\d{4}\s*??s*)?\d{1,2}\s*??s*\d{1,2}\s*???:\s*(?:?¤ì „|?¤í›„|?„ì¹¨|???ì‹¬|?€??ë°??ˆë²½)?\s*(?:[0-9]{1,2}|[ê°€-??{1,8})\s*???:\s*(?:[0-9]{1,2}|[ê°€-??{1,8})\s*ë¶?|\s*ë°??)?',
      ),
      RegExp(
        r'(?:?¤ì „|?¤í›„|?„ì¹¨|???ì‹¬|?€??ë°??ˆë²½)?\s*(?:[0-9]{1,2}|[ê°€-??{1,8})\s*???:\s*(?:[0-9]{1,2}|[ê°€-??{1,8})\s*ë¶?|\s*ë°??',
      ),
    ];

    RegExpMatch? latest;
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final value = match.group(0)?.trim() ?? '';
        if (value.isEmpty) {
          continue;
        }
        if (latest == null ||
            match.end > latest.end ||
            (match.end == latest.end && match.start < latest.start)) {
          latest = match;
        }
      }
    }
    return latest;
  }

  String? _extractRequestedLocation(String changeText) {
    final text = changeText.trim();
    if (text.isEmpty) {
      return null;
    }
    final match = RegExp(
      r'(?:?¥ì†Œ|?„ì¹˜|ì£¼ì†Œ)\s*(?:ë¥????\s*(.+?)(?:ë¡??¼ë¡œ)\s*(?:ë³€ê²?ë°”ê¿”|?˜ì •)|(.+?)(?:ë¡??¼ë¡œ)?\s*(?:?¥ì†Œ|?„ì¹˜|ì£¼ì†Œ)\s*(?:ì¶”ê?|?£ì–´|?…ë ¥|?¤ì •|?±ë¡)',
    ).firstMatch(text);
    final prefixLocation = match?.group(1)?.trim();
    final suffixLocation = match?.group(2)?.trim();
    final location = prefixLocation == null || prefixLocation.isEmpty
        ? suffixLocation
        : prefixLocation;
    if (location == null || location.isEmpty) {
      return null;
    }
    return location
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^(?:??ë¡??¼ë¡œ)\s+'), '')
        .trim();
  }

  double _confidenceFor({
    required VoiceCommandPipelineIntent intent,
    required VoiceCommandSplit split,
    required List<String> requestedChanges,
  }) {
    var confidence = 0.45;
    if (intent != VoiceCommandPipelineIntent.choose) {
      confidence += 0.15;
    }
    if (split.targetText.trim().isNotEmpty) {
      confidence += 0.15;
    }
    if (split.changeText.trim().isNotEmpty || requestedChanges.isNotEmpty) {
      confidence += 0.15;
    }
    return confidence.clamp(0.05, 0.95).toDouble();
  }

  bool _hasAddIntentCue(String text) {
    final normalized = normalizeManagementText(text);
    return _hasExplicitAddIntentCue(normalized) ||
        _hasRecurringLookupAddCue(normalized) ||
        (_looksLikeScheduleContentToConfirm(normalized) &&
            _hasScheduleCue(normalized));
  }

  bool _hasExplicitAddIntentCue(String text) {
    final normalized = normalizeManagementText(text);
    return RegExp(
      r'(ì¶”ê?|?±ë¡|?€???!?????˜ì–´|??|ê¸°ë¡|?ˆì•½|ë§Œë“¤???¼ì •?¼ë¡œ|?˜ê¸°ë¡?s*?€??ë¡?s*?€??ë©”ëª¨\s*(?:???´ì¤˜|?¨ê²¨|ê¸°ë¡|?€??ì¶”ê?))',
    ).hasMatch(normalized);
  }

  bool _hasRecurringLookupAddCue(String text) {
    final normalized = normalizeManagementText(text);
    return RegExp(
      r'((?:ë§¤ì›”\s*)?(?:?”ë?|?•ê¸°|?Œì‚¬)\s*ì¡°íšŒ)',
    ).hasMatch(normalized);
  }

  bool _hasAmbiguousQueryIntentCue(String text) {
    final normalized = normalizeManagementText(text);
    return RegExp(r'^(?:?¼ì •\s*)?ì¡°íšŒ$').hasMatch(normalized);
  }

  bool _looksLikeScheduleContentToConfirm(String text) {
    final normalized = normalizeManagementText(text);
    if (!normalized.endsWith('?•ì¸?˜ê¸°')) {
      return false;
    }
    if (RegExp(r'^(?¤ëŠ˜|?´ì¼|ëª¨ë ˆ|ê¸€???\s*?¼ì •\s*?•ì¸?˜ê¸°$').hasMatch(normalized)) {
      return false;
    }
    return true;
  }

  bool _hasQueryIntentCue(String text) {
    final normalized = normalizeManagementText(text);
    return RegExp(
      r'(ì°¾ì•„\s*ì¤?ì°¾ì•„\s*ì£¼ì„¸??ê²€???Œë ¤\s*ì¤??Œë ¤\s*ì£¼ì„¸???¸ì œ|?´ë””|ë­ì•¼|ë³´ì—¬\s*ì¤?ë³´ì—¬\s*ì£¼ì„¸???¼ì •\s*?•ì¸|?•ì¸??s*ì¤??•ì¸??s*ì£¼ì„¸??',
    ).hasMatch(normalized);
  }

  bool _hasScheduleCue(String text) {
    final normalized = normalizeManagementText(text);
    return _parseDateTimeHint(normalized) != null ||
        RegExp(r'(?¤ëŠ˜|?´ì¼|ëª¨ë ˆ|ê¸€???´ë²ˆì£??¤ìŒì£??´ë²ˆ\s*ì£??¤ìŒ\s*ì£?').hasMatch(normalized);
  }

  DateTime? _parseDateTimeHint(String text) {
    final dayMatch = RegExp(r'(?¤ëŠ˜|?´ì¼|ëª¨ë ˆ|ê¸€??').firstMatch(text);
    if (dayMatch != null) {
      return DateTime.now();
    }
    if (RegExp(r'(?¤ì „|?¤í›„|?„ì¹¨|???ì‹¬|?€??ë°??ˆë²½)?\s*[0-9ê°€-??{1,8}\s*??)
        .hasMatch(text)) {
      return DateTime.now();
    }
    return null;
  }

  static const Set<String> stopWords = {
    '?¼ì •',
    '?˜ì •',
    '?˜ì •??,
    'ë³€ê²?,
    'ë³€ê²½í•´',
    'ë°”ê¿”',
    'ê³ ì³',
    'ê³ ì¹˜',
    '?? œ',
    '?? œ??,
    'ì¶”ê?',
    '?±ë¡',
    'ë³´ì—¬',
    'ì°¾ì•„',
    'ì¡°íšŒ',
    'ë°”ê¾¸',
    '??²¨',
    '?´ë™',
    '??¸°',
    'ë¯¸ë¤„',
    'ë¯¸ë£¨',
    '?°ê¸°',
    '?ë‹¹ê²?,
    '?¹ê²¨',
    '??¶°',
    '??¶”',
    '? íƒ',
    '?´ê±¸ë¡?,
    '?´ê±°',
    'ê·¸ê±¸ë¡?,
    'ê³¨ë¼',
    'ì²«ë²ˆì§?,
    '?ë²ˆì§?,
    '?‹ì§¸',
    '?œê°„',
    '? ì§œ',
    '?¥ì†Œ',
    '?„ì¹˜',
    '?¤ëŠ˜',
    '?´ì¼',
    'ëª¨ë ˆ',
    'ê¸€??,
    '?´ë²ˆ',
    '?´ë²ˆì£?,
    '?´ë²ˆ ì£?,
    '?¤ìŒì£?,
    '?¤ìŒ ì£?,
    '?”ìš”??,
    '?”ìš”??,
    '?˜ìš”??,
    'ëª©ìš”??,
    'ê¸ˆìš”??,
    '? ìš”??,
    '?¼ìš”??,
    '?¤ì „',
    '?¤í›„',
    '?„ì¹¨',
    '?ì‹¬',
    '?€??,
    'ë°?,
    'ë¬´ì—‡',
    'ë­?,
    '?˜ì–´',
    '?ˆëŠ”',
    '?´ë¼ê³?,
    '?¼ê³ ',
    '?´ë¦„',
    '?œëª©',
    '?•ì¸',
    '?•ì¸??,
    '?•ì¸?˜ê¸°',
    '?•ì¸?˜ê¸°ë¡?,
    '?•ì¸?´ì¤˜',
    '?•ì¸?´ì£¼?¸ìš”',
    '?´ì¤˜',
    'ì£¼ì„¸??,
    '?´ì£¼?¸ìš”',
    'ì¢€',
    '?˜ì',
    '?˜ìê³?,
    '?´ì•¼',
    '? ê¹Œ',
    '?˜ëŠ”',
    '?¬ì´',
  };
}

class VoiceCommandSplit {
  const VoiceCommandSplit({
    required this.targetText,
    required this.changeText,
  });

  final String targetText;
  final String changeText;
}

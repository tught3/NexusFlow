enum VoiceTextCleanupContext {
  add,
  edit,
  delete,
  query,
}

enum VoiceTextCleanupMethod {
  none,
  local,
  ai,
}

class VoiceTextCleanupCandidate {
  const VoiceTextCleanupCandidate({
    required this.title,
    this.location,
    this.startAt,
  });

  final String title;
  final String? location;
  final DateTime? startAt;

  String get searchableText => [title, location ?? '']
      .join(' ')
      .replaceAll(RegExp(r'[^0-9a-zA-ZÍ∞Ä-??s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class VoiceTextCleanupResult {
  const VoiceTextCleanupResult({
    required this.originalText,
    required this.cleanedText,
    required this.changed,
    required this.method,
    required this.reason,
    required this.confidence,
  });

  factory VoiceTextCleanupResult.unchanged(String text) {
    final normalized = VoiceTextCleanupService.normalizeBasic(text);
    return VoiceTextCleanupResult(
      originalText: text,
      cleanedText: normalized,
      changed: normalized != text.trim(),
      method: normalized == text.trim()
          ? VoiceTextCleanupMethod.none
          : VoiceTextCleanupMethod.local,
      reason: normalized == text.trim() ? 'no_cleanup_needed' : 'basic_cleanup',
      confidence: 1,
    );
  }

  final String originalText;
  final String cleanedText;
  final bool changed;
  final VoiceTextCleanupMethod method;
  final String reason;
  final double confidence;
}

class VoiceTextCleanupService {
  const VoiceTextCleanupService._();

  static VoiceTextCleanupResult cleanLocally(
    String rawText, {
    VoiceTextCleanupContext context = VoiceTextCleanupContext.add,
    Iterable<VoiceTextCleanupCandidate> candidates = const [],
  }) {
    final original = rawText.trim();
    var cleaned = normalizeBasic(original);
    var reason = cleaned == original ? 'no_cleanup_needed' : 'basic_cleanup';

    final candidateCleaned = _mergeCandidateSplitParticles(
      cleaned,
      candidates,
    );
    if (candidateCleaned != cleaned) {
      cleaned = candidateCleaned;
      reason = 'candidate_particle_repair';
    }

    return VoiceTextCleanupResult(
      originalText: original,
      cleanedText: cleaned,
      changed: cleaned != original,
      method: cleaned == original
          ? VoiceTextCleanupMethod.none
          : VoiceTextCleanupMethod.local,
      reason: reason,
      confidence: 1,
    );
  }

  static bool shouldAskAi(String text) {
    final normalized = normalizeBasic(text);
    if (normalized.isEmpty) {
      return false;
    }
    if (RegExp(r'([Í∞Ä-??-9a-zA-Z]{2,})\s*(?êÏÑú|??\s+([Í∞Ä-??-9a-zA-Z]{2,})\s*(?êÏÑú|??')
        .hasMatch(normalized)) {
      return true;
    }
    if (RegExp(r'([Í∞Ä-??{2,})\s+\1').hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  static String normalizeBasic(String text) {
    return text
        .replaceAll(RegExp(r'[,\.\!\?\(\)\[\]\{\}]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String normalizeForSearch(String text) {
    return normalizeBasic(text)
        .toLowerCase()
        .replaceAll(RegExp(r'[^0-9a-zÍ∞Ä-??s]'), ' ')
        .split(RegExp(r'\s+'))
        .map(_stripKoreanParticles)
        .where((token) => token.isNotEmpty)
        .join('');
  }

  static String _mergeCandidateSplitParticles(
    String text,
    Iterable<VoiceTextCleanupCandidate> candidates,
  ) {
    if (candidates.isEmpty) {
      return text;
    }
    final candidateSearch = candidates
        .map((candidate) => normalizeForSearch(candidate.searchableText))
        .where((value) => value.isNotEmpty)
        .join(' ');
    if (candidateSearch.isEmpty) {
      return text;
    }

    return text.replaceAllMapped(
      RegExp(
        r'([Í∞Ä-??-9a-zA-Z]{2,})\s*(?êÏÑú|??\s+([Í∞Ä-??-9a-zA-Z]{2,})\s*(?êÏÑú|??',
      ),
      (match) {
        final first = match.group(1) ?? '';
        final lastParticle = match.group(4) ?? '';
        final second = match.group(3) ?? '';
        final joined = '$first$second';
        if (candidateSearch.contains(normalizeForSearch(joined))) {
          return '$joined$lastParticle';
        }
        return match.group(0) ?? '';
      },
    );
  }

  static String _stripKoreanParticles(String token) {
    var value = token.toLowerCase().trim();
    for (final suffix in const <String>[
      '?êÏÑú',
      '?ºÎ°ú',
      'Î∂Ä??,
      'ÍπåÏ?',
      '?êÍ≤å',
      '?úÌÖå',
      'Î°?,
      '??,
      '??,
      'Î•?,
      '?Ä',
      '??,
      '??,
      'Í∞Ä',
      '?Ä',
      'Í≥?,
      '??,
    ]) {
      if (value.length > suffix.length + 1 && value.endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length);
        break;
      }
    }
    return value;
  }
}

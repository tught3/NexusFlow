import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../core/local_time.dart';
import '../data/models/event_model.dart';
import '../data/models/user_settings_model.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/settings_repository.dart';
import 'alarm_service.dart';
import 'gpt_service.dart';
import 'notification_service.dart';
import 'remote_config_service.dart';
import 'smart_preparation_alarm_service.dart';
import 'travel_time_buffer_service.dart';
import 'tts_service.dart';

class BriefingScheduleEntry {
  const BriefingScheduleEntry({
    required this.scheduledAt,
    required this.scheduled,
  });

  final DateTime scheduledAt;
  final bool scheduled;
}

class BriefingDailyScheduleResult {
  const BriefingDailyScheduleResult({
    required this.morning,
    required this.evening,
  });

  final BriefingScheduleEntry morning;
  final BriefingScheduleEntry evening;

  bool get allScheduled => morning.scheduled && evening.scheduled;
}

class BriefingNextTimes {
  const BriefingNextTimes({
    required this.morning,
    required this.evening,
  });

  final DateTime morning;
  final DateTime evening;
}

class BriefingExecutionResult {
  const BriefingExecutionResult({
    required this.delivered,
    required this.usedFallback,
    required this.message,
    this.failureReason,
  });

  final bool delivered;
  final bool usedFallback;
  final String message;
  final String? failureReason;
}

class BriefingRuntimeStatus {
  const BriefingRuntimeStatus({
    this.nextMorningAt,
    this.nextEveningAt,
    this.morningScheduled,
    this.eveningScheduled,
    this.lastExecutedType,
    this.lastExecutedAt,
    this.lastExecutionDelivered,
    this.lastExecutionMessage,
    this.lastExecutionFailureReason,
  });

  final DateTime? nextMorningAt;
  final DateTime? nextEveningAt;
  final bool? morningScheduled;
  final bool? eveningScheduled;
  final String? lastExecutedType;
  final DateTime? lastExecutedAt;
  final bool? lastExecutionDelivered;
  final String? lastExecutionMessage;
  final String? lastExecutionFailureReason;
}

class BriefingSchedulerService {
  BriefingSchedulerService({
    AlarmService? alarmService,
    GptService? gptService,
    TtsService? ttsService,
    NotificationService? notificationService,
    SettingsRepository? settingsRepository,
    EventRepository? eventRepository,
    DateTime Function()? now,
  })  : _alarmService = alarmService ?? const AlarmService(),
        _gptService = gptService ?? GptService(),
        _ttsService = ttsService ?? const TtsService(),
        _notificationService = notificationService ?? NotificationService(),
        _settingsRepository = settingsRepository,
        _eventRepository = eventRepository,
        _now = now ?? DateTime.now;

  final AlarmService _alarmService;
  final GptService _gptService;
  final TtsService _ttsService;
  final NotificationService _notificationService;
  final SettingsRepository? _settingsRepository;
  final EventRepository? _eventRepository;
  final DateTime Function() _now;

  static const String _morningAlarmId = 'briefing:morning';
  static const String _eveningAlarmId = 'briefing:evening';
  static const String _nextMorningAtKey = 'briefing:next_morning_at';
  static const String _nextEveningAtKey = 'briefing:next_evening_at';
  static const String _morningScheduledKey = 'briefing:morning_scheduled';
  static const String _eveningScheduledKey = 'briefing:evening_scheduled';
  static const String _lastExecutedTypeKey = 'briefing:last_executed_type';
  static const String _lastExecutedAtKey = 'briefing:last_executed_at';
  static const String _lastExecutionDeliveredKey =
      'briefing:last_execution_delivered';
  static const String _lastExecutionMessageKey =
      'briefing:last_execution_message';
  static const String _lastExecutionFailureReasonKey =
      'briefing:last_execution_failure_reason';
  static const Duration _briefingLeadBeforePrepStart = Duration(minutes: 30);

  Future<BriefingDailyScheduleResult> scheduleDaily({
    required String morningTime,
    required String eveningTime,
    String? userId,
  }) async {
    final resolvedUserId = _resolveUserId(userId);
    final settings = await _loadSettings(resolvedUserId);
    final morningAt = await _resolveMorningScheduleTime(
      baseMorningAt: _nextOccurrence(morningTime),
      userId: resolvedUserId,
      settings: settings.copyWith(morningBriefingAt: morningTime),
    );
    final eveningAt = _nextOccurrence(eveningTime);

    if (!RemoteConfigService.briefingEnabled) {
      debugPrint(
        'Briefing schedule skipped: remote config disabled, '
        'userId=${resolvedUserId ?? 'none'}',
      );
      return BriefingDailyScheduleResult(
        morning: BriefingScheduleEntry(
          scheduledAt: morningAt,
          scheduled: false,
        ),
        evening: BriefingScheduleEntry(
          scheduledAt: eveningAt,
          scheduled: false,
        ),
      );
    }

    final morningScheduled = await _alarmService.scheduleMorningBriefing(
      id: _morningAlarmId,
      scheduledAt: morningAt,
      userId: resolvedUserId,
    );

    final eveningScheduled = await _alarmService.scheduleEveningBriefing(
      id: _eveningAlarmId,
      scheduledAt: eveningAt,
      userId: resolvedUserId,
    );

    await _recordScheduleStatus(
      morningAt: morningAt,
      morningScheduled: morningScheduled,
      eveningAt: eveningAt,
      eveningScheduled: eveningScheduled,
    );

    return BriefingDailyScheduleResult(
      morning: BriefingScheduleEntry(
        scheduledAt: morningAt,
        scheduled: morningScheduled,
      ),
      evening: BriefingScheduleEntry(
        scheduledAt: eveningAt,
        scheduled: eveningScheduled,
      ),
    );
  }

  Future<BriefingRuntimeStatus> loadRuntimeStatus() async {
    final preferences = await SharedPreferences.getInstance();
    return BriefingRuntimeStatus(
      nextMorningAt: _parseDateTime(preferences.getString(_nextMorningAtKey)),
      nextEveningAt: _parseDateTime(preferences.getString(_nextEveningAtKey)),
      morningScheduled: preferences.getBool(_morningScheduledKey),
      eveningScheduled: preferences.getBool(_eveningScheduledKey),
      lastExecutedType: preferences.getString(_lastExecutedTypeKey),
      lastExecutedAt: _parseDateTime(preferences.getString(_lastExecutedAtKey)),
      lastExecutionDelivered: preferences.getBool(_lastExecutionDeliveredKey),
      lastExecutionMessage: preferences.getString(_lastExecutionMessageKey),
      lastExecutionFailureReason:
          preferences.getString(_lastExecutionFailureReasonKey),
    );
  }

  BriefingNextTimes nextDailyTimes({
    required String morningTime,
    required String eveningTime,
  }) {
    return BriefingNextTimes(
      morning: _nextOccurrence(morningTime),
      evening: _nextOccurrence(eveningTime),
    );
  }

  Future<BriefingExecutionResult> executeBriefing({
    required bool isMorning,
    String? userId,
  }) async {
    final resolvedUserId = _resolveUserId(userId);
    final type = isMorning ? 'morning' : 'evening';
    debugPrint(
        'Briefing execute: type=$type userId=${resolvedUserId ?? 'none'}');

    try {
      if (!RemoteConfigService.briefingEnabled) {
        const result = BriefingExecutionResult(
          delivered: false,
          usedFallback: false,
          message: 'Î∏åÎ¶¨??Í∏∞Îä•???ÑÏû¨ ÎπÑÌôú?±Ìôî?òÏñ¥ ?àÏäµ?àÎã§.',
          failureReason: 'briefing_disabled',
        );
        await _recordExecutionStatus(isMorning: isMorning, result: result);
        return result;
      }

      if (!AppEnv.isSupabaseReady) {
        const message = 'PlanFlow Î∏åÎ¶¨?ëÏùÑ ?§Ìñâ?òÎ†§Î©??úÎ≤Ñ ?§Ï†ï???ÑÏöî?©Îãà?? ?±ÏùÑ ?¥Ïñ¥ ?§Ï†ï???ïÏù∏??Ï£ºÏÑ∏??';
        await _deliverBriefing(
          message,
          isMorning: isMorning,
        );
        const result = BriefingExecutionResult(
          delivered: true,
          usedFallback: true,
          message: 'Supabase ?§Ï†ï???ÜÏñ¥ Î°úÏª¨ ?àÎÇ¥Î•??¨ÏÉù?àÏäµ?àÎã§.',
          failureReason: 'supabase_missing',
        );
        await _recordExecutionStatus(isMorning: isMorning, result: result);
        return result;
      }

      if (resolvedUserId == null) {
        const message = 'PlanFlow Î∏åÎ¶¨?ëÏùÑ ?ÑÌï¥ Î°úÍ∑∏???ÅÌÉú ?ïÏù∏???ÑÏöî?©Îãà?? ?±ÏùÑ ??Î≤??¥Ïñ¥ Ï£ºÏÑ∏??';
        await _deliverBriefing(
          message,
          isMorning: isMorning,
        );
        const result = BriefingExecutionResult(
          delivered: true,
          usedFallback: true,
          message: 'Î°úÍ∑∏?∏Ïù¥ ?ÑÏöî?òÎã§???àÎÇ¥Î•??¨ÏÉù?àÏäµ?àÎã§.',
          failureReason: 'signed_out',
        );
        await _recordExecutionStatus(isMorning: isMorning, result: result);
        return result;
      }

      final events = await _fetchRelevantEvents(
        userId: resolvedUserId,
        isMorning: isMorning,
      );

      if (events.isEmpty) {
        final message = isMorning
            ? 'Ï¢ãÏ? ?ÑÏπ®?¥Ïóê?? ?§Îäò?Ä ?àÏ†ï???ºÏ†ï???ÜÏñ¥?? ?¨Ïú†Î°úÏö¥ ?òÎ£® Î≥¥ÎÇ¥?∏Ïöî.'
            : '?§Îäò ?òÎ£®??Í≥†ÏÉù?òÏÖ®?¥Ïöî. ?¥Ïùº?Ä ?àÏ†ï???ºÏ†ï???ÜÏñ¥?? ?∏Ïïà???Ä??Î≥¥ÎÇ¥?∏Ïöî.';
        await _deliverBriefing(
          message,
          isMorning: isMorning,
        );
        final result = BriefingExecutionResult(
          delivered: true,
          usedFallback: false,
          message: isMorning
              ? '?§Îäò ?ºÏ†ï???ÜÏñ¥ Î™®Îãù Î∏åÎ¶¨?ëÏùÑ ?¨ÏÉù?àÏäµ?àÎã§.'
              : '?¥Ïùº ?ºÏ†ï???ÜÏñ¥ ?¥Î∏å??Î∏åÎ¶¨?ëÏùÑ ?¨ÏÉù?àÏäµ?àÎã§.',
        );
        await _recordExecutionStatus(isMorning: isMorning, result: result);
        return result;
      }

      final eventSummary = _buildEventSummary(events);
      var usedFallback = false;
      String? failureReason;
      late final String briefingText;
      try {
        briefingText = await _gptService.generateBriefing(
          rawText: eventSummary,
          isMorning: isMorning,
        );
      } catch (error, stackTrace) {
        failureReason = error is GptCompletionException
            ? error.reason
            : 'unknown_gpt_error';
        debugPrint('Briefing GPT failed: type=$type error=$error');
        debugPrintStack(stackTrace: stackTrace);
        briefingText = await _buildLocalBriefing(
          events,
          isMorning: isMorning,
        );
        usedFallback = true;
        debugPrint(
          'Briefing fallback used: type=$type events=${events.length} reason=$failureReason',
        );
      }
      await _deliverBriefing(briefingText, isMorning: isMorning);
      final result = BriefingExecutionResult(
        delivered: true,
        usedFallback: usedFallback,
        message: usedFallback
            ? 'OpenAI ?ëÎãµ ?§Ìå®Î°?Î°úÏª¨ Î∏åÎ¶¨?ëÏùÑ ?¨ÏÉù?àÏäµ?àÎã§.'
            : (isMorning ? 'Î™®Îãù Î∏åÎ¶¨?ëÏùÑ ?¨ÏÉù?àÏäµ?àÎã§.' : '?¥Î∏å??Î∏åÎ¶¨?ëÏùÑ ?¨ÏÉù?àÏäµ?àÎã§.'),
        failureReason: failureReason,
      );
      await _recordExecutionStatus(isMorning: isMorning, result: result);
      return result;
    } catch (error, stackTrace) {
      // Background alarm callbacks must never crash the isolate.
      debugPrint('Briefing execute failed: type=$type error=$error');
      debugPrintStack(stackTrace: stackTrace);
      const result = BriefingExecutionResult(
        delivered: false,
        usedFallback: false,
        message: 'Î∏åÎ¶¨???§Ìñâ???§Ìå®?àÏäµ?àÎã§. Î°úÍ∑∏???ÅÌÉú?Ä ?ºÏ†ï Ï°∞ÌöåÎ•??ïÏù∏??Ï£ºÏÑ∏??',
        failureReason: 'execute_failed',
      );
      await _recordExecutionStatus(isMorning: isMorning, result: result);
      return result;
    } finally {
      try {
        await _rescheduleForTomorrow(
          isMorning: isMorning,
          userId: resolvedUserId,
        );
      } catch (error, stackTrace) {
        debugPrint('Briefing reschedule failed: type=$type error=$error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> showBriefingStartNotification({
    required bool isMorning,
  }) {
    final title = isMorning ? 'Î™®Îãù Î∏åÎ¶¨?? : '?¥Î∏å??Î∏åÎ¶¨??;
    final body = isMorning
        ? '?åÎ¶º???ÑÎ•¥Î©??§Îäò ?ºÏ†ï???úÍ∞Ñ?úÏúºÎ°??ïÎ¶¨???úÎ¶¥Í≤åÏöî.'
        : '?åÎ¶º???ÑÎ•¥Î©??¥Ïùº ?ºÏ†ï???úÍ∞Ñ?úÏúºÎ°??ïÎ¶¨???úÎ¶¥Í≤åÏöî.';
    return _notificationService.scheduleEventReminder(
      id: isMorning ? 91001 : 91002,
      title: title,
      body: body,
      notifyAt: DateTime.now().add(const Duration(seconds: 1)),
      payload: isMorning ? 'briefing:morning' : 'briefing:evening',
    );
  }

  Future<bool> rescheduleNextBriefing({
    required bool isMorning,
    String? userId,
  }) {
    return _rescheduleForTomorrow(isMorning: isMorning, userId: userId);
  }

  Future<List<EventModel>> _fetchRelevantEvents({
    required String userId,
    required bool isMorning,
  }) async {
    final repository = _eventRepository ?? EventRepository.supabase();
    final allEvents = await repository.listEvents(userId: userId);
    final targetDate = isMorning ? _now() : _tomorrow();

    return allEvents.where((event) {
      final startAt = event.startAt;
      if (startAt == null) {
        return false;
      }
      return planflowIsSameLocalDay(startAt, targetDate);
    }).toList(growable: false)
      ..sort((a, b) => a.startAt!.compareTo(b.startAt!));
  }

  String _buildEventSummary(List<EventModel> events) {
    return events.map((event) {
      final time = event.startAt == null
          ? '?úÍ∞Ñ ÎØ∏Ï†ï'
          : '${planflowLocal(event.startAt!).hour.toString().padLeft(2, '0')}:${planflowLocal(event.startAt!).minute.toString().padLeft(2, '0')}';
      final location = event.location == null ? '' : ' ?•ÏÜå: ${event.location}';
      final critical = event.isCritical ? ' Ï§ëÏöî ?ºÏ†ï' : '';
      final supplies =
          event.supplies.isEmpty ? '' : ' Ï§ÄÎπÑÎ¨º: ${event.supplies.join(', ')}';
      return '- $time ${event.title}$location$critical$supplies';
    }).join('\n');
  }

  Future<String> _buildLocalBriefing(
    List<EventModel> events, {
    required bool isMorning,
  }) async {
    final prefix = isMorning
        ? 'Ï¢ãÏ? ?ÑÏπ®?ÖÎãà?? ?§Îäò ?ºÏ†ï?Ä ${events.length}Í∞úÏûÖ?àÎã§.'
        : '?§Îäò ?òÎ£®??Í≥†ÏÉù?òÏÖ®?¥Ïöî. ?¥Ïùº ?ºÏ†ï?Ä ${events.length}Í∞úÏûÖ?àÎã§.';
    final briefingEvents = events.take(6).toList(growable: false);
    final highlights = briefingEvents
        .asMap()
        .entries
        .map((entry) => _buildSecretaryEventSentence(
              entry.value,
              index: entry.key,
            ))
        .join(' ');
    final remainingCount = events.length - briefingEvents.length;
    final remainingSummary =
        remainingCount > 0 ? '?¥ÌõÑ ?ºÏ†ï??$remainingCountÍ∞????àÏäµ?àÎã§.' : '';
    final tightGapWarning = await _buildTightGapWarning(events);
    return [
      prefix,
      highlights,
      if (remainingSummary.isNotEmpty) remainingSummary,
      if (tightGapWarning != null) tightGapWarning,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  String _buildSecretaryEventSentence(
    EventModel event, {
    required int index,
  }) {
    final lead = switch (index) {
      0 when event.isCritical => 'Ï§ëÏöî???ºÏ†ï?ÖÎãà??',
      0 => 'Ï≤??ºÏ†ï?Ä',
      1 when event.isCritical => '?§Ïùå?Ä Ï§ëÏöî???ºÏ†ï?ÖÎãà??',
      1 => '?§Ïùå ?ºÏ†ï?Ä',
      _ when event.isCritical => 'Í∑∏Îã§?åÏ? Ï§ëÏöî???ºÏ†ï?ÖÎãà??',
      _ => 'Í∑∏Îã§???ºÏ†ï?Ä',
    };
    final time =
        event.startAt == null ? '?úÍ∞Ñ ÎØ∏Ï†ï' : _spokenLocalTime(event.startAt!);
    final location = event.location?.trim();
    final locationPhrase =
        location == null || location.isEmpty ? '' : ', $location?êÏÑú';
    final detail = '$time$locationPhrase ${event.title}???àÏäµ?àÎã§.';
    return '$lead $detail';
  }

  String _spokenLocalTime(DateTime value) {
    final local = planflowLocal(value);
    final period = local.hour < 12 ? '?§Ï†Ñ' : '?§ÌõÑ';
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    if (local.minute == 0) {
      return '$period $hour12??;
    }
    return '$period $hour12??${local.minute}Î∂?;
  }

  Future<String?> _buildTightGapWarning(List<EventModel> events) async {
    if (events.length < 2) {
      return null;
    }
    for (var index = 1; index < events.length; index += 1) {
      final previous = events[index - 1];
      final current = events[index];
      final previousStart = previous.startAt;
      final currentStart = current.startAt;
      if (previousStart == null || currentStart == null) {
        continue;
      }
      final gapMinutes = currentStart.difference(previousStart).inMinutes;
      if (gapMinutes <= 0) {
        continue;
      }

      var requiredMinutes = 45;
      final previousLat = previous.locationLat;
      final previousLng = previous.locationLng;
      final currentLat = current.locationLat;
      final currentLng = current.locationLng;
      if (previousLat != null &&
          previousLng != null &&
          currentLat != null &&
          currentLng != null) {
        try {
          final estimate = await TravelTimeBufferService().estimateWithMapApis(
            originLat: previousLat,
            originLng: previousLng,
            destinationLat: currentLat,
            destinationLng: currentLng,
            locationText: current.location,
          );
          requiredMinutes = estimate.minutes + 30;
        } catch (error) {
          debugPrint('Briefing travel estimate skipped: $error');
        }
      }

      if (gapMinutes < requiredMinutes) {
        return '${previous.title} ?§Ïùå ${current.title}ÍπåÏ? ?úÍ∞Ñ??Îπ†ÎìØ?òÎãà ?¥Îèô???úÎëò??Ï£ºÏÑ∏??';
      }
    }
    return null;
  }

  Future<void> _deliverBriefing(
    String text, {
    required bool isMorning,
  }) async {
    final title = isMorning ? 'Î™®Îãù Î∏åÎ¶¨?? : '?¥Î∏å??Î∏åÎ¶¨??;
    final type = isMorning ? 'morning' : 'evening';

    try {
      await _notificationService.scheduleEventReminder(
        id: isMorning ? 90001 : 90002,
        title: title,
        body: text.length > 100 ? '${text.substring(0, 100)}...' : text,
        notifyAt: DateTime.now().add(const Duration(seconds: 1)),
      );
    } catch (error, stackTrace) {
      debugPrint('Briefing notification failed: type=$type error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _ttsService.speak(text);
    } catch (error, stackTrace) {
      debugPrint('Briefing TTS failed: type=$type error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _rescheduleForTomorrow({
    required bool isMorning,
    String? userId,
  }) async {
    final resolvedUserId = _resolveUserId(userId);
    final settings = await _loadSettings(resolvedUserId);
    final nextTime =
        isMorning ? settings.morningBriefingAt : settings.eveningBriefingAt;

    final scheduledAt = isMorning
        ? await _resolveMorningScheduleTime(
            baseMorningAt: _nextOccurrence(nextTime),
            userId: resolvedUserId,
            settings: settings,
          )
        : _nextOccurrence(nextTime);
    if (isMorning) {
      final scheduled = await _alarmService.scheduleMorningBriefing(
        id: _morningAlarmId,
        scheduledAt: scheduledAt,
        userId: resolvedUserId,
      );
      await _recordSingleScheduleStatus(
        isMorning: true,
        scheduledAt: scheduledAt,
        scheduled: scheduled,
      );
      return scheduled;
    }
    final scheduled = await _alarmService.scheduleEveningBriefing(
      id: _eveningAlarmId,
      scheduledAt: scheduledAt,
      userId: resolvedUserId,
    );
    await _recordSingleScheduleStatus(
      isMorning: false,
      scheduledAt: scheduledAt,
      scheduled: scheduled,
    );
    return scheduled;
  }

  Future<void> _recordScheduleStatus({
    required DateTime morningAt,
    required bool morningScheduled,
    required DateTime eveningAt,
    required bool eveningScheduled,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_nextMorningAtKey, morningAt.toIso8601String());
    await preferences.setBool(_morningScheduledKey, morningScheduled);
    await preferences.setString(_nextEveningAtKey, eveningAt.toIso8601String());
    await preferences.setBool(_eveningScheduledKey, eveningScheduled);
  }

  Future<void> _recordSingleScheduleStatus({
    required bool isMorning,
    required DateTime scheduledAt,
    required bool scheduled,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      isMorning ? _nextMorningAtKey : _nextEveningAtKey,
      scheduledAt.toIso8601String(),
    );
    await preferences.setBool(
      isMorning ? _morningScheduledKey : _eveningScheduledKey,
      scheduled,
    );
  }

  Future<void> _recordExecutionStatus({
    required bool isMorning,
    required BriefingExecutionResult result,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastExecutedTypeKey,
      isMorning ? 'morning' : 'evening',
    );
    await preferences.setString(
      _lastExecutedAtKey,
      DateTime.now().toIso8601String(),
    );
    await preferences.setBool(_lastExecutionDeliveredKey, result.delivered);
    await preferences.setString(_lastExecutionMessageKey, result.message);
    final failureReason = result.failureReason;
    if (failureReason == null || failureReason.isEmpty) {
      await preferences.remove(_lastExecutionFailureReasonKey);
    } else {
      await preferences.setString(
        _lastExecutionFailureReasonKey,
        failureReason,
      );
    }
  }

  Future<UserSettingsModel> _loadSettings(String? userId) async {
    if (userId == null) {
      return UserSettingsModel.defaults(userId: userId ?? '');
    }

    if (_settingsRepository == null && !AppEnv.isSupabaseReady) {
      return UserSettingsModel.defaults(userId: userId);
    }

    try {
      final repository = _settingsRepository ?? SettingsRepository.supabase();
      final settings = await repository.fetchSettings(userId);
      return settings ?? UserSettingsModel.defaults(userId: userId);
    } catch (_) {
      return UserSettingsModel.defaults(userId: userId);
    }
  }

  Future<DateTime> _resolveMorningScheduleTime({
    required DateTime baseMorningAt,
    required String? userId,
    required UserSettingsModel settings,
  }) async {
    if (userId == null || userId.isEmpty) {
      return baseMorningAt;
    }

    try {
      final firstExternalEvent = await _firstExternalEventOn(
        userId: userId,
        targetDate: baseMorningAt,
      );
      if (firstExternalEvent == null || firstExternalEvent.startAt == null) {
        return baseMorningAt;
      }

      final prepStartAt = _prepStartAtFor(
        firstExternalEvent,
        settings: settings,
      );
      final adjusted = prepStartAt.subtract(_briefingLeadBeforePrepStart);
      if (adjusted.isAfter(_now()) && adjusted.isBefore(baseMorningAt)) {
        return adjusted;
      }
    } catch (error, stackTrace) {
      debugPrint('Morning briefing smart schedule skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return baseMorningAt;
  }

  Future<EventModel?> _firstExternalEventOn({
    required String userId,
    required DateTime targetDate,
  }) async {
    final repository = _eventRepository ?? EventRepository.supabase();
    final events = await repository.listEvents(userId: userId);
    final smartPreparation = const SmartPreparationAlarmService();
    final externalEvents = events.where((event) {
      final startAt = event.startAt;
      if (startAt == null || !planflowIsSameLocalDay(startAt, targetDate)) {
        return false;
      }
      return smartPreparation.isExternalEvent(
        title: event.title,
        location: event.location,
      );
    }).toList(growable: false)
      ..sort((a, b) => a.startAt!.compareTo(b.startAt!));
    return externalEvents.isEmpty ? null : externalEvents.first;
  }

  DateTime _prepStartAtFor(
    EventModel event, {
    required UserSettingsModel settings,
  }) {
    final startAt = planflowLocal(event.startAt!);
    final prepMinutes = settings.prepTimeMin.clamp(5, 240).toInt();
    final travelMinutes = SmartPreparationAlarmService.defaultTravelBufferMin
        .clamp(0, 360)
        .toInt();
    final departureAt = startAt.subtract(
      Duration(
        minutes: travelMinutes +
            SmartPreparationAlarmService.externalScheduleSlackMin,
      ),
    );
    return departureAt.subtract(Duration(minutes: prepMinutes));
  }

  String? _resolveUserId(String? userId) {
    final explicitUserId = userId?.trim();
    if (explicitUserId != null && explicitUserId.isNotEmpty) {
      return explicitUserId;
    }

    try {
      final currentUserId =
          Supabase.instance.client.auth.currentUser?.id.trim();
      if (currentUserId != null && currentUserId.isNotEmpty) {
        return currentUserId;
      }
    } catch (_) {}

    return null;
  }

  DateTime _nextOccurrence(String timeString) {
    final parts = timeString.split(':');
    final hour = int.tryParse(parts.firstOrNull ?? '') ?? 7;
    final minute = int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 30;

    final now = _now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);

    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    return target;
  }

  DateTime _tomorrow() {
    final now = _now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

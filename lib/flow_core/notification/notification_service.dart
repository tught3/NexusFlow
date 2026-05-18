import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/constants.dart';
import '../core/router.dart';

enum NotificationScheduleStatus {
  scheduled,
  skippedPast,
  permissionBlocked,
  error,
}

class NotificationScheduleResult {
  const NotificationScheduleResult({
    required this.status,
    required this.notifyAt,
    this.message,
  });

  final NotificationScheduleStatus status;
  final DateTime notifyAt;
  final String? message;

  bool get isScheduled => status == NotificationScheduleStatus.scheduled;
}

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void>? _initializationFuture;

  static const String _eventReminderChannelId = 'event_reminders';
  static const String _eventReminderChannelName = '?¼ì • ?Œë¦¼';
  static const String _eventReminderChannelDescription = '?¤ê??¤ëŠ” ?¼ì • ?Œë¦¼';
  static const int _maxSmartPreparationAlarmsPerEvent = 20;

  @visibleForTesting
  static const String criticalAlarmChannelId = 'critical_alarms_v2';

  @visibleForTesting
  static const String criticalAlarmSoundResource = 'planflow_critical_alarm';

  static const String _criticalAlarmChannelName = 'ì¤‘ìš” ?¼ì • ?ŒëŒ';
  static const String _criticalAlarmChannelDescription =
      'ì¤‘ìš” ?¼ì • ?ŒëŒ. ?¼ë°˜ ?¼ì • ?Œë¦¼ê³??¤ë¥¸ ?„ìš© ?Œë¦¼?Œìœ¼ë¡??¸ë¦½?ˆë‹¤. Android ?Œë¦¼/?•í™•???ŒëŒ/?„ì²´ ?”ë©´ ?Œë¦¼ ê¶Œí•œ??êº¼ì ¸ ?ˆìœ¼ë©?ê°•í•œ ?Œë¦¼ê³?? ê¸ˆ?”ë©´/ê²‰í™”ë©??œì‹œê°€ ?œí•œ?????ˆìŠµ?ˆë‹¤.';
  static const Color _criticalAlarmColor = Color(0xFFD32F2F);
  static const MethodChannel _settingsChannel = MethodChannel(
    'planflow/android_settings',
  );

  Future<void> initialize() {
    return _initializationFuture ??= _initializeInternal();
  }

  Future<void> schedule({
    required String id,
    required String title,
    required DateTime scheduledAt,
    String? body,
  }) {
    return scheduleEventReminder(
      id: _stableNotificationId(id),
      title: title,
      body: body ?? title,
      notifyAt: scheduledAt,
    );
  }

  int notificationIdFor(String id) {
    return _stableNotificationId(id);
  }

  Future<void> scheduleEventReminder({
    required int id,
    required String title,
    required String body,
    required DateTime notifyAt,
    String? payload,
  }) async {
    await scheduleEventReminderWithResult(
      id: id,
      title: title,
      body: body,
      notifyAt: notifyAt,
      payload: payload,
    );
  }

  Future<NotificationScheduleResult> scheduleEventReminderWithResult({
    required int id,
    required String title,
    required String body,
    required DateTime notifyAt,
    String? payload,
  }) async {
    if (!notifyAt.isAfter(DateTime.now())) {
      debugPrint('Notification skipped because notifyAt is past: $notifyAt');
      return NotificationScheduleResult(
        status: NotificationScheduleStatus.skippedPast,
        notifyAt: notifyAt,
        message: '?Œë¦¼ ?œê°„???´ë? ì§€???ˆì•½?˜ì? ?Šì•˜?µë‹ˆ??',
      );
    }

    try {
      await initialize();
      final status = await checkPermissionStatus();
      if (status.notificationsEnabled == false) {
        debugPrint('Event reminder permission blocked: notifications=false');
        return NotificationScheduleResult(
          status: NotificationScheduleStatus.permissionBlocked,
          notifyAt: notifyAt,
          message: '???Œë¦¼ ê¶Œí•œ??êº¼ì ¸ ?ˆì–´ ?Œë¦¼???ˆì•½?˜ì? ëª»í–ˆ?µë‹ˆ??',
        );
      }
      await _scheduleNotification(
        id: id,
        title: title,
        body: body,
        notifyAt: notifyAt,
        details: _eventReminderDetails,
        androidScheduleMode: reminderScheduleModeForStatus(status),
        payload: payload,
      );
      return NotificationScheduleResult(
        status: NotificationScheduleStatus.scheduled,
        notifyAt: notifyAt,
        message: status.exactAlarmsEnabled == false
            ? '?•í™•???ŒëŒ ê¶Œí•œ??êº¼ì ¸ ?ˆì–´ Androidê°€ ?Œë¦¼??ì¡°ê¸ˆ ??¶œ ???ˆìŠµ?ˆë‹¤.'
            : null,
      );
    } catch (error, stackTrace) {
      debugPrint('Event reminder scheduling failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return NotificationScheduleResult(
        status: NotificationScheduleStatus.error,
        notifyAt: notifyAt,
        message: '?Œë¦¼ ?ˆì•½ ì¤??¤ë¥˜ê°€ ë°œìƒ?ˆìŠµ?ˆë‹¤.',
      );
    }
  }

  Future<void> scheduleMonthlyNaverIcsReminder({DateTime? now}) {
    final basis = now ?? DateTime.now();
    final nextReminder = _nextMonthlyNaverIcsReminderAt(basis);
    return scheduleEventReminder(
      id: notificationIdFor('naver_ics_monthly_reminder'),
      title: '?¤ì´ë²?ìº˜ë¦°??ê°€?¸ì˜¤ê¸?,
      body: '???¼ì •???ˆì„ ???ˆì–´?? ?¤ì‹œ ê°€?¸ì˜¬ê¹Œìš”?',
      notifyAt: nextReminder,
      payload: 'naver_ics_monthly_reminder',
    );
  }

  Future<void> scheduleCriticalAlarm({
    required int id,
    required String title,
    required DateTime notifyAt,
    String? body,
  }) async {
    await scheduleCriticalAlarmWithResult(
      id: id,
      title: title,
      notifyAt: notifyAt,
      body: body,
    );
  }

  Future<NotificationScheduleResult> scheduleCriticalAlarmWithResult({
    required int id,
    required String title,
    required DateTime notifyAt,
    String? body,
  }) async {
    if (!notifyAt.isAfter(DateTime.now())) {
      debugPrint('Critical alarm skipped because notifyAt is past: $notifyAt');
      return NotificationScheduleResult(
        status: NotificationScheduleStatus.skippedPast,
        notifyAt: notifyAt,
        message: 'ì¤‘ìš” ?ŒëŒ ?œê°„???´ë? ì§€???ˆì•½?˜ì? ?Šì•˜?µë‹ˆ??',
      );
    }

    try {
      await initialize();
      await _runPermissionRequestBestEffort(
        'exact alarm before critical notification',
        _requestExactAlarmPermissionIfNeeded,
      );
      final fullScreenIntentAllowed =
          await _requestFullScreenIntentPermissionBestEffort();
      final status = await checkPermissionStatus();
      if (status.notificationsEnabled == false ||
          status.exactAlarmsEnabled == false) {
        debugPrint(
          'Critical alarm permission blocked: '
          'notifications=${status.notificationsEnabled}, '
          'exact=${status.exactAlarmsEnabled}',
        );
        return NotificationScheduleResult(
          status: NotificationScheduleStatus.permissionBlocked,
          notifyAt: notifyAt,
          message: _criticalAlarmPermissionMessage(status),
        );
      }
      final alarmTitle = criticalAlarmDisplayTitle(title);
      final alarmBody = criticalAlarmDisplayBody(title: title, body: body);
      await _scheduleNotification(
        id: id,
        title: alarmTitle,
        body: alarmBody,
        notifyAt: notifyAt,
        details: _criticalAlarmDetails(
          title: alarmTitle,
          body: alarmBody,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return NotificationScheduleResult(
        status: NotificationScheduleStatus.scheduled,
        notifyAt: notifyAt,
        message: fullScreenIntentAllowed == false
            ? 'ì¤‘ìš” ?ŒëŒ?€ ?ˆì•½?ˆì?ë§?Android ?„ì²´ ?”ë©´ ?Œë¦¼??êº¼ì ¸ ?ˆì–´ ? ê¸ˆ?”ë©´ ?ì—…?´ë‚˜ ?´ë“œ/?Œë¦½ ê²‰í™”ë©??¸ì¶œ???œí•œ?????ˆìŠµ?ˆë‹¤. ?´ë????¤ì •?ì„œ PlanFlow ?„ì²´ ?”ë©´ ?Œë¦¼???ˆìš©??ì£¼ì„¸??'
            : null,
      );
    } catch (error, stackTrace) {
      debugPrint('Critical alarm scheduling failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return NotificationScheduleResult(
        status: NotificationScheduleStatus.error,
        notifyAt: notifyAt,
        message:
            'ì¤‘ìš” ?ŒëŒ ?ˆì•½ ì¤??¤ë¥˜ê°€ ë°œìƒ?ˆìŠµ?ˆë‹¤. Android ?Œë¦¼, ?•í™•???ŒëŒ, ?„ì²´ ?”ë©´ ?Œë¦¼ ?¤ì •???•ì¸??ì£¼ì„¸??',
      );
    }
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id: id);
  }

  Future<void> cancelEventNotifications(String eventId) async {
    await cancel(notificationIdFor('$eventId:push'));
    await cancel(notificationIdFor('$eventId:critical'));
    await cancel(notificationIdFor('$eventId:departure'));
    await cancelSmartPreparationAlarms(eventId);
    await cancelPreActionAlarms(eventId);
  }

  Future<void> cancelSmartPreparationAlarms(String eventId) async {
    for (var index = 0;
        index < _maxSmartPreparationAlarmsPerEvent;
        index += 1) {
      await cancel(notificationIdFor('$eventId:smart_preparation:$index'));
    }
  }

  Future<void> cancelPreActionAlarms(String eventId) async {
    for (var index = 0;
        index < _maxSmartPreparationAlarmsPerEvent;
        index += 1) {
      await cancel(notificationIdFor('$eventId:pre_action:$index'));
    }
  }

  Future<NotificationPermissionStatus> checkPermissionStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const NotificationPermissionStatus(
        notificationsEnabled: null,
        exactAlarmsEnabled: null,
        fullScreenIntentStatus: PermissionCheckState.unsupported,
      );
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notificationsEnabled =
        await android?.areNotificationsEnabled() ?? false;
    final exactAlarmsEnabled =
        await android?.canScheduleExactNotifications() ?? false;

    return NotificationPermissionStatus(
      notificationsEnabled: notificationsEnabled,
      exactAlarmsEnabled: exactAlarmsEnabled,
      fullScreenIntentStatus: await _checkFullScreenIntentStatus(),
    );
  }

  Future<NotificationPermissionStatus> requestAndCheckPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return checkPermissionStatus();
    }

    await initialize();
    await _runPermissionRequestBestEffort(
      'notification permission',
      _requestNotificationPermissionIfNeeded,
    );
    await _runPermissionRequestBestEffort(
      'exact alarm permission',
      _requestExactAlarmPermissionIfNeeded,
    );
    await _runPermissionRequestBestEffort(
      'full-screen intent permission',
      _requestFullScreenIntentPermissionIfNeeded,
    );
    return checkPermissionStatus();
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();
    await _runPermissionRequestBestEffort(
      'notification permission',
      _requestNotificationPermissionIfNeeded,
    );
    return (await checkPermissionStatus()).notificationsEnabled == true;
  }

  Future<bool> requestExactAlarmPermission() async {
    await initialize();
    await _runPermissionRequestBestEffort(
      'exact alarm permission',
      _requestExactAlarmPermissionIfNeeded,
    );
    return (await checkPermissionStatus()).exactAlarmsEnabled == true;
  }

  Future<bool?> requestFullScreenIntentPermission() async {
    await initialize();
    return _requestFullScreenIntentPermissionBestEffort();
  }

  Future<PermissionCheckState> _checkFullScreenIntentStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return PermissionCheckState.unsupported;
    }

    try {
      final granted = await _settingsChannel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      if (granted == true) {
        return PermissionCheckState.granted;
      }
      if (granted == false) {
        return PermissionCheckState.denied;
      }
      return PermissionCheckState.needsManualCheck;
    } catch (error, stackTrace) {
      debugPrint('Full-screen intent permission check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return PermissionCheckState.needsManualCheck;
    }
  }

  @visibleForTesting
  static AndroidScheduleMode reminderScheduleModeForStatus(
    NotificationPermissionStatus status,
  ) {
    if (status.exactAlarmsEnabled == false) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  Future<bool> openAppNotificationSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      return await _settingsChannel.invokeMethod<bool>(
            'openNotificationSettings',
          ) ??
          false;
    } catch (error, stackTrace) {
      debugPrint('Open notification settings failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _initializeInternal() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_planflow'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      ),
      linux: LinuxInitializationSettings(defaultActionName: '?Œë¦¼ ?´ê¸°'),
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'naver_ics_monthly_reminder') {
          appRouter.go(AppRoutes.naverIcsImport);
          return;
        }
        final payload = response.payload ?? '';
        if (payload == 'briefing:morning' || payload == 'briefing:evening') {
          final type = payload.endsWith('evening') ? 'evening' : 'morning';
          appRouter.go('${AppRoutes.briefing}?type=$type');
        }
      },
    );
    await _runPermissionRequestBestEffort(
      'initial notification permission',
      _requestNotificationPermissionIfNeeded,
    );
  }

  Future<void> _runPermissionRequestBestEffort(
    String label,
    Future<void> Function() request,
  ) async {
    try {
      await request();
    } catch (error, stackTrace) {
      debugPrint('Notification permission request skipped ($label): $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    if (kIsWeb) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> _requestExactAlarmPermissionIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  Future<void> _requestFullScreenIntentPermissionIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestFullScreenIntentPermission();
  }

  Future<bool?> _requestFullScreenIntentPermissionBestEffort() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      return await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestFullScreenIntentPermission();
    } catch (error, stackTrace) {
      debugPrint('Full-screen intent permission request skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime notifyAt,
    required NotificationDetails details,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
  }) async {
    if (!notifyAt.isAfter(DateTime.now())) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(notifyAt.toUtc(), tz.UTC);

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: androidScheduleMode,
      title: title,
      body: body,
      payload: payload ?? id.toString(),
    );
  }

  NotificationDetails get _eventReminderDetails {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _eventReminderChannelId,
        _eventReminderChannelName,
        channelDescription: _eventReminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.event,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      linux: LinuxNotificationDetails(
        urgency: LinuxNotificationUrgency.normal,
        suppressSound: false,
      ),
    );
  }

  NotificationDetails _criticalAlarmDetails({
    required String title,
    required String body,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        criticalAlarmChannelId,
        _criticalAlarmChannelName,
        channelDescription: _criticalAlarmChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: '?“ì¹˜ë©????˜ëŠ” ì¤‘ìš” ?ŒëŒ',
        ),
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        channelAction: AndroidNotificationChannelAction.update,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(
          criticalAlarmSoundResource,
        ),
        enableVibration: true,
        autoCancel: false,
        color: _criticalAlarmColor,
        colorized: true,
        enableLights: true,
        ledColor: _criticalAlarmColor,
        ledOnMs: 1000,
        ledOffMs: 500,
        vibrationPattern: Int64List.fromList(
          <int>[0, 1200, 250, 1200, 250, 1600],
        ),
        visibility: NotificationVisibility.public,
        ticker: 'ì¤‘ìš” ?¼ì • ?ŒëŒ',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
      linux: const LinuxNotificationDetails(
        urgency: LinuxNotificationUrgency.critical,
        suppressSound: false,
      ),
    );
  }

  @visibleForTesting
  static String criticalAlarmDisplayTitle(String title) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return 'ì¤‘ìš” ?ŒëŒ';
    }
    if (trimmedTitle.startsWith('ì¤‘ìš” ?ŒëŒ')) {
      return trimmedTitle;
    }
    return 'ì¤‘ìš” ?ŒëŒ: $trimmedTitle';
  }

  @visibleForTesting
  static String criticalAlarmDisplayBody({
    required String title,
    String? body,
  }) {
    final trimmedTitle = title.trim();
    final trimmedBody = body?.trim();
    final eventLine = trimmedTitle.isEmpty ? null : trimmedTitle;
    const defaultBody = 'ì¤‘ìš” ?¼ì •??ê³??œì‘?©ë‹ˆ??';
    final bodyLines = <String>[
      'ì¤‘ìš” ?ŒëŒ?…ë‹ˆ?? ì§€ê¸??•ì¸?´ì•¼ ?˜ëŠ” ?¼ì •?…ë‹ˆ??',
      if (eventLine != null) eventLine,
      if (trimmedBody != null &&
          trimmedBody.isNotEmpty &&
          trimmedBody != defaultBody)
        trimmedBody
      else
        defaultBody,
    ];
    return bodyLines.join('\n');
  }

  int _stableNotificationId(String id) {
    final parsedId = int.tryParse(id);
    if (parsedId != null) {
      return parsedId;
    }

    var hash = 0x811c9dc5;
    for (final codeUnit in id.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }

    return hash == 0 ? 1 : hash;
  }

  DateTime _nextMonthlyNaverIcsReminderAt(DateTime now) {
    var reminder = DateTime(now.year, now.month, 1, 9);
    if (!reminder.isAfter(now)) {
      reminder = DateTime(now.year, now.month + 1, 1, 9);
    }
    return reminder;
  }

  String _criticalAlarmPermissionMessage(NotificationPermissionStatus status) {
    final blockers = <String>[];
    if (status.notificationsEnabled == false) {
      blockers.add('???Œë¦¼');
    }
    if (status.exactAlarmsEnabled == false) {
      blockers.add('?•í™•???ŒëŒ');
    }
    if (status.fullScreenIntentStatus == PermissionCheckState.denied) {
      blockers.add('?„ì²´ ?”ë©´ ?Œë¦¼');
    }

    final blockerText =
        blockers.isEmpty ? 'Android ?Œë¦¼ ?¤ì •' : blockers.join(', ');
    return 'ì¤‘ìš” ?ŒëŒ??ê°•í•˜ê²??¸ë¦¬?¤ë©´ $blockerText ê¶Œí•œ???„ìš”?©ë‹ˆ?? '
        '?´ë????¤ì •?ì„œ PlanFlow ?Œë¦¼, ?ŒëŒ ë°?ë¦¬ë§ˆ?¸ë”, ?„ì²´ ?”ë©´ ?Œë¦¼ ?ˆìš© ?íƒœë¥??•ì¸??ì£¼ì„¸?? ?´ë“œ/?Œë¦½ ê²‰í™”ë©??¸ì¶œ?€ ê¸°ê¸° ?•ì±…???°ë¼ ?¬ë¼ì§????ˆìŠµ?ˆë‹¤.';
  }
}

enum PermissionCheckState { granted, denied, unsupported, needsManualCheck }

class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
    required this.fullScreenIntentStatus,
  });

  final bool? notificationsEnabled;
  final bool? exactAlarmsEnabled;
  final PermissionCheckState fullScreenIntentStatus;
}

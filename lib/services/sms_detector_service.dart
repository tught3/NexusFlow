class SmsDetectorService {
// SMS 자동 감지 서비스 - 거래처 번호 매칭 후 파이프라인 연결
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmsDetectorService {
  static const _channel = MethodChannel('nexusflow/sms');
  static const _eventChannel = EventChannel('nexusflow/sms_events');

  static SmsDetectorService? _instance;
  static SmsDetectorService get instance =>
      _instance ??= SmsDetectorService._();
  SmsDetectorService._();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// 감지 시작
  Future<void> start({
    required List<String> knownPhoneNumbers,
    required List<String> keywords,
  }) async {
    if (_isRunning) return;
    try {
      await _channel.invokeMethod('startSmsDetection', {
        'knownPhoneNumbers': knownPhoneNumbers,
        'keywords': keywords,
      });
      _isRunning = true;
    } catch (_) {}
  }

  /// 감지 중지
  Future<void> stop() async {
    if (!_isRunning) return;
    try {
      await _channel.invokeMethod('stopSmsDetection');
    } catch (_) {}
    _isRunning = false;
  }

  /// SMS 감지 이벤트 스트림
  /// 거래처 번호 또는 키워드 매칭된 SMS만 이벤트 발생
  Stream<SmsDetectedEvent> get detectionStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return SmsDetectedEvent(
        sender: map['sender'] as String,
        body: map['body'] as String,
        matchedAccountId: map['matchedAccountId'] as String?,
        matchedContactId: map['matchedContactId'] as String?,
        matchedKeywords: List<String>.from(map['matchedKeywords'] as List),
        receivedAt: DateTime.parse(map['receivedAt'] as String),
      );
    });
  }

  /// 알려진 전화번호 업데이트
  Future<void> updatePhoneNumbers({
    required List<String> phoneNumbers,
  }) async {
    try {
      await _channel.invokeMethod('updatePhoneNumbers', {
        'phoneNumbers': phoneNumbers,
      });
    } catch (_) {}
  }
}

class SmsDetectedEvent {
  const SmsDetectedEvent({
    required this.sender,
    required this.body,
    this.matchedAccountId,
    this.matchedContactId,
    required this.matchedKeywords,
    required this.receivedAt,
  });

  final String sender;
  final String body;
  final String? matchedAccountId;
  final String? matchedContactId;
  final List<String> matchedKeywords;
  final DateTime receivedAt;
}

final smsDetectorProvider = Provider<SmsDetectorService>((ref) {
  return SmsDetectorService.instance;
});
}

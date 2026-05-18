class KakaoDetectorService {
// 카카오톡 알림 감지 서비스 - Notification Listener API 활용
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KakaoDetectorService {
  static const _channel = MethodChannel('nexusflow/kakao');
  static const _eventChannel = EventChannel('nexusflow/kakao_events');

  static KakaoDetectorService? _instance;
  static KakaoDetectorService get instance =>
      _instance ??= KakaoDetectorService._();
  KakaoDetectorService._();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Notification Listener 권한 확인
  Future<bool> hasPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('hasNotificationPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 권한 요청 (설정 화면으로 이동)
  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  /// 감지 시작
  Future<void> start({
    required List<String> knownContactNames,
    required List<String> keywords,
  }) async {
    if (_isRunning) return;
    try {
      await _channel.invokeMethod('startKakaoDetection', {
        'knownContactNames': knownContactNames,
        'keywords': keywords,
      });
      _isRunning = true;
    } catch (_) {}
  }

  /// 감지 중지
  Future<void> stop() async {
    if (!_isRunning) return;
    try {
      await _channel.invokeMethod('stopKakaoDetection');
    } catch (_) {}
    _isRunning = false;
  }

  /// 카카오톡 알림 감지 이벤트 스트림
  /// 거래처/담당자명 또는 키워드 매칭된 알림만 이벤트 발생
  Stream<KakaoDetectedEvent> get detectionStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return KakaoDetectedEvent(
        sender: map['sender'] as String,
        message: map['message'] as String,
        matchedContactId: map['matchedContactId'] as String?,
        matchedKeywords: List<String>.from(map['matchedKeywords'] as List),
        receivedAt: DateTime.parse(map['receivedAt'] as String),
      );
    });
  }
}

class KakaoDetectedEvent {
  const KakaoDetectedEvent({
    required this.sender,
    required this.message,
    this.matchedContactId,
    required this.matchedKeywords,
    required this.receivedAt,
  });

  final String sender;
  final String message;
  final String? matchedContactId;
  final List<String> matchedKeywords;
  final DateTime receivedAt;
}

final kakaoDetectorProvider = Provider<KakaoDetectorService>((ref) {
  return KakaoDetectorService.instance;
});
}

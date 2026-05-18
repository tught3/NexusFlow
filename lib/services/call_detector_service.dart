class CallDetectorService {
// 통화 종료 감지 서비스 - 통화 후 녹음 파일 분석 연결
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CallDetectorService {
  static const _channel = MethodChannel('nexusflow/call');
  static const _eventChannel = EventChannel('nexusflow/call_events');

  static CallDetectorService? _instance;
  static CallDetectorService get instance =>
      _instance ??= CallDetectorService._();
  CallDetectorService._();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// 감지 시작
  Future<void> start({
    required List<String> knownPhoneNumbers,
  }) async {
    if (_isRunning) return;
    try {
      await _channel.invokeMethod('startCallDetection', {
        'knownPhoneNumbers': knownPhoneNumbers,
      });
      _isRunning = true;
    } catch (_) {}
  }

  /// 감지 중지
  Future<void> stop() async {
    if (!_isRunning) return;
    try {
      await _channel.invokeMethod('stopCallDetection');
    } catch (_) {}
    _isRunning = false;
  }

  /// 통화 종료 이벤트 스트림
  Stream<CallEndedEvent> get detectionStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return CallEndedEvent(
        phoneNumber: map['phoneNumber'] as String,
        duration: Duration(seconds: map['durationSeconds'] as int),
        recordingFilePath: map['recordingFilePath'] as String?,
        matchedAccountId: map['matchedAccountId'] as String?,
        matchedContactId: map['matchedContactId'] as String?,
        endedAt: DateTime.parse(map['endedAt'] as String),
      );
    });
  }

  /// 녹음 파일 STT 변환 요청
  Future<String?> transcribeRecording(String filePath) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'transcribeRecording',
        {'filePath': filePath},
      );
      return result;
    } catch (_) {
      return null;
    }
  }
}

class CallEndedEvent {
  const CallEndedEvent({
    required this.phoneNumber,
    required this.duration,
    this.recordingFilePath,
    this.matchedAccountId,
    this.matchedContactId,
    required this.endedAt,
  });

  final String phoneNumber;
  final Duration duration;
  final String? recordingFilePath;
  final String? matchedAccountId;
  final String? matchedContactId;
  final DateTime endedAt;
}

final callDetectorProvider = Provider<CallDetectorService>((ref) {
  return CallDetectorService.instance;
});
}

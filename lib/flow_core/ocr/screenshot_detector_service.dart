class ScreenshotDetectorService {
// 스크린샷 감지 서비스 - MediaStore 변경 감지 후 관련성 판별
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScreenshotDetectorService {
  static const _channel = MethodChannel('nexusflow/screenshot');
  static const _eventChannel = EventChannel('nexusflow/screenshot_events');

  static ScreenshotDetectorService? _instance;
  static ScreenshotDetectorService get instance =>
      _instance ??= ScreenshotDetectorService._();
  ScreenshotDetectorService._();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// 감지 시작
  Future<void> start({
    required List<String> keywords,
    required List<String> accountNames,
    required List<String> contactNames,
  }) async {
    if (_isRunning) return;
    try {
      await _channel.invokeMethod('startDetection', {
        'keywords': keywords,
        'accountNames': accountNames,
        'contactNames': contactNames,
      });
      _isRunning = true;
    } catch (_) {}
  }

  /// 감지 중지
  Future<void> stop() async {
    if (!_isRunning) return;
    try {
      await _channel.invokeMethod('stopDetection');
    } catch (_) {}
    _isRunning = false;
  }

  /// 스크린샷 감지 이벤트 스트림
  /// 관련성 있는 스크린샷만 이벤트 발생
  Stream<ScreenshotDetectedEvent> get detectionStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return ScreenshotDetectedEvent(
        imagePath: map['imagePath'] as String,
        ocrText: map['ocrText'] as String,
        matchedKeywords: List<String>.from(map['matchedKeywords'] as List),
        detectedAt: DateTime.parse(map['detectedAt'] as String),
      );
    });
  }

  /// 키워드 업데이트 (거래처/담당자 추가 시)
  Future<void> updateKeywords({
    required List<String> keywords,
    required List<String> accountNames,
    required List<String> contactNames,
  }) async {
    try {
      await _channel.invokeMethod('updateKeywords', {
        'keywords': keywords,
        'accountNames': accountNames,
        'contactNames': contactNames,
      });
    } catch (_) {}
  }
}

class ScreenshotDetectedEvent {
  const ScreenshotDetectedEvent({
    required this.imagePath,
    required this.ocrText,
    required this.matchedKeywords,
    required this.detectedAt,
  });

  final String imagePath;
  final String ocrText;
  final List<String> matchedKeywords;
  final DateTime detectedAt;
}

final screenshotDetectorProvider =
    Provider<ScreenshotDetectorService>((ref) {
  return ScreenshotDetectorService.instance;
});
}

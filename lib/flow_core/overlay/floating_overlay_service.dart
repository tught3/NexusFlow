class FloatingOverlayService {
// 플로팅 오버레이 서비스 - 스크린샷/SMS 감지 시 다른 앱 위에 표시
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FloatingOverlayService {
  static const _channel = MethodChannel('nexusflow/overlay');

  static FloatingOverlayService? _instance;
  static FloatingOverlayService get instance =>
      _instance ??= FloatingOverlayService._();
  FloatingOverlayService._();

  bool _isShowing = false;
  bool get isShowing => _isShowing;

  /// 오버레이 권한 확인
  Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 오버레이 권한 요청 (설정 화면으로 이동)
  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// 플로팅 오버레이 표시
  /// [title] 오버레이 제목
  /// [extractedData] AI 추출 결과 (null이면 분석 중 상태)
  Future<void> show({
    required String title,
    required String sourceType,
    Map<String, dynamic>? extractedData,
    Function(Map<String, dynamic>)? onSave,
    VoidCallback? onDismiss,
  }) async {
    if (_isShowing) return;
    _isShowing = true;

    try {
      await _channel.invokeMethod('showOverlay', {
        'title': title,
        'sourceType': sourceType,
        'extractedData': extractedData,
      });
    } catch (_) {
      _isShowing = false;
    }
  }

  /// 플로팅 오버레이 숨기기
  Future<void> hide() async {
    if (!_isShowing) return;
    try {
      await _channel.invokeMethod('hideOverlay');
    } catch (_) {}
    _isShowing = false;
  }

  /// 오버레이 결과 스트림 수신
  Stream<Map<String, dynamic>> get overlayResults {
    return const EventChannel('nexusflow/overlay_results')
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
  }
}
}

// 통합 연결 테스트 - 감지 오케스트레이터(가짜 주입) + OAuth 딥링크 판별
// MethodChannel/Supabase 없이 순수 주입만으로 동작한다.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexusflow/flow_core/ocr/ocr_service.dart';
import 'package:nexusflow/flow_core/ocr/screenshot_detector_service.dart';
import 'package:nexusflow/main.dart';
import 'package:nexusflow/nexusflow_core/confidence/nexusflow_pipeline.dart';
import 'package:nexusflow/services/call_detector_service.dart';
import 'package:nexusflow/services/detection_orchestrator.dart';
import 'package:nexusflow/services/kakao_detector_service.dart';
import 'package:nexusflow/services/sms_detector_service.dart';

// ---------------------------------------------------------------------------
// 가짜 주입체
// ---------------------------------------------------------------------------

class _ProcessRecorder {
  final calls = <({String rawText, NexusflowInputSource source})>[];
  NexusflowPipelineResult? Function()? nextResult;

  Future<NexusflowPipelineResult?> process(
    String rawText,
    NexusflowInputSource source,
  ) async {
    calls.add((rawText: rawText, source: source));
    return nextResult?.call();
  }
}

class _FakeSmsDetector implements SmsDetectorDelegate {
  int startCalls = 0;
  int stopCalls = 0;
  List<String>? lastPhoneNumbers;
  List<String>? lastKeywords;
  final _controller = StreamController<SmsDetectedEvent>.broadcast();

  void emit(SmsDetectedEvent event) => _controller.add(event);

  @override
  Future<void> start({
    required List<String> knownPhoneNumbers,
    required List<String> keywords,
  }) async {
    startCalls++;
    lastPhoneNumbers = knownPhoneNumbers;
    lastKeywords = keywords;
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Stream<SmsDetectedEvent> get detectionStream => _controller.stream;
}

class _FakeKakaoDetector implements KakaoDetectorDelegate {
  int startCalls = 0;
  int stopCalls = 0;
  bool permission = true;
  int permissionRequests = 0;
  List<String>? lastContactNames;
  List<String>? lastKeywords;
  final _controller = StreamController<KakaoDetectedEvent>.broadcast();

  void emit(KakaoDetectedEvent event) => _controller.add(event);

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> requestPermission() async => permissionRequests++;

  @override
  Future<void> start({
    required List<String> knownContactNames,
    required List<String> keywords,
  }) async {
    startCalls++;
    lastContactNames = knownContactNames;
    lastKeywords = keywords;
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Stream<KakaoDetectedEvent> get detectionStream => _controller.stream;
}

class _FakeCallDetector implements CallDetectorDelegate {
  int startCalls = 0;
  int stopCalls = 0;
  String? transcribeResult;
  final _controller = StreamController<CallEndedEvent>.broadcast();

  void emit(CallEndedEvent event) => _controller.add(event);

  @override
  Future<void> start({required List<String> knownPhoneNumbers}) async =>
      startCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Stream<CallEndedEvent> get detectionStream => _controller.stream;

  @override
  Future<String?> transcribeRecording(String filePath) async =>
      transcribeResult;
}

class _FakeScreenshotDetector implements ScreenshotDetectorDelegate {
  int startCalls = 0;
  int stopCalls = 0;
  final _controller = StreamController<ScreenshotDetectedEvent>.broadcast();

  void emit(ScreenshotDetectedEvent event) => _controller.add(event);

  @override
  Future<void> start({
    required List<String> keywords,
    required List<String> accountNames,
    required List<String> contactNames,
  }) async =>
      startCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Stream<ScreenshotDetectedEvent> get detectionStream => _controller.stream;
}

class _FakeOcr implements OcrDelegate {
  OcrResult extractResult = const OcrResult(
    text: '',
    success: false,
    imagePath: '',
  );
  bool relevant = false;

  @override
  Future<OcrResult> extractText(String imagePath) async => extractResult;

  @override
  bool isRelevant({
    required String text,
    required List<String> keywords,
    required List<String> accountNames,
    required List<String> contactNames,
  }) =>
      relevant;
}

class _FakeOverlay implements OverlayDelegate {
  bool permission = false;
  final showCalls = <({String title, String sourceType})>[];

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> show({
    required String title,
    required String sourceType,
    Map<String, dynamic>? extractedData,
  }) async =>
      showCalls.add((title: title, sourceType: sourceType));
}

// ---------------------------------------------------------------------------
// 헬퍼
// ---------------------------------------------------------------------------

NexusflowPipelineResult _result(ConfidenceLevel level) {
  return NexusflowPipelineResult(
    rawSourceId: 'raw-1',
    extractionId: 'ext-1',
    extracted: const {'account_name': '오메가약국'},
    overallConfidence: 0.9,
    routingLevel: level,
    cleanedText: '',
    piiFlags: const {},
  );
}

SmsDetectedEvent _smsEvent() => SmsDetectedEvent(
      sender: '010-1111-2222',
      body: '오늘 방문 감사합니다',
      matchedKeywords: const [],
      receivedAt: DateTime.now(),
    );

void main() {
  group('DetectionOrchestrator - syncFlags', () {
    test('sms 플래그 on → 매칭 데이터와 함께 start 호출', () async {
      final sms = _FakeSmsDetector();
      final orchestrator = DetectionOrchestrator(
        loadData: () async => const DetectionData(
          contactNames: ['김원장'],
          contactPhones: ['010-1111-2222'],
          accountNames: ['오메가약국'],
        ),
        smsDetector: sms,
      );

      await orchestrator.syncFlags(
        sms: true,
        screenshot: false,
        call: false,
        kakao: false,
      );

      expect(sms.startCalls, 1);
      expect(sms.lastPhoneNumbers, ['010-1111-2222']);
      expect(sms.lastKeywords, ['오메가약국']);
    });

    test('플래그 off → 해당 서비스 stop 호출', () async {
      final sms = _FakeSmsDetector();
      final orchestrator = DetectionOrchestrator(
        loadData: () async => const DetectionData(),
        smsDetector: sms,
      );

      await orchestrator.syncFlags(
        sms: true,
        screenshot: false,
        call: false,
        kakao: false,
      );
      await orchestrator.syncFlags(
        sms: false,
        screenshot: false,
        call: false,
        kakao: false,
      );

      expect(sms.stopCalls, 1);
    });

    test('kakao 권한 없으면 start 대신 권한 요청', () async {
      final kakao = _FakeKakaoDetector()..permission = false;
      final orchestrator = DetectionOrchestrator(
        loadData: () async => const DetectionData(
          contactNames: ['김원장'],
          accountNames: ['오메가약국'],
        ),
        kakaoDetector: kakao,
      );

      await orchestrator.syncFlags(
        sms: false,
        screenshot: false,
        call: false,
        kakao: true,
      );

      expect(kakao.permissionRequests, 1);
      expect(kakao.startCalls, 0);

      // 권한 생기면 다음 syncFlags 때 start
      kakao.permission = true;
      await orchestrator.syncFlags(
        sms: false,
        screenshot: false,
        call: false,
        kakao: true,
      );
      expect(kakao.startCalls, 1);
      expect(kakao.lastContactNames, ['김원장']);
      expect(kakao.lastKeywords, ['오메가약국']);
    });
  });

  group('DetectionOrchestrator - 이벤트 → 파이프라인', () {
    test('sms 이벤트 → process가 (텍스트, sms)로 호출된다', () async {
      final sms = _FakeSmsDetector();
      final recorder = _ProcessRecorder();
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(),
        smsDetector: sms,
      );

      await orchestrator.syncFlags(
        sms: true,
        screenshot: false,
        call: false,
        kakao: false,
      );
      sms.emit(_smsEvent());
      await pumpEventQueue();

      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single.rawText,
          '[SMS 발신자: 010-1111-2222] 오늘 방문 감사합니다');
      expect(recorder.calls.single.source, NexusflowInputSource.sms);
    });

    test('mid 결과 + 오버레이 권한 false → 오버레이 show 미호출', () async {
      final sms = _FakeSmsDetector();
      final overlay = _FakeOverlay()..permission = false;
      final recorder = _ProcessRecorder()..nextResult = () => _result(ConfidenceLevel.mid);
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(),
        smsDetector: sms,
        overlayService: overlay,
      );

      await orchestrator.syncFlags(
        sms: true,
        screenshot: false,
        call: false,
        kakao: false,
      );
      sms.emit(_smsEvent());
      await pumpEventQueue();

      expect(recorder.calls, hasLength(1));
      expect(overlay.showCalls, isEmpty);
    });

    test('mid 결과 + 오버레이 권한 true → 오버레이 show 호출', () async {
      final sms = _FakeSmsDetector();
      final overlay = _FakeOverlay()..permission = true;
      final recorder = _ProcessRecorder()
        ..nextResult = () => _result(ConfidenceLevel.mid);
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(),
        smsDetector: sms,
        overlayService: overlay,
      );

      await orchestrator.syncFlags(
        sms: true,
        screenshot: false,
        call: false,
        kakao: false,
      );
      sms.emit(_smsEvent());
      await pumpEventQueue();

      expect(overlay.showCalls, hasLength(1));
      expect(overlay.showCalls.single.title, '새 기록이 도착했어요');
      expect(overlay.showCalls.single.sourceType, 'sms');
    });

    test('high 결과 → 무음 완료 (오버레이 미호출)', () async {
      final sms = _FakeSmsDetector();
      final overlay = _FakeOverlay()..permission = true;
      final recorder = _ProcessRecorder()
        ..nextResult = () => _result(ConfidenceLevel.high);
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(),
        smsDetector: sms,
        overlayService: overlay,
      );

      await orchestrator.syncFlags(
        sms: true,
        screenshot: false,
        call: false,
        kakao: false,
      );
      sms.emit(_smsEvent());
      await pumpEventQueue();

      expect(overlay.showCalls, isEmpty);
    });

    test('screenshot 이벤트 + OCR 성공·관련 → process 호출', () async {
      final screenshot = _FakeScreenshotDetector();
      final ocr = _FakeOcr()
        ..extractResult = const OcrResult(
          text: '오메가약국 신약접수 문의',
          success: true,
          imagePath: '/tmp/shot.png',
        )
        ..relevant = true;
      final recorder = _ProcessRecorder();
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(
          accountNames: ['오메가약국'],
        ),
        screenshotDetector: screenshot,
        ocrService: ocr,
      );

      await orchestrator.syncFlags(
        sms: false,
        screenshot: true,
        call: false,
        kakao: false,
      );
      screenshot.emit(ScreenshotDetectedEvent(
        imagePath: '/tmp/shot.png',
        ocrText: '',
        matchedKeywords: const [],
        detectedAt: DateTime.now(),
      ));
      await pumpEventQueue();

      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single.rawText, '오메가약국 신약접수 문의');
      expect(
          recorder.calls.single.source, NexusflowInputSource.screenshot_ocr);
    });

    test('screenshot 이벤트 + OCR 관련 없음 → process 미호출', () async {
      final screenshot = _FakeScreenshotDetector();
      final ocr = _FakeOcr()
        ..extractResult = const OcrResult(
          text: '무관한 텍스트',
          success: true,
          imagePath: '/tmp/shot.png',
        )
        ..relevant = false;
      final recorder = _ProcessRecorder();
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(),
        screenshotDetector: screenshot,
        ocrService: ocr,
      );

      await orchestrator.syncFlags(
        sms: false,
        screenshot: true,
        call: false,
        kakao: false,
      );
      screenshot.emit(ScreenshotDetectedEvent(
        imagePath: '/tmp/shot.png',
        ocrText: '',
        matchedKeywords: const [],
        detectedAt: DateTime.now(),
      ));
      await pumpEventQueue();

      expect(recorder.calls, isEmpty);
    });

    test('call 이벤트 + 녹음 파일 → STT 텍스트로 process 호출', () async {
      final call = _FakeCallDetector()..transcribeResult = '통화 내용 요약';
      final recorder = _ProcessRecorder();
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(),
        callDetector: call,
      );

      await orchestrator.syncFlags(
        sms: false,
        screenshot: false,
        call: true,
        kakao: false,
      );
      call.emit(CallEndedEvent(
        phoneNumber: '010-1111-2222',
        duration: const Duration(seconds: 60),
        recordingFilePath: '/tmp/rec.m4a',
        endedAt: DateTime.now(),
      ));
      await pumpEventQueue();

      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single.rawText, '통화 내용 요약');
      expect(
          recorder.calls.single.source, NexusflowInputSource.call_transcript);
    });

    test('call 이벤트 + 녹음 없음/STT 빈값 → process 스킵', () async {
      final call = _FakeCallDetector()..transcribeResult = null;
      final recorder = _ProcessRecorder();
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(),
        callDetector: call,
      );

      await orchestrator.syncFlags(
        sms: false,
        screenshot: false,
        call: true,
        kakao: false,
      );
      call.emit(CallEndedEvent(
        phoneNumber: '010-1111-2222',
        duration: const Duration(seconds: 60),
        endedAt: DateTime.now(),
      ));
      call.emit(CallEndedEvent(
        phoneNumber: '010-1111-2222',
        duration: const Duration(seconds: 60),
        recordingFilePath: '/tmp/rec.m4a',
        endedAt: DateTime.now(),
      ));
      await pumpEventQueue();

      expect(recorder.calls, isEmpty);
    });

    test('kakao 이벤트 → process가 (텍스트, kakao_notification)으로 호출된다',
        () async {
      final kakao = _FakeKakaoDetector()..permission = true;
      final recorder = _ProcessRecorder();
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(),
        kakaoDetector: kakao,
      );

      await orchestrator.syncFlags(
        sms: false,
        screenshot: false,
        call: false,
        kakao: true,
      );
      kakao.emit(KakaoDetectedEvent(
        sender: '김원장',
        message: '내일 방문 가능하세요?',
        matchedKeywords: const [],
        receivedAt: DateTime.now(),
      ));
      await pumpEventQueue();

      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single.rawText, '[카톡 김원장] 내일 방문 가능하세요?');
      expect(recorder.calls.single.source,
          NexusflowInputSource.kakao_notification);
    });
  });

  group('DetectionOrchestrator - dispose', () {
    test('dispose → 4종 서비스 stop + 이후 이벤트 무시', () async {
      final sms = _FakeSmsDetector();
      final kakao = _FakeKakaoDetector()..permission = true;
      final call = _FakeCallDetector();
      final screenshot = _FakeScreenshotDetector();
      final recorder = _ProcessRecorder();
      final orchestrator = DetectionOrchestrator(
        process: recorder.process,
        loadData: () async => const DetectionData(),
        smsDetector: sms,
        kakaoDetector: kakao,
        callDetector: call,
        screenshotDetector: screenshot,
      );

      await orchestrator.syncFlags(
        sms: true,
        screenshot: true,
        call: true,
        kakao: true,
      );
      await orchestrator.dispose();

      expect(sms.stopCalls, 1);
      expect(kakao.stopCalls, 1);
      expect(call.stopCalls, 1);
      expect(screenshot.stopCalls, 1);

      // dispose 후 이벤트는 파이프라인으로 가지 않는다
      sms.emit(_smsEvent());
      await pumpEventQueue();
      expect(recorder.calls, isEmpty);

      // 멱등
      await orchestrator.dispose();
      expect(sms.stopCalls, 1);
    });
  });

  group('OAuth 딥링크 판별 (isAuthCallbackUri)', () {
    test('nexusflow://auth-callback은 true', () {
      expect(
        isAuthCallbackUri(Uri.parse('nexusflow://auth-callback?code=abc')),
        isTrue,
      );
    });

    test('호스트가 다르면 false', () {
      expect(isAuthCallbackUri(Uri.parse('nexusflow://other')), isFalse);
    });

    test('스킴이 다르면 false', () {
      expect(
        isAuthCallbackUri(Uri.parse('https://auth-callback')),
        isFalse,
      );
    });
  });
}

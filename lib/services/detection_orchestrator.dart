// 감지 오케스트레이터 - 4종 감지 서비스(sms/kakao/screenshot/call)와
// 파이프라인·OCR·플로팅 오버레이를 연결한다.
//
// 테스트 가능성이 핵심: 외부 의존(Supabase, 파이프라인, 감지 서비스, OCR,
// 오버레이)을 전부 생성자 주입으로 받는다. 기본값은 실서비스/실 Supabase.
// MethodChannel·Supabase 없이 순수 주입만으로 유닛 테스트 가능.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../flow_core/ocr/ocr_service.dart';
import '../flow_core/ocr/screenshot_detector_service.dart';
import '../flow_core/overlay/floating_overlay_service.dart';
import '../nexusflow_core/confidence/nexusflow_pipeline.dart';
import '../providers/auth_provider.dart';
import '../providers/pipeline_provider.dart';
import 'call_detector_service.dart';
import 'kakao_detector_service.dart';
import 'sms_detector_service.dart';

/// 파이프라인 처리 시그니처 (오케스트레이터가 감지 이벤트를 넘긴다)
typedef PipelineProcess = Future<NexusflowPipelineResult?> Function(
  String rawText,
  NexusflowInputSource source,
);

/// 감지 매칭 데이터 로더 (Supabase 조회를 대체 가능하게 분리)
typedef DetectionDataLoader = Future<DetectionData> Function();

/// 감지 서비스 start에 필요한 매칭 데이터 (contacts + accounts 로드 결과)
class DetectionData {
  const DetectionData({
    this.contactIds = const [],
    this.contactNames = const [],
    this.contactPhones = const [],
    this.accountIds = const [],
    this.accountNames = const [],
  });

  final List<String> contactIds;
  final List<String> contactNames;
  final List<String> contactPhones;
  final List<String> accountIds;
  final List<String> accountNames;

  /// 스크린샷 OCR 관련성 판별용 전체 키워드
  List<String> get allKeywords => [...accountNames, ...contactNames];
}

// ---------------------------------------------------------------------------
// 감지 서비스 추상 인터페이스 (실서비스는 싱글턴이라 테스트에서 교체 불가 → 위임)
// ---------------------------------------------------------------------------

abstract class SmsDetectorDelegate {
  Future<void> start({
    required List<String> knownPhoneNumbers,
    required List<String> keywords,
  });
  Future<void> stop();
  Stream<SmsDetectedEvent> get detectionStream;
}

abstract class KakaoDetectorDelegate {
  Future<bool> hasPermission();
  Future<void> requestPermission();
  Future<void> start({
    required List<String> knownContactNames,
    required List<String> keywords,
  });
  Future<void> stop();
  Stream<KakaoDetectedEvent> get detectionStream;
}

abstract class CallDetectorDelegate {
  Future<void> start({required List<String> knownPhoneNumbers});
  Future<void> stop();
  Stream<CallEndedEvent> get detectionStream;
  Future<String?> transcribeRecording(String filePath);
}

abstract class ScreenshotDetectorDelegate {
  Future<void> start({
    required List<String> keywords,
    required List<String> accountNames,
    required List<String> contactNames,
  });
  Future<void> stop();
  Stream<ScreenshotDetectedEvent> get detectionStream;
}

abstract class OcrDelegate {
  Future<OcrResult> extractText(String imagePath);
  bool isRelevant({
    required String text,
    required List<String> keywords,
    required List<String> accountNames,
    required List<String> contactNames,
  });
}

abstract class OverlayDelegate {
  Future<bool> hasPermission();
  Future<void> show({
    required String title,
    required String sourceType,
    Map<String, dynamic>? extractedData,
  });
}

// ---------------------------------------------------------------------------
// 실서비스 위임 구현
// ---------------------------------------------------------------------------

class _RealSmsDetector implements SmsDetectorDelegate {
  final SmsDetectorService _svc = SmsDetectorService.instance;

  @override
  Future<void> start({
    required List<String> knownPhoneNumbers,
    required List<String> keywords,
  }) =>
      _svc.start(knownPhoneNumbers: knownPhoneNumbers, keywords: keywords);

  @override
  Future<void> stop() => _svc.stop();

  @override
  Stream<SmsDetectedEvent> get detectionStream => _svc.detectionStream;
}

class _RealKakaoDetector implements KakaoDetectorDelegate {
  final KakaoDetectorService _svc = KakaoDetectorService.instance;

  @override
  Future<bool> hasPermission() => _svc.hasPermission();

  @override
  Future<void> requestPermission() => _svc.requestPermission();

  @override
  Future<void> start({
    required List<String> knownContactNames,
    required List<String> keywords,
  }) =>
      _svc.start(knownContactNames: knownContactNames, keywords: keywords);

  @override
  Future<void> stop() => _svc.stop();

  @override
  Stream<KakaoDetectedEvent> get detectionStream => _svc.detectionStream;
}

class _RealCallDetector implements CallDetectorDelegate {
  final CallDetectorService _svc = CallDetectorService.instance;

  @override
  Future<void> start({required List<String> knownPhoneNumbers}) =>
      _svc.start(knownPhoneNumbers: knownPhoneNumbers);

  @override
  Future<void> stop() => _svc.stop();

  @override
  Stream<CallEndedEvent> get detectionStream => _svc.detectionStream;

  @override
  Future<String?> transcribeRecording(String filePath) =>
      _svc.transcribeRecording(filePath);
}

class _RealScreenshotDetector implements ScreenshotDetectorDelegate {
  final ScreenshotDetectorService _svc = ScreenshotDetectorService.instance;

  @override
  Future<void> start({
    required List<String> keywords,
    required List<String> accountNames,
    required List<String> contactNames,
  }) =>
      _svc.start(
        keywords: keywords,
        accountNames: accountNames,
        contactNames: contactNames,
      );

  @override
  Future<void> stop() => _svc.stop();

  @override
  Stream<ScreenshotDetectedEvent> get detectionStream =>
      _svc.detectionStream;
}

class _RealOcr implements OcrDelegate {
  final OcrService _svc = OcrService.instance;

  @override
  Future<OcrResult> extractText(String imagePath) =>
      _svc.extractText(imagePath);

  @override
  bool isRelevant({
    required String text,
    required List<String> keywords,
    required List<String> accountNames,
    required List<String> contactNames,
  }) =>
      _svc.isRelevant(
        text: text,
        keywords: keywords,
        accountNames: accountNames,
        contactNames: contactNames,
      );
}

class _RealOverlay implements OverlayDelegate {
  final FloatingOverlayService _svc = FloatingOverlayService.instance;

  @override
  Future<bool> hasPermission() => _svc.hasPermission();

  @override
  Future<void> show({
    required String title,
    required String sourceType,
    Map<String, dynamic>? extractedData,
  }) =>
      _svc.show(
        title: title,
        sourceType: sourceType,
        extractedData: extractedData,
      );
}

// ---------------------------------------------------------------------------
// 오케스트레이터
// ---------------------------------------------------------------------------

class DetectionOrchestrator {
  DetectionOrchestrator({
    PipelineProcess? process,
    DetectionDataLoader? loadData,
    SmsDetectorDelegate? smsDetector,
    KakaoDetectorDelegate? kakaoDetector,
    CallDetectorDelegate? callDetector,
    ScreenshotDetectorDelegate? screenshotDetector,
    OcrDelegate? ocrService,
    OverlayDelegate? overlayService,
  })  : process = process ?? _noProcess,
        _loadData = loadData ?? _loadDataFromSupabase,
        _sms = smsDetector ?? _RealSmsDetector(),
        _kakao = kakaoDetector ?? _RealKakaoDetector(),
        _call = callDetector ?? _RealCallDetector(),
        _screenshot = screenshotDetector ?? _RealScreenshotDetector(),
        _ocr = ocrService ?? _RealOcr(),
        _overlay = overlayService ?? _RealOverlay();

  final PipelineProcess process;
  final DetectionDataLoader _loadData;
  final SmsDetectorDelegate _sms;
  final KakaoDetectorDelegate _kakao;
  final CallDetectorDelegate _call;
  final ScreenshotDetectorDelegate _screenshot;
  final OcrDelegate _ocr;
  final OverlayDelegate _overlay;

  final Map<String, StreamSubscription<void>> _subscriptions = {};
  DetectionData _data = const DetectionData();
  bool _disposed = false;

  static Future<NexusflowPipelineResult?> _noProcess(
    String rawText,
    NexusflowInputSource source,
  ) async =>
      null;

  /// 감지 플래그 동기화 — 켜진 서비스는 매칭 데이터를 로드해 start,
  /// 꺼진 서비스는 stop. 재호출해도 무해 (실행 중 서비스 start는 no-op).
  Future<void> syncFlags({
    required bool sms,
    required bool screenshot,
    required bool call,
    required bool kakao,
  }) async {
    if (_disposed) return;

    if (!sms) await _safeStop('sms', _sms.stop);
    if (!kakao) await _safeStop('kakao', _kakao.stop);
    if (!call) await _safeStop('call', _call.stop);
    if (!screenshot) await _safeStop('screenshot', _screenshot.stop);

    if (!sms && !kakao && !call && !screenshot) return;

    // start에 필요한 매칭 데이터 로드 (실패 시 이번 사이클은 조용히 건너뜀)
    try {
      _data = await _loadData();
    } catch (e) {
      debugPrint('[DetectionOrchestrator] 감지 데이터 로드 실패: $e');
      return;
    }

    if (sms) {
      try {
        await _sms.start(
          knownPhoneNumbers: _data.contactPhones,
          keywords: _data.accountNames,
        );
        _subscribe('sms', _sms.detectionStream.listen(_onSms));
      } catch (e) {
        debugPrint('[DetectionOrchestrator] SMS 감지 시작 실패: $e');
      }
    }

    if (kakao) {
      try {
        final granted = await _kakao.hasPermission();
        if (!granted) {
          // 사용자가 설정에서 허용하면 다음 syncFlags 때 start된다.
          await _kakao.requestPermission();
        } else {
          await _kakao.start(
            knownContactNames: _data.contactNames,
            keywords: _data.accountNames,
          );
          _subscribe('kakao', _kakao.detectionStream.listen(_onKakao));
        }
      } catch (e) {
        debugPrint('[DetectionOrchestrator] 카카오 감지 시작 실패: $e');
      }
    }

    if (screenshot) {
      try {
        await _screenshot.start(
          keywords: _data.allKeywords,
          accountNames: _data.accountNames,
          contactNames: _data.contactNames,
        );
        _subscribe(
          'screenshot',
          _screenshot.detectionStream.listen(_onScreenshot),
        );
      } catch (e) {
        debugPrint('[DetectionOrchestrator] 스크린샷 감지 시작 실패: $e');
      }
    }

    if (call) {
      try {
        await _call.start(knownPhoneNumbers: _data.contactPhones);
        _subscribe('call', _call.detectionStream.listen(_onCall));
      } catch (e) {
        debugPrint('[DetectionOrchestrator] 통화 감지 시작 실패: $e');
      }
    }
  }

  /// 모든 구독 해제 + 감지 서비스 stop. 멱등.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final sub in _subscriptions.values) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();
    await _safeStop('sms', _sms.stop);
    await _safeStop('kakao', _kakao.stop);
    await _safeStop('call', _call.stop);
    await _safeStop('screenshot', _screenshot.stop);
  }

  // --- 이벤트 핸들러 -------------------------------------------------------

  void _onSms(SmsDetectedEvent event) {
    _runProcess(
      '[SMS 발신자: ${event.sender}] ${event.body}',
      NexusflowInputSource.sms,
    );
  }

  void _onKakao(KakaoDetectedEvent event) {
    _runProcess(
      '[카톡 ${event.sender}] ${event.message}',
      NexusflowInputSource.kakao_notification,
    );
  }

  Future<void> _onScreenshot(ScreenshotDetectedEvent event) async {
    try {
      final ocrResult = await _ocr.extractText(event.imagePath);
      if (!ocrResult.success || ocrResult.text.trim().isEmpty) return;
      final relevant = _ocr.isRelevant(
        text: ocrResult.text,
        keywords: _data.allKeywords,
        accountNames: _data.accountNames,
        contactNames: _data.contactNames,
      );
      if (!relevant) return;
      await _runProcess(
        ocrResult.text,
        NexusflowInputSource.screenshot_ocr,
      );
    } catch (e) {
      debugPrint('[DetectionOrchestrator] 스크린샷 OCR 실패: $e');
    }
  }

  Future<void> _onCall(CallEndedEvent event) async {
    final path = event.recordingFilePath;
    if (path == null || path.isEmpty) return;
    try {
      final text = await _call.transcribeRecording(path);
      if (text == null || text.trim().isEmpty) return;
      await _runProcess(text, NexusflowInputSource.call_transcript);
    } catch (e) {
      debugPrint('[DetectionOrchestrator] 통화 녹음 변환 실패: $e');
    }
  }

  Future<void> _runProcess(
    String rawText,
    NexusflowInputSource source,
  ) async {
    if (_disposed) return;
    try {
      final result = await process(rawText, source);
      await _handleResult(result, source);
    } catch (e) {
      debugPrint('[DetectionOrchestrator] 파이프라인 처리 실패: $e');
    }
  }

  /// 파이프라인 결과 후처리 — high는 무음 완료(검수 큐만),
  /// mid/low는 오버레이 권한이 있을 때만 플로팅 오버레이 표시.
  Future<void> _handleResult(
    NexusflowPipelineResult? result,
    NexusflowInputSource source,
  ) async {
    if (result == null) return;
    switch (result.routingLevel) {
      case ConfidenceLevel.high:
        return;
      case ConfidenceLevel.mid:
      case ConfidenceLevel.low:
        try {
          if (await _overlay.hasPermission()) {
            await _overlay.show(
              title: '새 기록이 도착했어요',
              sourceType: source.name,
              extractedData: result.extracted,
            );
          }
          // 권한 없으면 아무것도 안 함 — 조용히 검수 큐에만 쌓임.
        } catch (e) {
          debugPrint('[DetectionOrchestrator] 오버레이 표시 실패: $e');
        }
    }
  }

  // --- 유틸 ---------------------------------------------------------------

  void _subscribe(String key, StreamSubscription<void> sub) {
    _subscriptions[key]?.cancel();
    _subscriptions[key] = sub;
  }

  Future<void> _safeStop(String name, Future<void> Function() stop) async {
    try {
      await stop();
    } catch (e) {
      debugPrint('[DetectionOrchestrator] $name 감지 중지 실패: $e');
    }
  }

  /// Supabase에서 contacts + accounts 매칭 데이터 로드 (기본 구현).
  /// contacts는 'phone' 컬럼 실패 시 'phone_number' 재시도,
  /// 둘 다 실패 시 전화번호 없이 이름만 로드.
  static Future<DetectionData> _loadDataFromSupabase() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const DetectionData();

    List<Map<String, dynamic>> contactRows = [];
    String? phoneColumn;
    for (final candidate in const ['phone', 'phone_number', null]) {
      final select =
          candidate == null ? 'id,name' : 'id,name,$candidate';
      try {
        final rows = await client
            .schema('nexusflow')
            .from('contacts')
            .select(select)
            .eq('user_id', userId);
        contactRows = List<Map<String, dynamic>>.from(rows);
        phoneColumn = candidate;
        break;
      } catch (_) {}
    }

    List<Map<String, dynamic>> accountRows = [];
    try {
      final rows = await client
          .schema('nexusflow')
          .from('accounts')
          .select('id,name')
          .eq('user_id', userId);
      accountRows = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}

    final contactIds = <String>[];
    final contactNames = <String>[];
    final contactPhones = <String>[];
    for (final row in contactRows) {
      final id = row['id']?.toString();
      final name = row['name']?.toString();
      if (id != null && id.isNotEmpty) contactIds.add(id);
      if (name == null || name.isEmpty) continue;
      contactNames.add(name);
      if (phoneColumn != null) {
        final phone = row[phoneColumn]?.toString();
        if (phone != null && phone.isNotEmpty) contactPhones.add(phone);
      }
    }

    final accountIds = <String>[];
    final accountNames = <String>[];
    for (final row in accountRows) {
      final id = row['id']?.toString();
      final name = row['name']?.toString();
      if (id != null && id.isNotEmpty) accountIds.add(id);
      if (name != null && name.isNotEmpty) accountNames.add(name);
    }

    return DetectionData(
      contactIds: contactIds,
      contactNames: contactNames,
      contactPhones: contactPhones,
      accountIds: accountIds,
      accountNames: accountNames,
    );
  }
}

/// 로그인 상태에서만 오케스트레이터 생성. 로그아웃(userId null) 시
/// 이전 인스턴스는 ref.onDispose로 자동 dispose된다.
final detectionOrchestratorProvider = Provider<DetectionOrchestrator?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final orchestrator = DetectionOrchestrator(
    process: (rawText, source) => ref
        .read(pipelineStateProvider.notifier)
        .process(rawText: rawText, source: source),
  );
  ref.onDispose(orchestrator.dispose);
  return orchestrator;
});

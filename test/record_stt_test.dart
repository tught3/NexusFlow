// 기록 화면 STT 연결 테스트 - 렌더 스모크 + 실패 메시지 매핑 + 텍스트 탭 파이프라인 흐름
// 주의: SttService.listen은 테스트에서 호출 금지 (마이크 권한 팝업 방지)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexusflow/flow_core/stt/stt_service.dart';
import 'package:nexusflow/nexusflow_core/confidence/nexusflow_pipeline.dart';
import 'package:nexusflow/providers/pipeline_provider.dart';
import 'package:nexusflow/screens/record/record_screen.dart';

class _MockPipelineNotifier extends PipelineStateNotifier {
  _MockPipelineNotifier(super.ref);

  final List<String> processed = [];

  @override
  Future<NexusflowPipelineResult?> process({
    required String rawText,
    required NexusflowInputSource source,
  }) async {
    processed.add(rawText);
    state = const AsyncValue.data(null);
    return null;
  }
}

Future<void> _pumpRecordScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: RecordScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('RecordScreen 렌더 스모크', () {
    testWidgets('탭 3개(음성/텍스트/파일)와 앱바 제목이 표시된다', (tester) async {
      await _pumpRecordScreen(tester);

      expect(find.text('기록하기'), findsOneWidget);
      expect(find.text('음성'), findsOneWidget);
      expect(find.text('텍스트'), findsOneWidget);
      expect(find.text('파일'), findsOneWidget);
      // 마이크 아이콘은 탭바('음성' 탭)와 음성 탭 버튼 2곳에 존재
      expect(find.byIcon(Icons.mic), findsNWidgets(2));
    });

    testWidgets('음성 탭 초기 문구가 표시된다', (tester) async {
      await _pumpRecordScreen(tester);

      expect(find.text('탭하면 녹음 시작'), findsOneWidget);
    });
  });

  group('sttFailureMessage (실패 유형별 안내 메시지)', () {
    test('permissionDenied는 마이크 권한 안내', () {
      expect(
        sttFailureMessage(SttListenFailure.permissionDenied, '무시되는 원본'),
        '마이크 권한이 필요해요',
      );
    });

    test('silence는 서비스 message를 그대로 사용', () {
      expect(
        sttFailureMessage(SttListenFailure.silence, '일정 시간 말소리가 들리지 않아 종료했어요.'),
        '일정 시간 말소리가 들리지 않아 종료했어요.',
      );
    });

    test('silence에 message가 없으면 기본 안내로 폴백', () {
      expect(
        sttFailureMessage(SttListenFailure.silence, ''),
        '입력이 인식되지 않았어요. 다시 말씀해 주세요.',
      );
    });

    test('unavailable은 환경 안내', () {
      expect(
        sttFailureMessage(SttListenFailure.unavailable, '원본 무시'),
        '음성 인식을 사용할 수 없는 환경이에요',
      );
    });

    test('unsupportedLocale은 로캘 안내', () {
      expect(
        sttFailureMessage(SttListenFailure.unsupportedLocale, '원본 무시'),
        '이 기기에서는 한국어 음성 인식을 지원하지 않아요',
      );
    });
  });

  group('텍스트 탭 → 파이프라인 흐름', () {
    testWidgets('입력 후 AI 분석 시작하면 process가 호출된다', (tester) async {
      _MockPipelineNotifier? mock;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pipelineStateProvider.overrideWith((ref) {
              mock = _MockPipelineNotifier(ref);
              return mock!;
            }),
          ],
          child: const MaterialApp(home: RecordScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('텍스트'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '박원장 방문 메모');
      await tester.tap(find.text('AI 분석 시작'));
      await tester.pumpAndSettle();

      expect(mock!.processed, ['박원장 방문 메모']);
    });

    testWidgets('파일 탭 안내 문구와 파일 선택 버튼이 렌더된다', (tester) async {
      // file_picker 채널 목 킹은 생략 — 버튼 탭 없이 렌더만 확인한다.
      await _pumpRecordScreen(tester);

      await tester.tap(find.text('파일'));
      await tester.pumpAndSettle();

      expect(find.text('TXT, MD, CSV 파일을 업로드하세요'), findsOneWidget);
      expect(find.text('파일 선택'), findsOneWidget);
    });
  });
}

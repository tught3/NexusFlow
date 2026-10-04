// 컴파일 스모크 테스트 — 앱 전체(main → app → router → 모든 화면/서비스)를
// 트랜스파일 대상으로 강제해서 broken import/타입 오류를 flutter test에서 잡는다.
// 실행 로직은 없다: import만으로 컴파일 검증이 목적이다.
import 'package:flutter_test/flutter_test.dart';

import 'package:nexusflow/main.dart' as app_entry;
import 'package:nexusflow/app.dart' as app_router;
import 'package:nexusflow/screens/record/record_screen.dart' as record_screen;
import 'package:nexusflow/screens/record/confirm_screen.dart' as confirm_screen;
import 'package:nexusflow/screens/record/validation_screen.dart' as validation_screen;
import 'package:nexusflow/nexusflow_core/confidence/nexusflow_pipeline.dart' as pipeline;
import 'package:nexusflow/nexusflow_core/confidence/nexusflow_ai_service.dart' as ai_service;
import 'package:nexusflow/nexusflow_core/industry_modes/industry_mode_service.dart' as mode_service;
import 'package:nexusflow/nexusflow_core/relationship/health_score_service.dart' as health_service;
import 'package:nexusflow/nexusflow_core/insights/insight_engine.dart' as insight_engine;
import 'package:nexusflow/flow_core/stt/stt_service.dart' as stt_service;

void main() {
  test('앱 전체 소스가 컴파일된다', () {
    // 참조를 남겨 unused_import 경고도 컴파일 대상에 포함시킨다.
    final entries = <Object?>[
      app_entry.main,
      app_router.NexusFlowApp,
      record_screen.RecordScreen,
      confirm_screen.ConfirmScreen,
      validation_screen.ValidationScreen,
      pipeline.NexusflowPipeline,
      ai_service.NexusflowAiService,
      mode_service.IndustryModeService,
      health_service.HealthScoreService,
      insight_engine.InsightEngine,
      stt_service.SttService,
    ];
    expect(entries.length, 11);
  });
}

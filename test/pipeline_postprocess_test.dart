// 파이프라인 후처리(runPostProcess) 순수 로직 단위테스트 — Supabase 미초기화 상태에서 실행.
// 함수 주입 방식으로 health 계산/인사이트 생성의 호출 횟수·분기·예외 독립성을 검증한다.
import 'package:flutter_test/flutter_test.dart';

import 'package:nexusflow/nexusflow_core/confidence/nexusflow_pipeline.dart';

void main() {
  group('runPostProcess — HIGH 자동저장 케이스', () {
    test('accountId 있음 → health 계산 1회 + 인사이트 1회', () async {
      var healthCalls = <String>[];
      var insightCalls = 0;

      await NexusflowPipeline.runPostProcess(
        accountId: 'acc-1',
        calculateHealth: (accountId) async {
          healthCalls.add(accountId);
        },
        generateInsights: () async {
          insightCalls++;
        },
      );

      expect(healthCalls, ['acc-1']);
      expect(insightCalls, 1);
    });

    test('accountId null (거래처 추출 실패) → health 0회 + 인사이트 1회', () async {
      var healthCalls = 0;
      var insightCalls = 0;

      await NexusflowPipeline.runPostProcess(
        accountId: null,
        calculateHealth: (accountId) async {
          healthCalls++;
        },
        generateInsights: () async {
          insightCalls++;
        },
      );

      expect(healthCalls, 0);
      expect(insightCalls, 1);
    });

    test('accountId 빈 문자열 → health 0회 + 인사이트 1회', () async {
      var healthCalls = 0;
      var insightCalls = 0;

      await NexusflowPipeline.runPostProcess(
        accountId: '',
        calculateHealth: (accountId) async {
          healthCalls++;
        },
        generateInsights: () async {
          insightCalls++;
        },
      );

      expect(healthCalls, 0);
      expect(insightCalls, 1);
    });
  });

  group('runPostProcess — MID/LOW 검수 케이스', () {
    test('자동저장 없음(accountId null) → health 0회 + 인사이트 1회', () async {
      var healthCalls = 0;
      var insightCalls = 0;

      await NexusflowPipeline.runPostProcess(
        accountId: null,
        calculateHealth: (accountId) async {
          healthCalls++;
        },
        generateInsights: () async {
          insightCalls++;
        },
      );

      expect(healthCalls, 0);
      expect(insightCalls, 1);
    });
  });

  group('runPostProcess — 예외 독립성', () {
    test('health 계산이 예외를 던져도 인사이트 생성은 실행된다', () async {
      var insightCalls = 0;

      await NexusflowPipeline.runPostProcess(
        accountId: 'acc-1',
        calculateHealth: (accountId) async {
          throw StateError('health 계산 실패');
        },
        generateInsights: () async {
          insightCalls++;
        },
      );

      expect(insightCalls, 1);
    });

    test('인사이트 생성이 예외를 던져도 health 계산은 실행된다', () async {
      var healthCalls = <String>[];

      await NexusflowPipeline.runPostProcess(
        accountId: 'acc-2',
        calculateHealth: (accountId) async {
          healthCalls.add(accountId);
        },
        generateInsights: () async {
          throw StateError('인사이트 생성 실패');
        },
      );

      expect(healthCalls, ['acc-2']);
    });

    test('양쪽 모두 예외를 던져도 runPostProcess가 예외를 전파하지 않는다', () async {
      await NexusflowPipeline.runPostProcess(
        accountId: 'acc-3',
        calculateHealth: (accountId) async {
          throw StateError('health 계산 실패');
        },
        generateInsights: () async {
          throw StateError('인사이트 생성 실패');
        },
      );
      // 예외 없이 도달하면 통과.
    });
  });
}

# AGENTS.md for `C:\NexusFlow`

이 파일은 이 저장소에서 작업하는 에이전트의 최우선 작업 규칙이다.
항상 최신 사용자 요청과 이 파일을 우선하고, 다른 프로젝트의 규칙은 참고만 한다.

## 기본 언어
- 기본 응답 언어는 한국어다.
- 사용자가 명시적으로 다른 언어를 요청한 경우에만 그 언어를 사용한다.
- 한국어가 터미널에서 깨져 보이면 UTF-8로 다시 읽은 뒤 판단한다.

## 프로젝트 정체성
- NexusFlow는 단순 CRM, 메모앱, 회의록 앱, AI 챗봇이 아니다.
- NexusFlow는 AI가 관계 데이터를 구조화하고, 누구를 왜 언제 만나야 하는지 추천하는 모바일 우선 AI Relationship Operating System이다.
- 핵심 경험은 "말했더니 알아서 정리됨", "오늘 우선 관리할 관계가 보임", "추천 이유와 근거가 명확함"이다.
- 사용자가 모든 데이터를 직접 입력하게 만들지 말고, 음성, 텍스트, OCR, 파일, PlanFlow 일정 등 업무 흐름 속 데이터를 AI가 최대한 정리하는 방향을 우선한다.

## 작업 시작 규칙
- 작업 전 현재 경로가 `C:\NexusFlow`인지 확인한다.
- `.planning/STATE.md`가 있으면 확인한다.
- `.planning/context/ACTIVE_SUMMARY.md`가 있으면 확인한다.
- `scripts/gsd-context-hygiene.mjs`가 있으면 실행한다.
- 위 파일이나 스크립트가 없으면 없다고 기록하고 계속 진행한다.
- 기존 코드, 문서, 구조를 먼저 확인한 뒤 새 구조를 만든다.

## 작업 방식
- 범위는 사용자 요청에 맞게 좁게 유지한다.
- 관련 없는 파일을 수정하거나 삭제하지 않는다.
- 사용자가 만든 변경을 되돌리지 않는다.
- 복잡하거나 여러 하위 시스템을 건드리는 작업은 먼저 짧게 계획하고 진행한다.
- 여러 파일/기능을 병렬로 나눌 수 있고 사용자가 하위 에이전트 사용을 요청한 경우, 파일 소유 범위를 나눠 작업한다.
- 구현 후에는 가능한 검증을 실행하고, 실패하거나 막힌 경우 이유를 명확히 보고한다.
- 파일 변경이 끝난 작업은 의도한 파일만 커밋하고 원격 저장소에 푸시한다.

## Flutter / Android 규칙
- Android를 1차 주요 타깃으로 본다.
- 사용자에게 보이는 UI 텍스트는 기본적으로 한국어를 사용한다.
- Flutter 명령은 프로젝트 루트에서 실행한다.
- 검증 우선순위는 `flutter analyze`, `flutter test`, 가능한 경우 Android debug build 또는 실제 실행 확인이다.
- Windows에서 Flutter 플러그인 symlink 문제가 발생하면 Developer Mode 필요 여부를 명확히 보고한다.
- 빌드 캐시, IDE 캐시, 임시 산출물은 커밋하지 않는다.

## 데이터 / Supabase / Flow Core 규칙
- NexusFlow는 PlanFlow와 강하게 연결되는 관계/영업 OS다.
- 새 Supabase 프로젝트를 임의로 만들지 않는다.
- Supabase는 기존 PlanFlow 프로젝트를 공유하는 방향을 기본 가정으로 한다.
- DB schema, migration, RLS 변경은 PlanFlow와 NexusFlow 양쪽에 영향을 줄 수 있으므로 사용자 확인 없이 진행하지 않는다.
- `flow_core/`, `nexusflow_core/`, 공유 모델, 공유 repository, parsing/routing service, Supabase client 구조는 cross-project contract로 취급한다.
- 공유 계약을 바꾸는 변경은 사용자가 직접 요청했거나 명확히 승인한 경우에만 진행한다.

## 개인정보 / 음성 / OCR 규칙
- 음성 원본 파일은 외부 서버로 보내지 않는다.
- 필요한 경우 STT 결과 텍스트만 저장하거나 분석 대상으로 사용한다.
- SMS, 통화기록, 알림, OCR, 캡처, 연락처성 데이터는 민감정보로 취급한다.
- 권한 요청은 기능 맥락이 분명한 시점에 설명 가능하게 설계한다.
- 자동 저장보다 사용자 확인을 우선한다. 특히 관계 메모, 통화/OCR 추출 정보, 민감한 인사이트는 저장 전 확인 흐름을 고려한다.

## 제품 구조 규칙
- 업종 모드는 DB를 업종별로 쪼개는 방식이 아니라 공통 DB 구조 위에 모드별 Dictionary, Quick Action, AI Prompt, Insight를 얹는 방식으로 설계한다.
- 1차 모드의 우선순위는 제약영업 모드와 보험영업 모드다.
- 추천 결과는 대상, 이유, 근거, 추천 액션이 함께 드러나야 한다.
- AI 판단은 확정적 단정이 아니라 근거 기반 추천으로 표현한다.
- 차갑고 복잡한 CRM 대시보드보다 반복 사용에 편한 관계 우선순위 화면과 빠른 캡처 흐름을 우선한다.

## 현재 기본 구조

```text
lib/
├── flow_core/
│   ├── stt/
│   ├── voice_input/
│   ├── notification/
│   ├── briefing/
│   ├── supabase_client/
│   ├── permission/
│   ├── overlay/
│   └── ocr/
├── nexusflow_core/
│   ├── relationship/
│   ├── insights/
│   ├── industry_modes/
│   ├── confidence/
│   └── secure_vault/
├── screens/
├── widgets/
├── providers/
└── services/
```

## 완료 보고 규칙
- 무엇을 변경했는지 간단히 보고한다.
- 어떤 검증을 실행했는지, 통과/실패/차단 여부를 보고한다.
- 커밋과 푸시 여부를 보고한다.
- 남은 위험이나 다음에 필요한 작업이 있으면 짧게 적는다.

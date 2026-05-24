<!-- [WIKI:START] Personal Wiki Reference - 직접 수정 금지 -->
<!-- 작업 경로: E:\FluxStudio\nexusflow -->
<!-- 생성: 2026-05-24 09:48 -->

# Codex Common Rules
<!-- 프로젝트 공통 Codex 작업 규칙 -->

## 기본 원칙
- 기본 응답 언어는 한국어다.
- 여기에 남길 규칙은 둘 이상의 프로젝트군에서 재사용되는 것만 둔다.
- 하나의 프로젝트나 도메인에만 해당하는 규칙은 여기로 올리지 말고 해당 문서로 내린다.
- 세션 시작 시 `.planning/STATE.md`, `.planning/context/ACTIVE_SUMMARY.md`, `node scripts/gsd-context-hygiene.mjs`를 확인한다.
- 모든 작업을 진행하기 이전에 이전 대화 기록과 현재 작업 맥락을 먼저 컨텍스트 압축한 뒤 진행한다.
- 한글 중심 작업 환경이므로 모든 파일 읽기/쓰기는 UTF-8을 기준으로 처리하고, 한글이 깨지지 않게 확인한다.

## 모델 라우팅과 병렬 처리
- 비단순 작업은 계획 -> 병렬 작업자 -> 별도 리뷰어 -> 수정 -> 재리뷰 순서로 진행한다.
- 계획 단계는 `gpt-5.5`를 우선한다.
- 일반 구현은 `gpt-5.3-codex-spark`를 우선한다.
- 난도가 높은 구현과 리뷰어 검토는 `gpt-5.4-mini`를 우선한다.
- 계획이 끝나면 실제 작업은 가능한 한 무조건 병렬로 진행한다.
- 파일, 모듈, 서브시스템이 겹치지 않으면 워커를 동시에 띄우고 병렬 완료를 우선한다.
- 병렬 작업 후 자기 할 일이 끝난 서브에이전트는 즉시 닫는다.
- 완료된 서브에이전트를 띄워둔 채로 방치하지 않고, 다음 병렬 작업에 자원을 바로 쓸 수 있게 한다.

## 작업 방식
- 기존 코드, 기존 문서, 기존 구조를 먼저 확인한다.
- 새 기능, 화면, 컴포넌트, UI 요소를 추가하기 전에는 반드시 기존 디자인 스타일, CSS, 테마, 토큰, 공용 컴포넌트, 레이아웃 패턴이 있는지 먼저 확인한다.
- 새 UI는 프로젝트가 이미 쓰는 스타일과 시각 언어에 맞춰 통일해서 개발하고, 기본 브라우저/프레임워크 스타일을 그대로 덧붙이지 않는다.
- 버튼, 카드, 입력창, 모달, 색상, 간격, 폰트, 아이콘, 상태 표시 등은 기존 앱의 구현 방식을 우선 재사용한다.
- 범위는 사용자 요청에 맞게 좁게 유지한다.
- 관련 없는 파일을 수정하거나 삭제하지 않는다.
- 사용자가 만든 변경은 되돌리지 않는다.
- 새 구조는 정말 필요할 때만 만든다.
- 공통 규칙과 프로젝트 규칙이 충돌하면 프로젝트 문서를 우선한다.
- 프로젝트별 세부 규칙은 해당 프로젝트 문서에서 확인한다.

## 검증과 마무리
- 변경 후에는 재생성 스크립트와 검증 스크립트를 다시 돌린다.
- 모든 작업이 끝난 뒤에는 의도한 변경만 커밋하고 푸시한다.
- 앱/서비스 프로젝트는 커밋과 푸시 후 빌드와 실행 검증까지 완료한다.
- 앱이 아닌 문서/스크립트/위키 작업은 커밋과 푸시까지 완료한다.
- 결과를 설명할 때는 무엇을 바꿨는지, 무엇을 검증했는지, 남은 위험이 있는지를 분리해서 말한다.

## 프로젝트에서 반복 확인된 공통 규칙
<!-- [AUTO-COMMON:START] -->
- (새로 승격할 공통 규칙 없음)
<!-- [AUTO-COMMON:END] -->


# AI Behavior Rules
<!-- AI가 작업 시 반드시 따라야 할 행동 원칙. 모든 프로젝트에 공통 적용. -->

## 절대 금지
- 계획 없이 코드 먼저 작성
- 기존 동작 중인 코드를 이유 없이 리팩토링
- 승인 없이 아키텍처 변경
- 가격/구독 정책 임의 변경
- iOS 관련 코드 추가 (Android-only 프로젝트)
- 검증 없이 완료 보고
- 컨텍스트 압축 없이 작업 시작

## 필수 행동
- 작업 전: 컨텍스트 압축 -> 계획 제시 -> 승인 대기
- 작업 중: 계획 외 변경 발생 시 즉시 보고
- 작업 후: push -> 빌드 -> 실행 -> 테스트 순서로 검증
- 모르면 가정하지 말고 질문
- 난이도와 모델이 맞지 않으면 모델 변경 후 진행

## 응답 원칙
- 한국어로 응답
- 코드 변경 시 변경 전/후 명시
- 영향 범위 항상 명시 (어느 파일, 어느 기능)
- 에러 발생 시 원인 -> 해결책 -> 예방법 순서로 설명

# Anti-Patterns
<!-- 이미 실패했거나 기각된 접근법. AI에게 다시 제안하지 말 것. -->

## 전역 금지 패턴

### 상태관리
- Flutter에서 Provider 사용 -> Riverpod 사용
- React에서 Redux -> Zustand 사용

### 아키텍처
- React Native (Flutter 전환 완료, 롤백 금지)
- Firebase (Supabase로 확정, 변경 금지)
- iOS 빌드 시도 (SMS/알림 API 접근 불가)

### 코드 품질
- any 타입 남발
- useEffect 안에 직접 fetch 호출
- 하드코딩된 API 키/비밀값

## 프로젝트별 anti-patterns
-> 각 02_PROJECTS/[프로젝트].md 파일의 금지 패턴 섹션 참조

# NexusFlow

## 경로
E:\FluxStudio\nexusflow

## 현재 상태
- Stage: 컨셉 단계 (상세 내용 추후 추가)

## AI 작업 시 주의점
- 아직 아키텍처 미확정 - 임의 구조 제안 금지
- 작업 전 반드시 최신 기획 확인

## AGENTS (Project)
- NexusFlow는 CRM, 메모앱, 회의록, 일반 챗봇이 아니라 관계를 구조화하고 추천하는 모바일 우선 OS로 본다.
- 입력은 수동 입력보다 음성, 텍스트, OCR, 파일, PlanFlow 일정 같은 흐름 속 데이터 정리를 우선한다.
- 호감도 퍼센트, 성공확률, 냉한 CRM 스타일 UI는 사용하지 않는다.
- 추천 결과는 대상, 이유, 근거, 추천 액션이 함께 보여야 한다.
- `flow_core/`, `nexusflow_core/`, 공유 모델/리포지토리/파싱/라우팅 서비스는 cross-project contract로 본다.
- DB schema, migration, RLS 변경은 PlanFlow와 충돌할 수 있으므로 사용자 확인 없이 진행하지 않는다.
- `com.planflow.app`나 다른 프로젝트 패키지에 대한 삭제/정리 명령은 이 프로젝트에서 실행하지 않는다.
- 완료 보고에는 MASTER_PLAN 체크 여부를 반드시 포함한다.


<!-- [WIKI:END] -->

# AGENTS.md for `C:\NexusFlow`

이 파일은 이 저장소에서 작업하는 에이전트의 최우선 작업 규칙이다.
항상 최신 사용자 요청과 이 파일을 우선하고, 다른 프로젝트의 규칙은 참고만 한다.

## 기본 언어
- 기본 응답 언어는 한국어다.
- 사용자가 명시적으로 다른 언어를 요청한 경우에만 그 언어를 사용한다.
- 한국어가 터미널에서 깨져 보이면 UTF-8로 다시 읽은 뒤 판단한다.

## Model routing
- Default behavior: route work by task complexity automatically, even if the user names a model.
- Planner/Main for non-trivial work: `gpt-5.5`.
- Worker agents for general execution, code edits, and test updates: `gpt-5.3-codex-spark`.
- Complex refactors, architecture changes, or hard bugs: escalate to `gpt-5.4-mini` or higher.
- Review / verification: default `gpt-5.3-codex-spark`; use `gpt-5.4-mini` for high-risk changes.
- If the exact model cannot be selected in the current environment, keep the same role split and report the limitation.

## Hard routing rule
- For any non-trivial NexusFlow task, always run planner -> workers -> reviewer as separate steps before touching code.
- A user-requested model does not override the repo routing for non-trivial work.
- If a task is truly trivial enough to skip the split, say why it is trivial before editing.

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

## 체크리스트 자동 업데이트 규칙
- 이 규칙은 NEXUSFLOW_MASTER_PLAN.md 의 1차 배포 체크리스트가 100% 완료될 때까지만 적용한다.
- 1차 배포 체크리스트의 모든 항목이 [x] 로 완료되면 이 규칙은 자동으로 비활성화된다.
- 모든 작업 완료 후 반드시 NEXUSFLOW_MASTER_PLAN.md 를 열어 확인한다.
- 방금 완료한 항목이 1차 또는 2차 배포 체크리스트에 있으면 [ ] → [x] 로 변경한다.
- 체크리스트에 없는 항목이면 변경하지 않는다.
- 완료 보고 시 "MASTER_PLAN 업데이트: [항목명] 체크 완료" 또는 "MASTER_PLAN 업데이트: 해당 없음" 을 반드시 포함한다.

## 완료 보고 규칙
- 무엇을 변경했는지 간단히 보고한다.
- 어떤 검증을 실행했는지, 통과/실패/차단 여부를 보고한다.
- 커밋과 푸시 여부를 보고한다.
- 남은 위험이나 다음에 필요한 작업이 있으면 짧게 적는다.

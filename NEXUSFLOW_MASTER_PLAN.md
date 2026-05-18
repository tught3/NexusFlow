# NexusFlow 마스터 플랜

> AI 기반 관계 운영 시스템 (AI Relationship Operating System)
> Flux Studio | 1인 개발 | Android-first

---

## 제품 핵심 철학

- 사용자가 직접 입력하는 앱이 아니라 업무 흐름 속 데이터를 자동으로 흡수하는 앱
- AI가 대부분 정리하고 진짜 애매한 것만 사용자에게 물어보는 구조
- PlanFlow(시간/일정 OS) + NexusFlow(관계/영업 OS) = Flow Suite
- 핵심 포지셔닝: "말했더니 알아서 정리됨"

---

## 기술 스택

- Frontend: Flutter (Android-first)
- Backend: Supabase (PlanFlow 프로젝트 공유)
  - shared schema: 공통 유저/구독
  - planflow schema: PlanFlow 전용
  - nexusflow schema: NexusFlow 전용
- AI: GPT-4o-mini (openai-proxy via Supabase Edge Function)
- STT: on-device (speech_to_text, onDevice: true)
- OCR: on-device (google_mlkit_text_recognition)
- 상태관리: Riverpod
- 라우팅: go_router

---

## 업종 모드 (1차)

| 모드 | 코드 | 주요 타겟 |
|------|------|-----------|
| 제약영업 | pharma | 병원/의원 담당 MR |
| 보험영업 | insurance | 보험설계사 |
| 공통영업 | general | 일반 B2B 영업사원 |

> 커스텀 모드는 2차로 연기

---

## 구독 플랜

| 플랜 | 가격 | contacts 제한 | 핵심 제한 |
|------|------|---------------|-----------|
| FREE | 무료 | 30명 | AI 추출 10회/월, 인사이트 3개/월 |
| PRO | ₩6,900/월 | 200명 | AI 무제한, PlanFlow 연동, 자동감지 |
| MASTER | ₩12,900/월 | 무제한 | Secure Vault, 고급 인사이트, 월간 리포트 |
| TEAM S | ₩29,900/월 | 무제한 | 3인, 팀 대시보드 |
| TEAM M | ₩54,900/월 | 무제한 | 6인 |
| TEAM L | ₩99,900/월 | 무제한 | 12인 |
| BUSINESS | 별도문의 | 무제한 | 13인+ |

### 번들 전략
- Flow Bundle PRO: ₩19,900/월 (PlanFlow PRO + NexusFlow PRO)
- Flow Bundle MASTER: ₩29,900/월
- Flow Bundle TEAM S/M/L: ₩49,900 / ₩89,900 / ₩159,900

### 맛보기 + 광고 정책
- FREE: PRO 미리보기 3회/월, 광고 시청 시 AI 추출 +2회 (월 최대 6회)
- PRO: MASTER 기능 월 2~3회 맛보기, 광고로 일부 추가
- MASTER: TEAM 30일 무료체험 상시 노출
- 소진 시 항상 [광고 보기] + [업그레이드] 나란히 표시

---

## AI 파이프라인
입력 채널 (음성/OCR/SMS/카톡/통화/파일/수동)
↓
전처리 (STT 보정, 날짜 정규화)
↓
PII 감지 (전화번호/이메일/금액)
↓
Dictionary 매칭 (System/User/Learned)
↓
AI 구조화 (GPT-4o-mini, 업종별 프롬프트)
↓
Confidence 계산 (항목별 가중치)
↓
Confidence Routing
HIGH(0.80+) → 자동 저장
MID(0.55~0.79) → 플로팅 간단 확인
LOW(0.54-) → 강한 검수 모달
↓
저장 (raw_sources → ai_extractions → accounts/contacts → interaction_events)
↓
후처리 (Health Score 업데이트 → 인사이트 생성 → PlanFlow 연동)
---

## Confidence 기준값

| 항목 | HIGH | MID | 가중치 |
|------|------|-----|--------|
| 거래처명 | 0.85 | 0.55 | 2.0 |
| 담당자명 | 0.85 | 0.55 | 2.0 |
| 제품명 | 0.80 | 0.55 | 1.5 |
| 일정 | 0.75 | 0.50 | 1.5 |
| 액션아이템 | 0.70 | 0.50 | 1.0 |
| 관계신호 | 0.65 | 0.45 | 0.8 |
| 종합 | 0.80 | 0.55 | - |

---

## Relationship Health Score

| 지표 | 만점 | 기준 |
|------|------|------|
| 접촉 빈도 | 25점 | 최근 30일 접촉 횟수 |
| 반응 온도 | 25점 | 긍정/부정 신호 비율 |
| Follow-up 이행률 | 20점 | 액션아이템 완료율 |
| 관계 지속성 | 20점 | 거래 기간 + 공백 없는 접촉 |
| 기회 신호 | 10점 | active_signals 기준 |

| 등급 | 점수 | 의미 |
|------|------|------|
| 🟢 Strong | 80~100 | 탄탄한 관계 |
| 🔵 Stable | 60~79 | 안정적 |
| 🟡 Warming | 40~59 | 관리 필요 |
| 🟠 At Risk | 20~39 | 위험 |
| 🔴 Critical | 0~19 | 긴급 관리 |

---

## 홈 화면 구조
ZONE 1: 오늘 브리핑 (고정 상단, 탭 시 음성 브리핑)
ZONE 2: 우선순위 카드 (가로 스와이프, AI 선정 TOP5)
ZONE 3: 오늘 일정 (PlanFlow 연동, AI 브리핑 한 줄)
ZONE 4: 최근 인사이트 (스와이프로 dismiss)
FAB: 🎤 음성입력 / ✨ AI 검색 (항상 고정)

---

## 자동 감지 정책

| 채널 | 방식 | 권한 |
|------|------|------|
| 스크린샷 | MediaStore 감지 → on-device OCR → 관련성 판별 → 플로팅 | SYSTEM_ALERT_WINDOW |
| SMS | READ_SMS 권한, 거래처 번호 매칭 | READ_SMS |
| 카카오톡 알림 | Notification Listener API | BIND_NOTIFICATION_LISTENER_SERVICE |
| 통화 녹음 | 통화 종료 감지 → 파일 선택 | PHONE_STATE |

- 관련성 없으면 완전 무시
- on-device OCR 후 관련성 판별 → 있을 때만 플로팅 (1초 이내)
- 원본(음성/이미지)은 처리 후 삭제 기본값
- 모든 수집은 온보딩 동의 기반, 개별 on/off 가능

---

## Dictionary 구조

| 계층 | 관리 주체 | dict_scope |
|------|-----------|------------|
| System Dictionary | Flux Studio | system |
| User Dictionary | 사용자 직접 | user |
| Learned Dictionary | AI 자동 학습 | learned |

- 검수 시 동일 패턴 3회 확인 → User Dictionary 자동 승격
- 동일 패턴 5회 → term_dictionary 영구 등록
- 초기 System Dictionary: pharma 55개, insurance 55개, general 57개

---

## Supabase DB 구조

### nexusflow schema 테이블 (19개)
accounts, contacts, contact_aliases, contact_secure_vault,
contact_availability_slots, industry_modes, raw_sources,
ai_extractions, validation_queue, confirmed_memories,
active_signals, interaction_events, action_items,
term_dictionary, term_aliases, quick_actions,
insights, insight_feedback, shared_learning_patterns

### confidence_thresholds 테이블 (별도)
항목별 threshold 수치 저장

### subscription_plans 테이블 (별도)
구독 플랜 상수 저장

---

## 프로젝트 폴더 구조

E:\FluxStudio\NexusFlow\lib
flow_core/
stt/                    STT 서비스 (PlanFlow에서 복사)
voice_input/            음성 입력 파이프라인
notification/           알림 서비스
briefing/               브리핑 스케줄러
supabase_client/        Supabase 설정 + GPT 서비스
permission/             권한 관리
overlay/                플로팅 오버레이
ocr/                    ML Kit OCR + 스크린샷 감지
nexusflow_core/
relationship/           관계 서비스 + Health Score
insights/               인사이트 엔진
industry_modes/         업종 모드 서비스
confidence/             AI 서비스 + 파이프라인
secure_vault/           개인정보 암호화
screens/
home/                   홈 화면 (4존 레이아웃)
account/                거래처 목록/상세
contact/                담당자 상세
record/                 기록 화면
insight/                인사이트 목록/상세
settings/               설정
onboarding/             온보딩
auth/                   로그인
widgets/                  공통 위젯
providers/                Riverpod 프로바이더
services/                 감지 서비스

---

# 1차 배포 체크리스트

## 핵심 기능
- [ ] 음성 입력 → AI 파이프라인 → 저장
- [ ] 스크린샷 감지 → OCR → 플로팅 오버레이
- [x] SMS 자동 감지 → 파이프라인
- [x] 카카오톡 알림 감지 → 파이프라인
- [x] 통화 녹음 감지 → STT → 파이프라인
- [ ] Confidence Routing (HIGH 자동저장 / MID 플로팅 / LOW 검수)
- [ ] Dictionary 학습 (3회 확인 → 자동 승격)

## 화면
- [x] 홈 화면 (4존 레이아웃)
- [ ] 거래처 목록 화면
- [ ] 거래처 상세 화면 (Health Score + 타임라인)
- [ ] 담당자 상세 화면
- [ ] 기록 화면 (음성/텍스트/파일)
- [ ] 확인 모달 (MID Confidence)
- [ ] 검수 화면 (LOW Confidence)
- [ ] 인사이트 목록/상세
- [ ] 설정 화면
- [ ] 온보딩 (동의 → 모드선택 → 데이터가져오기)
- [ ] 로그인 화면

## 공통 컴포넌트
- [x] NexusflowFab (글로벌 FAB)
- [ ] 플로팅 오버레이
- [ ] Confidence 배지
- [x] Health Score 위젯

## Flow Core
- [x] nexusflow_ai_service.dart
- [x] nexusflow_pipeline.dart
- [x] floating_overlay_service.dart
- [ ] ocr_service.dart
- [x] screenshot_detector_service.dart
- [x] sms_detector_service.dart
- [x] kakao_detector_service.dart
- [x] call_detector_service.dart
- [x] health_score_service.dart
- [x] insight_engine.dart
- [ ] secure_vault_service.dart
- [ ] supabase_config.dart
- [ ] industry_mode_service.dart

## 인프라
- [x] Supabase nexusflow schema (19개 테이블)
- [x] confidence_thresholds 테이블
- [x] term_dictionary 167개 초기 데이터
- [x] subscription_plans 테이블
- [ ] Supabase Edge Function (openai-proxy) NexusFlow 연동 확인
- [ ] Android 권한 설정 완료
- [ ] 앱 서명 설정

## 런칭
- [ ] PRO Early Bird 이메일 수집 버튼
- [ ] 1차 전체 기능 무료 오픈
- [ ] Google Play 스토어 등록

---

# 2차 배포 체크리스트

## 핵심 기능 추가
- [ ] 커스텀 모드
- [ ] 팀 기능 (팀 대시보드, 팀 공유 거래처)
- [ ] Secure Vault 생체인증
- [ ] 고급 인사이트 (심층 분석)
- [ ] 월간 관계 리포트
- [ ] 업종별 벤치마크 비교
- [ ] 우선순위 전략 AI 코칭
- [ ] 루틴 실행 분석 (완료율 + 패턴 학습)

## 수익화 적용
- [ ] 구독 플랜 적용 (FREE/PRO/MASTER/TEAM/BUSINESS)
- [ ] 맛보기 기능 제한 적용
- [ ] 광고 시청 추가 기능 구현
- [ ] Early Bird 쿠폰 발송
- [ ] Flow Bundle 적용

## PlanFlow 연동 강화
- [ ] 인사이트 → PlanFlow 자동 일정 등록
- [ ] PlanFlow 완료 → NexusFlow Health Score 자동 업데이트
- [ ] 양방향 실시간 동기화

## Flow Core 패키지 분리
- [ ] packages/flow_core/ 물리적 분리
- [ ] PlanFlow + NexusFlow 공통 패키지 import

## 인프라
- [ ] Supabase 최적화 (인덱스, RLS 정책 점검)
- [ ] 성능 모니터링
- [ ] 크래시 리포팅 (Firebase Crashlytics)

---

_마지막 업데이트: 2026-05-19_

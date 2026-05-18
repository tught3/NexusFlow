# NexusFlow 전체 인수인계 / 마스터 설계 정리

## 프로젝트 개요

NexusFlow는 단순 CRM이 아니라:

> "AI가 관계 데이터를 계속 구조화하고, 지금 누구를 왜 언제 만나야 하는지 추천하는 AI Relationship Operating System"

을 목표로 하는 모바일 우선 앱.

핵심 철학:

- 사용자가 직접 입력하는 앱이 아니라
- 업무 흐름 속 데이터를 자동으로 흡수하는 앱
- AI가 대부분 정리하고
- 진짜 애매한 것만 사용자에게 물어보는 구조
- 업종별 전문화된 AI
- PlanFlow와 강하게 연결되는 관계/영업 OS

---

# 핵심 제품 방향

## PlanFlow와의 관계

```text
PlanFlow = 시간/일정 OS
NexusFlow = 관계/영업 OS

Supabase = 기존 PlanFlow 프로젝트 그대로 사용
Flow Core = 공통 엔진
```

핵심:

- 새 Supabase 프로젝트 생성하지 않음
- 기존 PlanFlow Supabase 프로젝트 사용
- schema만 분리
- PlanFlow 핵심 기능을 Flow Core로 분리 후 재사용

---

# 핵심 철학

## NexusFlow는:

❌ CRM
❌ 메모앱
❌ 회의록 앱
❌ 단순 AI 챗봇

이 아니라

# "AI 기반 관계 운영 시스템"

이어야 함.

---

# 킬러 기능 TOP3

## 1. AI 자동 데이터 추출

입력:

- 음성
- 텍스트
- TXT 파일
- 엑셀/CSV
- 카톡 캡처 OCR
- 전화 녹음/통화 텍스트
- Quick Action
- PlanFlow 일정

등.

AI가:

- 거래처
- 담당자
- 제품명
- 전문용어
- 일정
- 액션
- 관계 신호
- follow-up
- 우선순위

를 자동 구조화.

핵심 UX:

> "말했더니 알아서 정리됨"

---

## 2. AI 관계 검색 / DB 관리

자연어 기반 검색.

예:

```text
최근 방문 오래된 중요 거래처 보여줘
신약접수 얘기 나온 거래처 정리해줘
보험료 부담 언급 고객 보여줘
follow-up 놓친 사람 있어?
```

결과:

```text
대상
이유
근거
추천 액션
```

형태.

---

## 3. AI 우선순위 추천

홈 핵심 기능.

```text
오늘 우선 관리할 관계
```

AI가:

- 최근 접촉일
- 거래처 중요도
- follow-up 지연
- 기회 신호
- 리스크 신호
- 업종별 이벤트
- PlanFlow 일정
- 진료타임
- 지역/동선

등을 종합해서 추천.

---

# 업종 모드 시스템

절대:

```text
제약용 필드
보험용 필드
```

이렇게 나누지 않음.

## 구조

```text
공통 DB 구조
+
모드별 Dictionary
+
모드별 Quick Action
+
모드별 AI Prompt
+
모드별 인사이트
```

---

# 1차 모드

## 제약영업 모드

### 주요 용어

```text
신약접수
원내 코드
처방
경쟁약
약제부
D/C
조성
학회
샘플
오더
```

### Quick Action

```text
신약접수
원내 코드
처방 가능성
경쟁약 언급
샘플 요청
D/C 위험
학회 follow-up
약제부 논의
```

### 중요 인사이트

```text
신약접수 가능성
경쟁약 증가
D/C 위험
진료타임 기반 방문 추천
```

---

## 보험영업 모드

### 주요 용어

```text
갱신
보장분석
실손
특약
리모델링
보험료 부담
해지 위험
```

### Quick Action

```text
갱신 예정
보장분석
실손 문의
가족 보험
리모델링 가능성
보험료 부담
```

### 중요 인사이트

```text
계약 가능성
가족 보험 확장
갱신 시점
보험료 부담
해지 위험
```

---

## 공통 영업 모드

### 주요 용어

```text
견적
계약
제안서
클레임
경쟁사
follow-up
```

---

# 디자인 방향

## 핵심

모드별로 색 분리하지 않음.

디자인은 공통.

내용만 업종별 변경.

---

# 디자인 키워드

```text
Professional
Clean
Reliable
Fast
AI-assisted
Operational
```

---

# 컬러 시스템

## Core Palette

```text
Deep Navy #16213E
Slate Gray #334155
Electric Blue #2563EB
Medical Cyan Accent #06B6D4
Background #F8FAFC
Card White #FFFFFF
```

## Status Colors

```text
Opportunity #16A34A
Warning #F59E0B
Risk #DC2626
Neutral #64748B
```

---

# 모바일 우선 UX

핵심:

- 모바일 우선
- 태블릿 확장 가능
- 한 손 사용
- 현장 사용

예:

```text
차 안
병원 복도
이동 중
엘리베이터
```

---

# 홈 화면 구조

홈은:

> "오늘 뭐 해야 하는가"

만 보여주는 화면.

너무 많은 기능 배치 금지.

---

# 홈 구조

## AI는 탭이 아님

AI는 글로벌 FAB.

### FAB

```text
🎤 = 빠른 음성 입력
✨ = AI 검색/명령
```

어느 탭에서든 사용 가능.

---

# 홈 내용

아코디언 구조.

접혔을 때:

- 핵심 요약만
- 눌렀을 때 상세 펼침

---

## 홈 섹션

### 1. 오늘 우선 관리할 관계

요약:

```text
중요 3건
follow-up 지연 1건
계약 준비 1건
```

펼치면:

- 거래처 카드
- 추천 액션
- 준비 자료
- 일정 등록

---

### 2. 오늘 일정 + 브리핑

PlanFlow 연동.

예:

```text
10:00 박원장 방문
준비: ROI 자료
최근 이슈: 경쟁약 질문 증가
```

---

### 3. 최근 인사이트

요약:

```text
기회 2건
리스크 3건
데이터 확인 4건
```

---

# 거래처 상세 화면

핵심:

```text
거래처 정보
+
관계 흐름
+
다음 행동
```

---

# 상세 화면 요소

## 핵심 브리핑

AI가 최근 관계 흐름 분석.

예:

```text
위너프에이플러스 조성 설명 후
신약접수 논의가 있었고
follow-up 이후 31일 지남
```

---

## 진료타임 / 방문 가능 시간

제약영업 핵심.

요일 + 오전/오후 슬롯 구조.

예:

```text
화 오전/오후
수 오전
금 오후
```

### DB 구조 필요

```text
contact_availability_slots
```

---

## 관계 메모리

3층 구조.

### Permanent

```text
숫자 중심 설명 선호
가격 민감
```

### Temporal

```text
최근 경쟁약 질문 증가
최근 바쁨
```

### Action

```text
다음 방문 시 신약접수 확인
```

---

## 타임라인

```text
5/17 음성 메모
5/10 미팅
4/25 통화
```

---

# 기록 / AI 검수 화면

## 입력 채널

```text
음성
텍스트
TXT
엑셀/CSV
카톡 캡처
통화 정리
Quick Action
```

---

# 음성 입력 핵심

## STT 결과를 그대로 믿지 않음.

반드시:

```text
STT
→ 유사어 보정
→ Dictionary 매칭
→ 문맥 보정
→ AI 구조화
```

예:

```text
원주기도 세브란스 일정 검생
→
원주기독세브란스병원 일정 검색
```

---

# AI 검수 모달

AI가 추출:

```text
담당자
거래처
제품
일정
액션
관계 신호
```

사용자는:

```text
저장
수정
삭제
```

만.

---

# Confidence Routing

## HIGH

자동 처리.

예:

```text
위너 플러스
→ 위너프에이플러스
```

사용자에게 안 물어봄.

---

## MID

간단 확인.

예:

```text
조성 = 제품 조성?
```

---

## LOW

강한 검수.

예:

```text
D씨
```

---

# 검수 정책

중요:

검수는 사용자가 처리하기 전까지 사라지면 안 됨.

```text
validation_queue 유지
pending 상태 유지
```

1회 학습 후:

자동 처리 가능.

---

# 개인정보 정책

## 개인정보는 무조건 암호화 저장.

예:

```text
전화번호
주소
생일
가족정보
보험 관련 정보
통화 원문
```

---

# Secure Vault

```text
contact_secure_vault
```

저장.

---

# UI 정책

기본:

```text
010-12**-****
5월 **일
```

전체 보기:

```text
생체인증/PIN 필요
```

---

# 생체인증

필수 도입.

사용 위치:

```text
민감정보 보기
앱 잠금 해제
빠른 로그인
```

조건:

```text
Google/Kakao/Naver 로그인 후
생체 빠른 로그인 설정 가능
```

---

# 카톡 OCR 자동화

완전 자동 수집은 안 함.

대신:

```text
스크린샷 감지
→ 분석 제안
→ 사용자 확인
→ OCR 분석
```

구조.

---

# 전화 녹음 자동화

```text
통화 종료
→ 새 통화 파일 감지
→ 분석 제안
→ STT
→ AI 구조화
```

---

# 인사이트 엔진

핵심:

> "와 이런 것도 알려줘?"

느낌.

단순 통계 금지.

---

# 인사이트 종류

## 오늘 바로 할 일

```text
신약접수 follow-up 지연
계약 준비 누락 가능성
```

---

## 방문 타이밍 추천

```text
수요일 오전 원주권 방문 추천
```

진료타임 + 지역 + 일정 + 우선순위 결합.

---

## 기회 신호

```text
신약접수 가능성 증가
가족 보험 확장 기회
```

---

## 리스크 신호

```text
경쟁약 언급 후 follow-up 없음
보험료 부담 언급
장기 미접촉
```

---

## 데이터 품질

```text
진료타임 업데이트 필요
용어 의미 미확정
```

---

# 인사이트 정책

반복 금지.

상태 필요:

```text
new
seen
acted
dismissed
expired
```

---

# 인사이트 피드백

```text
도움됨
잘못됨
이미 처리함
```

학습 반영.

---

# 온보딩 구조

## 단계별 진행

### 1. 업종 모드 선택

```text
제약영업
보험영업
공통 영업
커스텀
```

---

### 2. 데이터 가져오기

```text
엑셀/CSV
TXT/메모
연락처
```

---

### 3. PlanFlow 연동

기존 PlanFlow Supabase 사용.

---

### 4. 권한 설정

```text
마이크
스크린샷 감지
통화 파일 접근
브리핑 알림
```

---

### 5. 보안 설정

```text
Secure Vault
생체인증
빠른 로그인
```

---

# Flow Core 구조

핵심:

공통 기능은 NexusFlow에서 새로 만들지 않음.

## 먼저 PlanFlow에서 분리.

---

# 공통 엔진

```text
voice_input_engine
stt_correction_engine
notification_engine
briefing_engine
schedule_parser
permission_manager
supabase_client
```

---

# 구조

```text
packages/flow_core
```

PlanFlow와 NexusFlow가 둘 다 import.

---

# 매우 중요

## 공통 기능 수정 위치

```text
flow_core 수정
```

절대:

```text
PlanFlow 복붙
NexusFlow 복붙
```

하지 않음.

---

# 프로젝트 구조

```text
apps/
  planflow_app
  nexusflow_app

packages/
  flow_core
  planflow_core
  nexusflow_core
```

---

# Supabase 구조

```text
shared
planflow
nexusflow
```

---

# 핵심 DB 테이블

## 핵심 테이블들

```text
industry_modes
accounts
contacts
contact_aliases
contact_secure_vault
contact_availability_slots
raw_sources
ai_extractions
confirmed_memories
active_signals
interaction_events
action_items
term_dictionary
term_aliases
quick_actions
validation_queue
insights
insight_feedback
shared_learning_patterns
```

---

# AI 파이프라인

```text
입력
↓
STT/OCR
↓
PII 감지
↓
Dictionary 매칭
↓
Confidence 계산
↓
AI 추출
↓
검수
↓
저장
↓
인사이트/브리핑/우선순위 추천
```

---

# 다음 단계

다음 AI와 이어서 해야 하는 것:

```text
1. AI 파이프라인 상세 설계
2. DB relation 상세 설계
3. Flow Core 상세 구조
4. 실제 Flutter 앱 구조
5. Codex 작업지시서 생성
6. Supabase migration 설계
7. 실제 UI 컴포넌트 구조 설계
8. API/Service layer 설계
```

---

# 새 AI에게 바로 전달할 말

```text
현재 NexusFlow는:
- 모바일 우선 AI Relationship Operating System
- PlanFlow와 강하게 연동
- 기존 PlanFlow Supabase 프로젝트 사용
- Flow Core 공통 엔진 구조
- 업종 모드 기반 시스템
- AI 자동 데이터 구조화 중심
- Confidence Routing 구조
- Secure Vault 개인정보 암호화 구조
- 인사이트 중심 UX

까지 설계 완료 상태.

지금부터는:
1. AI 파이프라인 상세 설계
2. Flutter 실제 앱 구조
3. Flow Core 구조 상세화
4. Codex 작업지시서
5. Supabase migration

단계로 이어서 진행하면 됨.
```


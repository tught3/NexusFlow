# Play Console 등록 절차 체크리스트 — NexusFlow

## 0. 사전 준비
- [ ] Play Console 개발자 계정 ($25 등록비, 1회)
- [ ] 앱 서명 완료 — `android/key.properties` + `upload-keystore.jks` (2026-10-05 생성 완료, gitignore 확인)
- [ ] `flutter build appbundle --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` → `build/app/outputs/bundle/release/app-release.aab`
- [ ] AAB 서명 확인: `jarsigner -verify build/app/outputs/bundle/release/app-release.aab`
- [ ] 앱 버전 코드/이름 확인 (pubspec.yaml version)

## 1. 스토어 등록
- [ ] docs/play-store/listing.md → 스토어 등록 정보 입력
- [ ] 앱 아이콘 512×512, 기능 그래픽 1024×500, 스크린샷 2장+ 업로드
- [ ] 카테고리: 비즈니스

## 2. 앱 콘텐츠
- [ ] 데이터 안전 설문 — docs/play-store/data-safety.md 기반
- [ ] 개인정보 처리방침 URL — docs/play-store/privacy-policy.md를 웹 게시 후 URL 입력 [TODO: 호스팅 필요]
- [ ] 콘텐츠 등급 설문 (폭력성/성인 콘텐츠 없음 — 비즈니스 도구)
- [ ] 타겟 오디언스: 18세 이상 (아동 대상 아님)
- [ ] 뉴스 앱 아님, 정부 앱 아님
- [ ] 광고 포함 여부: 아니오 (1차)

## 3. 민감 권한 선언 (중요 — 심사 관문)
앱이 요청하는 제한된 권한의 근거 문서화 필요 (docs/play-store/data-safety.md 민감 권한 표 참조):
- [ ] SMS (RECEIVE_SMS/READ_SMS): 거래처 문자 자동 기록 — **옵트인 기본 OFF** 근거 명시
- [ ] 전화 (READ_PHONE_STATE): 통화 종료 이벤트 감지
- [ ] 알림 리스너: 카톡 알림 감지 — 옵트인
- [ ] 위 권한이 심사 리스크가 크면 1차 빌드에서 제거하고 감지 채널을 2차로 연기하는 방안 검토
  (AndroidManifest.xml에서 RECEIVE_SMS/READ_SMS/READ_CALL_LOG/READ_PHONE_STATE 제거 + Dart 감지 서비스 비활성)

## 4. 출시 전 최종 확인
- [ ] 실기기 설치·기본 흐름 최종 점검 (온보딩→로그인→기록→AI 분석→거래처)
- [ ] 디버그 로그/디버그 배지 없는 릴리즈 빌드 확인
- [ ] INTERNET 권한 등 매니페스트 점검
- [ ] 백엔드 상태: Supabase xqv 프로젝트, 테이블 public 스키마 이동 완료(2026-10-05), Edge Function openai-proxy 동작 확인

## 5. 출시 트랙
- [ ] 내부 테스트 트랙 먼저 (테스터 1~2명) → 정상 확인 후 프로덕션
- [ ] 1차 출시: 전 기능 무료 (PRO Early Bird 수집은 2차)

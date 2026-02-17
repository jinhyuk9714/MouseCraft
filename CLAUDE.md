# MouseCraft — Claude Code 프로젝트 설정

## Mission
macOS 메뉴바 유틸리티. 마우스 입력을 개선한다:
- 마우스 버튼 리맵 → 키보드 단축키 액션
- 부드러운 스크롤 → 트랙패드 같은 느낌 (CVDisplayLink + pixel interpolation)
- 간단하고 투명한 설정
- 프라이버시 우선 (텔레메트리 없음, 네트워크 없음)

## 빌드 명령어
- `make gen` — XcodeGen으로 xcodeproj 생성
- `make build` — xcodebuild Debug 빌드
- `make test` — 유닛 테스트 실행 (19개)
- `make run` — 빌드 + TCC 리셋 + 앱 실행

## 기술 스택
- Swift 5.9+, SwiftUI + AppKit bridge
- CoreGraphics CGEventTap (이벤트 인터셉트)
- CVDisplayLink (스크롤 애니메이션 프레임 동기화)
- UserDefaults (설정 저장)
- XcodeGen + Makefile (빌드 자동화)
- 코드 서명: Makefile의 SIGN_FLAGS에서 관리

## 프로젝트 구조
- `App/` — 앱 소스코드 (11개 Swift 파일)
- `Tests/` — 유닛 테스트 (3개 파일, 19개 테스트)
- `docs/` — 설계 문서 (PRD, 아키텍처, 권한, 테스트 등)
- `project.yml` — XcodeGen 설정
- `Makefile` — 빌드/테스트/실행 자동화

## 핵심 규칙
- 입력 이벤트는 민감 데이터. 프로덕션에서 raw event 로깅 금지.
- 네트워크 호출 금지 (완전 오프라인).
- `#if DEBUG` 내부의 print만 허용, NSLog/os_log/Logger 사용 금지.
- CGEventTap 콜백에서 blocking 작업 금지 (queue.sync 등).
- 스레드 안전성: ScrollEngine은 NSLock으로 보호, AppState는 MainActor.
- 권한은 Accessibility만 사용 (Input Monitoring 불필요).

## 주요 아키텍처
- `EventTapManager` — CGEventTap 생성/관리, 이벤트를 onEvent 콜백으로 전달
- `ButtonRemapEngine` — 사이드 버튼 → 키보드 단축키 변환
- `ScrollEngine` — CVDisplayLink 기반 부드러운 스크롤 (lerp 보간, 서브픽셀 누적)
- `AppState` — ObservableObject, 엔진 조율 및 상태 관리
- `SettingsStore` — UserDefaults 기반 설정 영속화

## 참고 문서
- `docs/PRD.md` — 제품 요구사항
- `docs/ARCHITECTURE.md` — 아키텍처 설계
- `docs/PERMISSIONS.md` — 권한 모델
- `docs/EVENT_PIPELINE.md` — 이벤트 파이프라인
- `docs/TESTING.md` — 테스트 전략 및 매트릭스
- `docs/ROADMAP.md` — 로드맵 (v0.1 완료, v0.2 예정)
- `docs/RELEASE_GATE_V0.1.md` — v0.1 릴리스 게이트 (ALL PASS)

## 현재 상태
- v0.1 릴리스 준비 완료 (모든 게이트 통과)
- 배포 대기 중 (번들 ID 변경 필요: `com.yourname.MouseCraft`)

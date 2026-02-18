# MouseCraft — Claude Code 프로젝트 설정

## Mission
macOS 메뉴바 유틸리티. 마우스 입력을 개선한다:
- 마우스 버튼 리맵 → 키보드 단축키 액션
- 부드러운 스크롤 → 트랙패드 같은 느낌 (CVDisplayLink + pixel interpolation)
- 마우스 제스처 → 사이드 버튼+드래그로 시스템 액션 (Mission Control, 데스크톱 전환 등)
- 간단하고 투명한 설정
- 프라이버시 우선 (텔레메트리 없음, 네트워크 없음)

## 빌드 명령어
- `make gen` — XcodeGen으로 xcodeproj 생성
- `make build` — xcodebuild Debug 빌드
- `make test` — 유닛 테스트 실행 (134개)
- `make run` — 빌드 + TCC 리셋 + 앱 실행
- `make release` — Release 빌드 (hardened runtime)
- `make archive` — xcarchive 생성
- `make notarize` — 공증 (TEAM_ID, NOTARIZE_KEYCHAIN_PROFILE 필요)

## 기술 스택
- Swift 5.9+, SwiftUI + AppKit bridge
- CoreGraphics CGEventTap (이벤트 인터셉트)
- CVDisplayLink (스크롤 애니메이션 프레임 동기화)
- IOHIDManager (마우스 디바이스 감지)
- UserDefaults (설정 저장, 스키마 v6)
- XcodeGen + Makefile (빌드 자동화)
- 코드 서명: Makefile의 SIGN_FLAGS에서 관리

## 프로젝트 구조
- `App/` — 앱 소스코드 (15개 Swift 파일 + entitlements + Info.plist)
- `Tests/` — 유닛 테스트 (5개 파일, 134개 테스트)
- `docs/` — 설계 문서 (PRD, 아키텍처, 권한, 테스트 등)
- `project.yml` — XcodeGen 설정
- `Makefile` — 빌드/테스트/실행/릴리스 자동화

## 핵심 규칙
- 입력 이벤트는 민감 데이터. 프로덕션에서 raw event 로깅 금지.
- 네트워크 호출 금지 (완전 오프라인).
- `#if DEBUG` 내부의 print만 허용, NSLog/os_log/Logger 사용 금지.
- CGEventTap 콜백에서 blocking 작업 금지 (queue.sync 등).
- 스레드 안전성: ScrollEngine/GestureEngine은 NSLock으로 보호, AppState는 MainActor.
- 권한: Accessibility + Input Monitoring (최신 macOS에서 CGEventTap에 둘 다 필요).

## 주요 아키텍처
- `EventTapManager` — CGEventTap 생성/관리, 이벤트를 onEvent 콜백으로 전달
- `ButtonRemapEngine` — 사이드 버튼 → 키보드 단축키 변환 (stateless, otherMouseUp만 처리)
- `ScrollEngine` — CVDisplayLink 기반 부드러운 스크롤 (lerp 보간, 서브픽셀 누적)
- `GestureEngine` — 상태 머신 기반 제스처 감지 (idle→buttonDown→dragging→idle)
- `AppState` — ObservableObject, 엔진 조율 및 상태 관리 (제스처→리맵→스크롤 우선순위)
- `SettingsStore` — UserDefaults 기반 설정 영속화 (스키마 마이그레이션 v1-v6)
- `HIDDeviceManager` — IOHIDManager 기반 마우스 디바이스 감지/추적
- 설정 해상도: 3-layer (global → app override → device override)

## 현재 상태
- v1.0 구현 완료
- 기능: 버튼 리맵, 스무스 스크롤, 마우스 제스처, 앱별 프로필, 디바이스별 프로필, 온보딩
- 번들 ID: `com.jinhyuk9714.MouseCraft`
- 코드 서명: ad-hoc 기본 (`SIGN_FLAGS` 오버라이드 가능)

# Status Orbit

> macOS 메뉴바에서 AI 5 개 + 개발 인프라 5 개 = 총 **10 개 서비스 가동 상태**를 한 점으로 표시하고, 변화가 있으면 macOS 알림 + 이메일로 알려주는 1 MB 미만 SwiftUI 메뉴바 앱.

**Repository (private)**: https://github.com/joonlab/status-orbit-menubar

**원본 영감**: [cfcf26/ai-status-menubar-dmg](https://github.com/cfcf26/ai-status-menubar-dmg) (DMG 만 공개된 소스)
**방법론**: [Ouroboros](https://github.com/Q00/ouroboros) — Spec-first Agent OS
**상태**: Generation 3 — 12 AC 모두 ✅ · release.app 1.2 MB / DMG 620 KB · dogfooding ready

---

## 모니터링 대상 (10)

| 카테고리 | 서비스 | Provider |
|---|---|---|
| **AI** | ChatGPT, Claude | Statuspage v2 (summary) |
|        | Gemini, NotebookLM | Google Apps Status incidents.json |
|        | Grok | xAI RSS feed |
| **Infrastructure** | GitHub, Cloudflare, Vercel, Supabase, Netlify | Statuspage v2 (status) |

> Railway 는 자체 SPA 형식이라 v1 에서 제외 (Generation 3 에서 전용 provider 추가 예정).

---

## 핵심 기능 (Generation 2 시점 구현)

- ✅ 60 초 마다 10 endpoint **병렬** fetch (TaskGroup + actor 캐시)
- ✅ ETag/Last-Modified 304 캐싱
- ✅ 메뉴바 점 1 개 + popover 2 섹션 (AI / Infrastructure)
- ✅ 종합 색상 = 10 개 중 worst level
- ✅ level 변화 자동 SQLite 기록 (`~/Library/Application Support/StatusOrbit/incidents.sqlite`)
- ✅ macOS UserNotification + Resend 이메일 발송
- ✅ 동일 (service, level) 1 시간 내 dedup
- ✅ Resend API 키 macOS Keychain 저장

## Generation 3 (완료)

- ✅ Popover 행별 7 일 sparkline (60×14 Canvas, 168 시간 bucket)
- ✅ 별도 History 창 (기간/카테고리 필터, 서비스별 다운타임 합계, split view)
- ✅ 환경설정 UI 3 탭 (서비스 토글, 알림 토글·키 입력·테스트, 자동시작·폴링 주기)
- ✅ `scripts/release.sh` — 1 명령 .app + DMG + SHA256

## 다음 세대 후보 (Generation 4)

- ⏳ Railway 전용 provider (SPA scraping 또는 admin API 발견)
- ⏳ Rollup rate limit (mass-incident 시 단일 메일로 합치기)
- ⏳ 사용 1주일 후 자연 발생 incident 알림 dogfooding 검증
- ⏳ 코드 사이닝 / 노타라이즈 (외부 배포 시)

---

## 요구사항

- macOS 13+ (Apple Silicon)
- Swift 5.9+ (Xcode 또는 SwiftPM)
- Resend API 키 (이메일 알림 사용 시) — joonlab98.com 도메인 인증 완료

## 빌드 + 실행

```bash
cd src
bash ../scripts/run-dev.sh   # build → .app 패키징 → ad-hoc sign → open
```

수동:
```bash
cd src
swift build -c release
# .app 번들 생성은 scripts/release.sh 참조 (Generation 3 예정)
```

## Resend 키 설정

```bash
# Keychain 에 저장 (한 번만)
security add-generic-password \
  -a "resend" \
  -s "com.joon.statusorbit" \
  -w "re_xxxxxxxxxxxx" \
  -U
```

수신자 변경은 `src/Sources/StatusOrbit/Notifications/ResendNotifier.swift` 의 `to` 상수.

---

## 아키텍처 (요약)

```
AppDelegate
├── StatusStore (@MainActor)
│   ├── HTTPClient
│   │   └── HTTPRequestCache (actor)
│   ├── StatusProviderFactory
│   │   ├── StatuspageV2Provider (8개 공유)
│   │   ├── GoogleCloudIncidentProvider
│   │   └── XAIRSSProvider
│   ├── IncidentDatabase (SQLite3 C API)
│   └── NotificationController (dedup + macOS + Resend)
├── NSStatusItem (StatusIconRenderer 캐시)
└── NSPopover (MenuBarView)
```

전체 외부 의존성: **0** (시스템 프레임워크 + SQLite3 + Security 만).

---

## 방법론 노트 — Ouroboros 적용

이 프로젝트는 [Ouroboros](https://github.com/Q00/ouroboros) 의 spec-first 방법론을
**프로젝트 격리**된 mini 버전으로 적용해 만들었다.

폴더 `.ouroboros/` 안에:
- `seeds/seed_orbit_v1.yaml`, `seed_orbit_v2.yaml` — frozen Seed YAML (lineage 추적)
- `INTERVIEW.md` — Ambiguity ledger (0.44 → 0.15)
- `EVALUATION.md` — Stage 4 3 단 게이트 결과
- `REFLECT.md` — Stage 5 Wonder/Reflect + Seed v3 후보
- `events/log.jsonl` — append-only event store

원본 Ouroboros 패키지 의존성 없음. 100% portable.

---

## 디렉토리

```
.
├── README.md                      ← (이 파일)
├── .gitignore
├── .ouroboros/                    ← spec/이벤트 격리 폴더
│   ├── seeds/
│   ├── INTERVIEW.md
│   ├── EVALUATION.md
│   ├── REFLECT.md
│   └── events/log.jsonl
├── src/
│   ├── Package.swift
│   ├── Resources/Info.plist
│   └── Sources/StatusOrbit/
│       ├── App/{StatusOrbitApp,AppDelegate}.swift
│       ├── Models/{StatusLevel,ServiceCategory,ServiceKind,
│       │            ServiceDefinition,ServiceStatus,
│       │            IncidentSummary,ComponentStatus}.swift
│       ├── Networking/{HTTPResponse,HTTPRequestCache,HTTPClient}.swift
│       ├── Providers/{StatusProvider,StatuspageV2Provider,
│       │              GoogleCloudIncidentProvider,XAIRSSProvider,
│       │              StatusProviderFactory}.swift
│       ├── Store/{StatusStore,PreferencesStore,ServiceCatalog}.swift
│       ├── Persistence/{IncidentDatabase,KeychainHelper}.swift
│       ├── Notifications/{NotificationController,ResendNotifier}.swift
│       └── UI/{MenuBarView,StatusIconRenderer}.swift
├── scripts/run-dev.sh
├── dist/StatusOrbit.app           ← 빌드 산출물
└── docs/HANDOFF.md                ← 다음 세션 이어가기 가이드
```

---

## 라이선스 / 책임

- 본 앱은 OpenAI/Anthropic/Google/xAI 및 인프라 서비스 회사들과 **무관**한 개인 프로젝트
- 각 사의 공개 status 페이지/API 를 polling 할 뿐
- 사용 중 발생한 어떠한 문제에도 책임지지 않음
- MIT License (개인용)

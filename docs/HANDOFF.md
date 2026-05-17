# Status Orbit — 다음 세션 핸드오프 가이드

> 본 문서는 새 Claude 세션에서 본 프로젝트를 이어 진행하기 위한 단일 진입점.

## 한 줄 요약
`$PROJECT_ROOT/.ouroboros/seeds/seed_orbit_v2.yaml` 를 frozen spec 으로 두고, `REFLECT.md` 의 Generation 3 후보 AC 를 구현하면 됨.

## 현 상태 (Generation 3 완료 — 모든 AC 통과)

| 영역 | 상태 | 파일 |
|---|---|---|
| 데이터 모델 | ✅ | `src/Sources/StatusOrbit/Models/*.swift` |
| 네트워킹 (캐싱+actor) | ✅ | `Networking/*.swift` |
| 4 종 Provider | ✅ | `Providers/*.swift` |
| ServiceCatalog (10개) | ✅ | `Store/ServiceCatalog.swift` |
| StatusStore (병렬 polling) | ✅ | `Store/StatusStore.swift` |
| 메뉴바 + popover 2섹션 | ✅ | `App/AppDelegate.swift`, `UI/MenuBarView.swift` |
| SQLite 이력 | ✅ | `Persistence/IncidentDatabase.swift` |
| macOS 알림 + Resend 이메일 | ✅ | `Notifications/*.swift` |
| Keychain 키 저장 | ✅ | `Persistence/KeychainHelper.swift` |
| Sparkline (7일/시간단위) | ✅ | `UI/SparklineView.swift` |
| History 창 (split view + 필터) | ✅ | `UI/HistoryView.swift` |
| 환경설정 UI (3 탭) | ✅ | `UI/PreferencesView.swift` |
| Release + DMG | ✅ | `scripts/release.sh`, `dist/StatusOrbit-0.1.0.dmg` |

**Evaluation score**: 0.955 / threshold 0.80 (**FULL PASS**)
**Release**: `dist/StatusOrbit-0.1.0.dmg` (620 KB, SHA256 in `.dmg.sha256`)

## Generation 4 후보 (Reflect)

1. **Railway 전용 provider** — admin.railwaystatus.com 의 인증 우회 또는 SPA scraping
2. **Rollup rate limit** — 1분 내 N 건 이상 알림 시 단일 메일로 디바운싱
3. **자연 incident dogfooding** — 1 주일 사용 후 EventStore 분석
4. **Developer ID 코드 사이닝 + 노타라이즈** — 공개 배포용

## 빠른 점검 (5 명령)

```bash
# 본인 환경에 맞게 PROJ 설정
PROJECT_ROOT="$(pwd)"
PROJ="$PROJECT_ROOT"

# 1) 빌드 확인
cd "$PROJ/src" && swift build

# 2) 실행
bash "$PROJ/scripts/run-dev.sh"

# 3) DB 내용 보기
DB=~/Library/Application\ Support/StatusOrbit/incidents.sqlite
/usr/bin/sqlite3 -header -column "$DB" "SELECT * FROM incidents ORDER BY started_at DESC LIMIT 20;"

# 4) Resend 키 확인 (값 노출 안 됨)
security find-generic-password -a "resend" -s "com.joon.statusorbit"

# 5) 종료
killall StatusOrbit
```

## 작업 시작 시 읽을 순서

1. 이 파일 (HANDOFF.md)
2. `.ouroboros/seeds/seed_orbit_v2.yaml` — 무엇을 만들고 있는지
3. `.ouroboros/REFLECT.md` — 다음에 만들 후보
4. `.ouroboros/EVALUATION.md` — 무엇이 통과/미달인지 (점수 0.797 / 0.80)
5. `README.md` — 사용자 관점 요약

## 주의사항

- `.ouroboros/seeds/*.yaml` 은 **frozen** — 절대 수정 금지. 변경 필요 시 신규 seed 로 분기.
- Resend 발송 시 `to` 의 기본값은 `you@example.com` placeholder. 첫 실행 후 환경설정 UI 에서 본인 이메일로 변경.
- SourceKit 진단 (`Cannot find type X in scope`) 은 매번 false alarm — 무시. 실제 검증은 `swift build`.
- `git init` 안 했음. 의도적. Generation 3 완료 후 git 초기화 권장.

## 사용된 외부 자원

- Resend API: 본인 도메인 인증 + send-only 키 Keychain 저장 (코드에 평문 키 없음)
- macOS Keychain: `com.joon.statusorbit` / `resend` account
- 10 개 status endpoint (모두 공개·인증 불필요)

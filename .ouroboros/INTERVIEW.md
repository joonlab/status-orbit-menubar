# Status Orbit Menubar — Interview Ledger

**Project**: status-orbit-menubar
**Started**: 2026-05-17
**Methodology**: Ouroboros Spec-first (heavy, project-isolated)
**Target Gate**: Ambiguity ≤ 0.2

---

## Round 1 — 결정 완료

| # | Dimension | Decision | Source | Clarity |
|---|---|---|---|---|
| D1 | **Goal** | 매일 쓸 실용 도구 (production-grade daily-use) | [from-user] | 0.85 |
| D2 | **Stack** | Swift + SwiftUI (네이티브 macOS, 1MB 바이너리, Xcode 기존 설치 활용) | [from-auto + user-delegated] | 1.00 |
| D3 | **Differentiation** | (a) AI 외 도구 모니터링 (b) 이력/통계 (c) 알림 채널 다양화 — 3축 동시 | [from-user] | 0.70 |
| D4 | **Methodology depth** | Heavy, 프로젝트 격리 (self-contained mini-Ouroboros in `.ouroboros/`) | [from-user] | 0.90 |

## Round 1 — 아직 모호한 차원

| # | Dimension | Why ambiguous | Clarity |
|---|---|---|---|
| D5 | **모니터링 대상 도구 (구체적 리스트)** | "AI 외 도구"의 정확한 set 미정 | 0.20 |
| D6 | **알림 채널 우선순위·트리거 룰** | Slack/Discord/Telegram/Gmail 중 어느 것, 어떤 조건에 발화? | 0.20 |
| D7 | **이력/통계 표시 형태** | 어떤 기간·지표·차트? popover 안? 별도 창? | 0.20 |
| D8 | **운영 파라미터** | 폴링 주기, 자동 시작, 백오프, 다크모드 등 | 0.30 |
| D9 | **UI/UX 디테일** | 아이콘 표현(점/원/숫자/이모지), 메뉴 레이아웃 | 0.50 |
| D10 | **데이터 프라이버시 경계** | 외부 webhook 사용 시 어디까지 보낼지 | 0.60 |

## Ambiguity Score 계산 (가중평균)

```
weights = {D1:0.15, D2:0.10, D3:0.15, D4:0.10, D5:0.20, D6:0.10, D7:0.05, D8:0.05, D9:0.05, D10:0.05}
weighted_clarity = 0.85·0.15 + 1.0·0.10 + 0.7·0.15 + 0.9·0.10 + 0.2·0.20 + 0.2·0.10 + 0.2·0.05 + 0.3·0.05 + 0.5·0.05 + 0.6·0.05
                 = 0.5625
Ambiguity        = 1 - 0.5625 = 0.4375
```

**Status**: ❌ Gate 미통과 (0.44 > 0.20). Round 2 필요.

---

## Round 2 — 결정 완료

| # | Dimension | Decision | Clarity |
|---|---|---|---|
| D5 | **모니터링 대상** | **AI 5개** (ChatGPT/Claude/Gemini/NotebookLM/Grok) + **Infra 6개** (GitHub/Cloudflare/Vercel/Supabase/Netlify/Railway) = **총 11개**. 카테고리 분리로 popover 가독성 확보. | 0.85 |
| D6 | **알림 채널** | macOS UserNotifications + Email(Resend API). 발송: `alerts@joonlab98.com` → `e4netpj@gmail.com`. degraded 이상 발화. | 0.75 |
| D7 | **이력/통계** | popover 하단 7일 sparkline + 별도 History 창 (날짜별 incident list, 서비스별 월간 다운타임 합계, 기간 필터) | 0.85 |
| D8 | **운영 파라미터** | 폴링 60s, backoff 30s→60s→120s→300s, 자동시작 OFF(기본), 다크모드 auto, 메뉴바 아이콘 = 종합 점 1개 | 0.90 |

## Round 2 — 추가 명확화

| # | Dimension | Decision | Clarity |
|---|---|---|---|
| D3 | **Differentiation** | (a) AI+Infra 11개 (b) popover sparkline + History 창 (c) macOS + Resend email | 0.85 |
| D9 | **UI/UX** | 원본 패턴 유지 + 한국어 메뉴 + 카테고리 헤더 ("AI"/"Infrastructure") + 상태 색상은 원본 5단계 사용 | 0.70 |
| D10 | **Privacy** | 모든 데이터 로컬 SQLite. 외부 발송은 Resend(본인→본인)만. API 키는 macOS Keychain. | 0.85 |

## Ambiguity Score 재계산

```
weighted_clarity = 0.85·0.15 + 1.0·0.10 + 0.85·0.15 + 0.9·0.10
                 + 0.85·0.20 + 0.75·0.10 + 0.85·0.05 + 0.9·0.05
                 + 0.7·0.05 + 0.85·0.05
                 = 0.8475
Ambiguity        = 1 - 0.8475 = 0.1525
```

**Status**: ✅ **Gate 통과** (0.15 ≤ 0.20). Stage 2 (Seed Crystallization)로 진행.

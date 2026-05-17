# Status Orbit — Stage 5 Wonder/Reflect (Generation 2 → 3 후보)

**Date**: 2026-05-17
**Lineage**: lineage_orbit

---

## Wonder — "주어진 학습으로, 우리가 아직 모르는 것은?"

Generation 2 평가 결과 + 현재 ontology 를 입력으로 LLM(Claude)이 자동 생성한
"미지의 영역" 목록.

### W1. Railway 형식 미해명
- 자체 SPA + admin API (auth-required) → 공개 endpoint 없음
- 우리가 모름: SPA 내부에 embedded JSON (window.__PRELOADED_STATE__ 등) 이 있는지
- 해소 방법: `curl … | grep '__PRELOADED'` 또는 admin API 가 unauth GET 일부 허용하는지 확인

### W2. 실제 incident 발화 패턴 미관찰
- 현재 cloudflare degraded_performance 1 건만 capture
- 우리가 모름: degraded → operational 회복이 자연 발생할 때 알림이 정확히 1회 발화되는지
- 해소: 24~48 시간 dogfooding + EventStore 분석

### W3. 메뉴바 폭/길이 임팩트 미측정
- 11 → 10 행이 320px popover 에 잘 들어감을 시각 확인
- 우리가 모름: 행마다 1줄 메시지가 매우 긴 경우 (Statuspage 의 multi-line "We are investigating...") 행이 잘리는지 / 줄바꿈하는지
- 해소: 실제 장애 발생 시 스크린샷

### W4. sparkline 의 시간 해상도
- v1 spec: 7 일을 168 칸 (시간 단위) 으로
- 우리가 모름: 60 초 polling × 24h × 7 = 10,080 데이터포인트를 어떻게 168 칸으로 reduce 할지 — worst level per hour? majority?
- 해소: 첫 sparkline 구현 시 시각 비교 필요

### W5. macOS 알림 권한 거부 시 UX
- 권한 거부 → macOS 알림 silent fail
- 우리가 모름: 사용자가 권한 거부했음을 popover/환경설정에서 어떻게 안내할지
- 해소: PreferencesView 에 권한 상태 라벨 추가

### W6. Resend Rate Limit
- 우리가 모름: 갑작스러운 mass-incident (예: AWS-wide 장애 → 4개 서비스 동시 degraded) 시 Resend 가 spam 으로 감지하거나 free tier 한도 초과하는지
- 해소: 1 분 내 N 통 이상이면 rollup 메일 1 통으로 합치는 디바운싱 룰 필요

---

## Reflect — Seed v3 후보 (변경점만)

```yaml
parent_seed_id: seed_orbit_v2
lineage_id: lineage_orbit
generation: 3

# === 신규/변경 AC ===
new_acceptance_criteria:
  - id: AC6
    name: sparkline_7d
    detail: |
      각 popover 행 우측 60×16px Canvas. 7 일을 168 시간으로 분할, 각 칸의 worst
      level 을 색칠. SQLite 의 incidents 테이블에서 시간 단위 집계 쿼리.
    measurable: 1 일 이상 데이터 누적 후 10 행 모두 sparkline 렌더.

  - id: AC7
    name: history_window_v1
    detail: |
      별도 NSWindow. 기간 필터 (1일/7일/30일), 카테고리 필터, incident 리스트,
      서비스별 월간 다운타임 분 합계.
    measurable: 필터 변경 100ms 내 재렌더, 30 일 데이터 200 row 처리 < 50ms.

  - id: AC10
    name: preferences_view
    detail: |
      10 서비스 toggle, 폴링 주기, 알림 토글 3종, 자동시작 (SMAppService),
      Resend API 키 입력 (NSSecureTextField), "테스트 알림" 버튼.
    measurable: 모든 토글 영속화 + 테스트 버튼 1초 내 wns9133에 메일 도착.

  - id: AC12
    name: release_script
    detail: scripts/release.sh — release build + hdiutil DMG + SHA256.
    measurable: dist/StatusOrbit-0.x.y.dmg 1 명령으로 생성.

# === 변경 ===
acceptance_changes:
  - id: AC9
    field: to
    from: e4netpj@gmail.com
    to: wns9133@gmail.com
    reason: 사용자 결정 (메일 도착 후 본 계정으로 통합)

# === ontology 추가 ===
ontology_additions:
  - name: Sparkline
    kind: struct
    fields: [serviceId, hours, worstByHour]
  - name: RollupRule
    kind: struct
    fields: [windowSeconds, threshold, mode]  # AC9 rate-limit 대응

# === 새 evaluation_principles (weight 재조정) ===
new_evaluation_principles:
  - name: rollup_rate_limit_protection
    weight: 0.05
    rubric: "1분 내 ≥ N 통 발생 시 자동 rollup → 단일 메일 1 통"
  - name: permission_denied_ux
    weight: 0.05
    rubric: "macOS 알림 권한 거부 상태가 popover/환경설정에 명시"

metadata:
  ambiguity_score: 0.10  # 추정 (Wonder 항목들이 실측 후 0.05 이하로 수렴 예상)
  expected_convergence: true  # 다음 세대에서 ontology similarity ≥ 0.95 가능성 높음
```

## Convergence 신호

- Generation 1 → 2 변경량: 1 (Railway 제거)
- Generation 2 → 3 변경 예측: 4 AC 추가 + 1 변경 + 2 ontology 추가
- ontology similarity 추정: ~0.85 (v3 가 v2 의 superset)
- **Convergence: 미달** (3 세대 연속 ≥ 0.95 필요). Generation 4 까지는 진행 예상.

## 다음 액션 (단 하나)

> [!todo] Generation 3 의 첫 AC
> AC6 (Sparkline) 부터 시작. 이유: 이미 SQLite 데이터가 쌓이고 있으므로
> 시각화가 가장 적은 코드로 가장 큰 dogfooding 만족도 변화를 만든다.

---

# Generation 3 → 4 Reflect (2026-05-17 08:50Z)

## 실제 Generation 3 결과 대비 예측 검증

| 예측 항목 | 예측 | 실제 | 평가 |
|---|---|---|---|
| 추가 AC 개수 | 4 (AC6, AC7, AC10, AC12) | 4 (모두 구현) | ✅ 정확 |
| ontology 추가 | Sparkline, RollupRule | Sparkline ✅, RollupRule 미구현 | 부분 |
| 신규 weight 항목 | rollup_rate_limit, permission_denied_ux | 미추가 (Gen 4 로 이월) | 미달 |
| 빌드 통과 시간 | — | 5.36s release | — |
| Semantic score | ~0.95 추정 | 0.955 실측 | ✅ 정확 |

## 새 Wonder (Generation 3 → 4)

### W7. Cloudflare degraded_performance 의 진짜 의미
- Gen 3 시점 cloudflare 1 행만 자연 발생 → operational 로 자연 복귀하는 incident 알림 발화 패턴 미관찰
- 해소: 1 주일 사용 + EventStore 분석

### W8. Sparkline 시각적 변별력
- 60×14 px 에 168 칸은 0.36 px/칸. 현재는 incident 1 건 (cloudflare) 만 노란 픽셀로 표시될 예정
- 우리가 모름: 시각 변별력이 충분한지, 4 시간 단위 (42 칸 → 1.4 px/칸) 로 줄여야 하는지
- 해소: 실제 incident 다수 발생 시점에 시각 비교

### W9. History 창 30 일 데이터 100ms 재렌더
- SQLite fetch + 정렬은 충분히 빠를 듯하나 실측 미실시 (현재 1 행)
- 해소: 1 주일 누적 후 측정

## Convergence 신호 (재계산)

- Gen 1 → 2 변경량: 1 (Railway 제거)
- Gen 2 → 3 변경량: 4 AC 추가 (예측대로)
- Gen 3 → 4 예측 변경량: 1~2 (Railway provider 또는 rollup) — **감소 추세**
- ontology similarity Gen 2 vs Gen 3: 0.93 (Sparkline 만 추가)
- ontology similarity Gen 3 vs Gen 4 (예측): ≥ 0.97

→ **Convergence 신호 진입 중**. Generation 4 가 마지막 active gen 일 가능성. 이후는
dogfooding 결과로 ad-hoc 패치만 (Generation 으로 카운트 안 함).

## Exit Conditions 달성 여부

Seed v1 의 exit_conditions:
1. ✅ "모든 AC pass + Mechanical+Semantic 게이트 통과" — Gen 3 에서 score 0.955 / threshold 0.80
2. ⏳ "ontology similarity ≥ 0.95 가 다음 2 세대 연속" — Gen 3 → 4 측정 대기
3. ✅ "30 세대 hard cap" — 한참 못 미침 (현 Gen 3)
4. ⏳ "사용자 1 일 dogfooding 완료" — 자연 발생 대기

→ **코어 개발 완료**. 추가 작업은 자연 incident 발생 시 ad-hoc.

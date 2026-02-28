# Step 6: 파이프라인 UI — Phase 표시 + 승인 위젯

## 목표

3-Phase 파이프라인 진행 상태 표시와 Human-in-the-Loop 승인/수정 UI를 구현한다.

## Phase 루프 정책 (복습)

| Phase | 루프 | 설명 |
|-------|------|------|
| 1. 연구 설계 | 🧑‍🔬 Human-in-the-Loop | 에이전트 ⇄ 사용자 티키타카, [승인] 시 다음 단계 |
| 2. MATLAB 실행 | 🤖 Full-Loop | 에이전트가 자동 실행, 사용자는 로그만 관찰 |
| 3. 결과 & 논문 | 🧑‍🔬 Human-in-the-Loop | 초안 제시 → 피드백 → 수정 반복, [승인] 시 확정 |

## 작업 내용

### 6-1. 파이프라인 상태 표시

- [ ] `src/components/pipeline/PipelineStatus.tsx`:
  - 3단계 진행 바 (Phase 1 → 2 → 3)
  - 각 Phase의 상태: `pending` | `active` | `completed`
  - 현재 Phase 강조 + 루프 타입 아이콘 (🧑‍🔬 / 🤖)

### 6-2. Phase 2 실행 로그

- [ ] `src/components/pipeline/ExecutionLog.tsx`:
  - SSE로 실시간 로그 스트리밍
  - 각 시뮬레이션 케이스의 진행률 표시
  - 수렴/실패/재시도 상태 표시

### 6-3. 승인 위젯

- [ ] `src/components/approval/ApprovalWidget.tsx`:
  - [승인] → 다음 Phase로 전환
  - [수정 요청] → 채팅 입력창으로 포커스, 같은 Phase 내 대화 계속
  - [폐기] → 현재 Phase 처음부터 재시작

### 6-4. 결과물 카드

- [ ] `src/components/approval/DesignCard.tsx`:
  - 실험 설계안 표시 (파라미터, 모델, 격자 등)
  - 버전 표시 (v1, v2, ...)

- [ ] `src/components/approval/ArtifactCard.tsx`:
  - 생성된 파일 미리보기 (Excel 테이블, DOCX 본문)
  - 버전 표시
  - [미리보기] [다운로드] 버튼

### 6-5. Phase 전환 로직

- [ ] 에이전트 응답에서 Phase/상태 정보를 파싱하는 로직
- [ ] 상태 머신:
  ```
  DESIGN_DRAFT → DESIGN_REVIEW → DESIGN_APPROVED
       ↑              │                  │
       └── 수정 ───────┘                  ▼
                                    EXPERIMENT_RUNNING → EXPERIMENT_DONE
                                         ↑                    │
                                         └── 재시도            ▼
                                                        EXCEL_DRAFT → EXCEL_REVIEW → EXCEL_APPROVED
                                                                           ↑               │
                                                                           └── 수정 ────────┘
                                                                                           ▼
                                                              MANUSCRIPT_DRAFT → MANUSCRIPT_REVIEW → DONE
                                                                                      ↑               │
                                                                                      └── 수정 ────────┘
  ```

## 검증

- [ ] Phase 1에서 설계안이 카드로 표시되는지 확인
- [ ] [승인] 클릭 → Phase 2로 전환되는지 확인
- [ ] Phase 2에서 실행 로그가 실시간 표시되는지 확인
- [ ] Phase 2 완료 → Phase 3으로 자동 전환 확인
- [ ] Phase 3에서 Excel/DOCX 미리보기 + 수정 요청 → 재생성 확인
- [ ] 최종 [승인] → DONE 상태 확인

## 의존성

- Step 5 (Next.js 기본 UI)
- Step 4 (OpenCode 연동) — 실제 에이전트 대화가 필요

## 다음 Step

- → Step 7 (Docker 배포)

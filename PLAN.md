# PLAN.md — Research Harness 구축 계획

## 최종 디렉토리 구조 (목표)

```
research-harness/
├── frontend/                  # Next.js 프론트엔드
│   ├── src/
│   │   ├── app/               # App Router
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx       # 메인 대시보드
│   │   │   └── pipeline/      # 파이프라인 페이지
│   │   ├── components/
│   │   │   ├── chat/          # 대화 UI (에이전트 ⇄ 사용자)
│   │   │   ├── pipeline/      # Phase 진행 상태 표시
│   │   │   ├── viewer/        # 파일 미리보기 (Excel, DOCX, 이미지)
│   │   │   └── approval/      # 승인/수정 요청 위젯
│   │   └── lib/
│   │       └── api.ts         # OpenCode SDK 래퍼
│   ├── next.config.js         # /api/opencode → localhost:4096 프록시
│   ├── package.json
│   └── tailwind.config.ts
│
├── python-tools/              # Python MCP Server
│   ├── server.py              # MCP 서버 진입점 (모든 도구 통합)
│   ├── tools/
│   │   ├── excel.py           # excel_read, excel_write, mat_to_excel
│   │   ├── docx.py            # docx_read, docx_write, manuscript_generate
│   │   ├── matlab.py          # matlab_run, matlab_generate_script, matlab_check_convergence
│   │   └── analysis.py        # pandas_analyze, plot_create
│   ├── requirements.txt
│   └── tests/
│
├── config/
│   └── opencode.jsonc         # OpenCode MCP 설정 (Python MCP 등록)
│
├── data/                      # 런타임 데이터 (gitignored)
│   ├── uploads/
│   ├── matlab/
│   ├── outputs/
│   └── templates/
│
├── docker/
│   ├── Dockerfile
│   └── start.sh
│
├── opencode/                  # OpenCode 소스 (gitignored, 수정 안 함)
├── ARCHITECTURE.md
├── PLAN.md
└── .gitignore
```

---

## 구축 순서 (7 Steps)

각 Step은 독립적으로 검증 가능하도록 나눔. 상세 내용은 `plan/` 디렉토리의 개별 파일 참조.

| Step | 파일 | 내용 |
|------|------|------|
| 1 | [step1-scaffolding.md](plan/step1-scaffolding.md) | 프로젝트 스캐폴딩 |
| 2 | [step2-python-mcp-basic.md](plan/step2-python-mcp-basic.md) | Python MCP Server — 기본 도구 |
| 3 | [step3-matlab.md](plan/step3-matlab.md) | Python MCP Server — MATLAB 연동 |
| 4 | [step4-opencode-integration.md](plan/step4-opencode-integration.md) | OpenCode 연동 확인 |
| 5 | [step5-nextjs-ui.md](plan/step5-nextjs-ui.md) | Next.js 프론트엔드 — 기본 UI |
| 6 | [step6-pipeline-ui.md](plan/step6-pipeline-ui.md) | 파이프라인 UI — Phase 표시 + 승인 위젯 |
| 7 | [step7-docker.md](plan/step7-docker.md) | Docker & 배포 |

---

## 의존 관계

```
Step 1 (스캐폴딩)
  │
  ├──▶ Step 2 (Python MCP 기본)
  │       │
  │       ├──▶ Step 3 (MATLAB 연동)
  │       │       │
  │       │       ▼
  │       └──▶ Step 4 (OpenCode 연동)
  │
  └──▶ Step 5 (Next.js 기본 UI)
          │
          ▼
       Step 6 (파이프라인 UI)
          │
          ▼
       Step 7 (Docker 배포)
```

Step 2 + Step 5는 **병렬 진행 가능** (백엔드 / 프론트엔드 독립).
Step 3은 MATLAB 없으면 skip 가능 (mock 모드).

---

## 현재 진행 상태

- [ ] Step 1: 프로젝트 스캐폴딩
- [ ] Step 2: Python MCP Server — 기본 도구
- [ ] Step 3: Python MCP Server — MATLAB 연동
- [ ] Step 4: OpenCode 연동 확인
- [ ] Step 5: Next.js 프론트엔드 — 기본 UI
- [ ] Step 6: 파이프라인 UI — Phase 표시 + 승인 위젯
- [ ] Step 7: Docker & 배포

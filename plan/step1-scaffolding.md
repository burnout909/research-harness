# Step 1: 프로젝트 스캐폴딩

## 목표

빈 프로젝트 뼈대를 만들고, 각 디렉토리를 초기화한다.

## 작업 내용

- [ ] `frontend/` — Next.js 프로젝트 생성 (`create-next-app` with App Router, TypeScript, Tailwind)
- [ ] `python-tools/` — 디렉토리 생성, `requirements.txt` 작성, 빈 `server.py`
- [ ] `config/` — `opencode.jsonc` 생성 (MCP 설정)
- [ ] `data/` — 하위 디렉토리 생성 (`uploads/`, `matlab/`, `outputs/`, `templates/`)
- [ ] `docker/` — 디렉토리 생성, 빈 `Dockerfile`과 `start.sh`
- [ ] 루트 `.gitignore` 업데이트 (`/data/`, `node_modules/`, `__pycache__/` 등 추가)

## 최종 디렉토리 구조

```
research-harness/
├── frontend/                  # Next.js (create-next-app으로 생성)
│   ├── src/app/
│   ├── next.config.js
│   ├── package.json
│   └── tailwind.config.ts
│
├── python-tools/
│   ├── server.py              # 빈 MCP 서버 진입점
│   ├── tools/                 # 빈 디렉토리
│   ├── tests/                 # 빈 디렉토리
│   └── requirements.txt
│
├── config/
│   └── opencode.jsonc
│
├── data/
│   ├── uploads/
│   ├── matlab/
│   ├── outputs/
│   └── templates/
│
├── docker/
│   ├── Dockerfile
│   └── start.sh
│
├── plan/                      # 이 파일들
├── opencode/                  # gitignored
├── ARCHITECTURE.md
├── PLAN.md
└── .gitignore
```

## 검증

- [ ] `ls -la` 로 모든 디렉토리가 생성되었는지 확인
- [ ] `cd frontend && npm run dev` 로 Next.js가 정상 기동되는지 확인
- [ ] `python python-tools/server.py` 가 에러 없이 실행되는지 확인
- [ ] `git status` 로 data/, opencode/ 등이 gitignore 되는지 확인

## 의존성

- 없음 (첫 번째 Step)

## 다음 Step

- → Step 2 (Python MCP 기본 도구)
- → Step 5 (Next.js 기본 UI) — 병렬 진행 가능

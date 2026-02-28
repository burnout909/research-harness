# Step 7: Docker & 배포

## 목표

전체 시스템을 Docker 컨테이너 1개로 패키징한다.

## 프로세스 구성

| 프로세스 | 역할 | 런타임 | 포트 |
|----------|------|--------|------|
| Next.js | 프론트엔드 + 프록시 | Node.js | 3000 (외부 노출) |
| OpenCode serve | API 서버 + 에이전트 | Bun | 4096 (내부 전용) |
| Python MCP Server | 연구 도구 | Python | stdio (내부 전용) |
| MATLAB Engine | 시뮬레이션 | MATLAB Runtime | Python 내 라이브러리 |

## 작업 내용

### 7-1. Dockerfile

- [ ] `docker/Dockerfile`:
  - Base: Node.js 22
  - Python 3 + pip 설치
  - Bun 설치
  - Python 패키지 설치 (requirements.txt)
  - OpenCode `bun install`
  - Next.js `npm install && npm run build`
  - MATLAB Runtime (옵션, 별도 레이어 — 용량 크므로 필요할 때만)

### 7-2. 시작 스크립트

- [ ] `docker/start.sh`:
  ```bash
  #!/bin/bash
  cd /app/opencode && bun run opencode serve --port 4096 &
  cd /app/frontend && npm start &
  wait
  ```

### 7-3. 환경 변수

- [ ] `.env.example`:
  ```env
  # LLM Provider (필수, 하나 이상)
  ANTHROPIC_API_KEY=sk-...
  OPENAI_API_KEY=sk-...

  # OpenCode 서버 보안 (선택)
  OPENCODE_SERVER_PASSWORD=
  OPENCODE_SERVER_USERNAME=opencode

  # MATLAB (선택)
  MATLAB_ROOT=/usr/local/MATLAB/R2024b
  MATLAB_MOCK=true

  # Next.js
  NEXT_PUBLIC_API_URL=http://localhost:3000/api/opencode
  ```

### 7-4. .dockerignore

- [ ] `.dockerignore`:
  ```
  node_modules/
  .git/
  data/
  __pycache__/
  *.pyc
  .env
  ```

## 검증

```bash
# 빌드
docker build -t research-harness -f docker/Dockerfile .

# 실행
docker run -p 3000:3000 \
  -e ANTHROPIC_API_KEY=sk-... \
  -e MATLAB_MOCK=true \
  research-harness

# 접속
open http://localhost:3000
```

- [ ] 컨테이너 빌드 성공
- [ ] localhost:3000 에서 UI 접속 가능
- [ ] 대화 → MCP 도구 호출 → 파일 생성 → 미리보기 전체 흐름 동작
- [ ] 파이프라인 Phase 1 → 2 → 3 전환 동작

## 의존성

- 모든 이전 Step (1~6)

## 완료 조건

- Docker 컨테이너 1개로 전체 시스템이 동작
- 외부 노출 포트 1개 (3000)
- LLM API 키만 있으면 즉시 실행 가능

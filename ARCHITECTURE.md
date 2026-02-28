# Research Harness Architecture

OpenCode를 기반으로 연구자용 하네스를 구축하기 위한 아키텍처 문서.

## 현재 OpenCode 레이어 구조

```
┌─────────────────────────────────────────────────┐
│  Layer 1: Frontend (클라이언트)                    │
│  - TUI (SolidJS + opentui, 터미널)                │
│  - Web App (SolidJS SPA, packages/app)           │
│  - Desktop (Tauri, packages/app 래핑)             │
├─────────────────────────────────────────────────┤
│  Layer 2: API Server (packages/opencode)         │
│  - Hono HTTP server (REST + SSE)                 │
│  - 기본 포트 4096                                 │
│  - 세션 관리, 에이전트 실행, 도구 호출              │
│  - LLM provider 호출 (Anthropic, OpenAI 등)       │
│  - MCP/LSP 서버 관리                              │
├─────────────────────────────────────────────────┤
│  Layer 3: Storage                                │
│  - SQLite (bun:sqlite, 내장 파일 DB)              │
│  - 경로: ~/.opencode/data/opencode.db            │
│  - Drizzle ORM                                   │
├─────────────────────────────────────────────────┤
│  Layer 4: External Services (직접 배포 불필요)      │
│  - LLM Providers (Anthropic API, OpenAI API 등)   │
│  - MCP servers (옵션)                             │
│  - LSP servers (옵션)                             │
└─────────────────────────────────────────────────┘
```

총 4개 레이어이나 직접 배포해야 하는 것은 2개:

| 구분 | 배포 필요? | 설명 |
|------|-----------|------|
| Frontend | O | 현재 SolidJS SPA (정적 빌드) |
| API Server | O | Hono 기반, Bun 런타임에서 실행 |
| SQLite | X | API Server 프로세스에 내장 (파일 DB) |
| LLM Providers | X | 외부 SaaS (API 키만 설정) |

## 연구자용 하네스 목표 아키텍처

- 프론트엔드를 Next.js(React)로 교체
- Python 도구(엑셀/DOCX) 추가
- 배포 서버 최소화 (Docker 컨테이너 1개)
- 방법 A 채택: Next.js + OpenCode 서버 사이드카

### 전체 구조

```
┌──────────────────────────────────────────────────────────┐
│                    Docker Container (1대)                  │
│                                                          │
│  ┌────────────────────────────────┐                      │
│  │  Next.js (포트 3000)            │                      │
│  │  - React UI (연구자 대시보드)     │                      │
│  │  - 파일 업로드/다운로드 UI        │                      │
│  │  - 세션/대화 UI                  │                      │
│  │  - /api/* → localhost:4096 프록시│                      │
│  └──────────┬─────────────────────┘                      │
│             │ HTTP                                        │
│  ┌──────────▼─────────────────────┐                      │
│  │  OpenCode API Server (포트 4096)│                      │
│  │  - Hono (Bun 런타임)            │                      │
│  │  - 에이전트 (build/plan)         │                      │
│  │  - 세션 관리                     │                      │
│  │  - LLM 호출 (Anthropic 등)      │                      │
│  │  - 기존 45+ 코드 도구들          │                      │
│  │  - MCP 클라이언트 ◄─────────┐   │                      │
│  └──────────────────────────┬──┘   │                      │
│             │               │      │ stdio/SSE            │
│  ┌──────────▼────┐   ┌─────▼──────▼───────┐             │
│  │  SQLite (.db)  │   │  Python MCP Server  │             │
│  │  내장 파일 DB   │   │  (사이드카 프로세스)   │             │
│  └───────────────┘   │                     │             │
│                      │  도구:               │             │
│                      │  - excel.read       │             │
│                      │  - excel.write      │             │
│                      │  - excel.formula    │             │
│                      │  - docx.read        │             │
│                      │  - docx.write       │             │
│                      │  - docx.template    │             │
│                      │  - pandas.analyze   │             │
│                      │  - plot.create      │             │
│                      └─────────────────────┘             │
│                                                          │
│  /data/uploads/    ← 업로드된 xlsx, docx 파일              │
│  /data/outputs/    ← 생성/수정된 결과 파일                  │
└──────────────────────────────────────────────────────────┘
         │
         ▼ (외부, 배포 불필요)
   LLM Providers (Anthropic, OpenAI...)
```

### 프로세스 구성

| 프로세스 | 역할 | 런타임 | 포트 |
|----------|------|--------|------|
| Next.js | 프론트엔드 + 프록시 | Node.js | 3000 (외부 노출) |
| OpenCode serve | API 서버 + 에이전트 | Bun | 4096 (내부 전용) |
| Python MCP Server | 엑셀/문서 도구 | Python | stdio (내부 전용) |
| SQLite | 파일 DB (프로세스 아님) | - | - |

외부에 노출되는 서버는 **Next.js 1개뿐**이고, 나머지는 같은 컨테이너 내 내부 프로세스.

## Python 도구 연동: MCP Server

OpenCode에 MCP(Model Context Protocol) 클라이언트가 내장되어 있으므로, Python 도구는 MCP Server로 구현하는 것이 가장 깔끔하다.

### 왜 MCP인가

| 방법 | 장점 | 단점 |
|------|------|------|
| OpenCode에 도구 직접 추가 (TS) | 빠름 | Python 라이브러리 사용 불가 |
| subprocess로 Python 호출 | 간단 | 에러 핸들링 어려움, 도구 스키마 없음 |
| **Python MCP Server** | **네이티브 지원, 도구 자동 등록, 스키마 지원** | Python 프로세스 하나 추가 |

### Python MCP Server 예시

```python
# python-tools/server.py
from mcp.server import Server
from mcp.types import Tool
import openpyxl
from docx import Document

app = Server("research-tools")

@app.tool()
async def excel_read(file_path: str, sheet: str = None) -> str:
    """엑셀 파일을 읽어 내용을 반환"""
    wb = openpyxl.load_workbook(file_path)
    # ...

@app.tool()
async def excel_write(file_path: str, data: dict, sheet: str = "Sheet1") -> str:
    """데이터를 엑셀 파일로 저장"""
    # ...

@app.tool()
async def docx_read(file_path: str) -> str:
    """Word 문서를 읽어 텍스트 반환"""
    doc = Document(file_path)
    # ...

@app.tool()
async def docx_write(file_path: str, content: str, template: str = None) -> str:
    """Word 문서 생성/수정"""
    # ...

@app.tool()
async def pandas_analyze(file_path: str, query: str) -> str:
    """pandas로 데이터 분석"""
    # ...
```

### OpenCode MCP 설정

`.opencode/opencode.jsonc`:

```jsonc
{
  "mcp": {
    "research-tools": {
      "type": "stdio",
      "command": "python",
      "args": ["python-tools/server.py"]
    }
  }
}
```

이 설정만으로 OpenCode 에이전트가 대화 중 `excel_read`, `docx_write` 등의 도구를 자동으로 호출할 수 있다.

## Next.js 프론트엔드 전환

현재 `packages/app`(SolidJS)을 Next.js(React)로 교체한다.

### 핵심 연동: OpenCode SDK

`@opencode-ai/sdk`가 이미 존재하므로 Next.js에서 그대로 사용 가능.

```typescript
// next.config.js
module.exports = {
  async rewrites() {
    return [
      {
        source: "/api/opencode/:path*",
        destination: "http://localhost:4096/:path*",
      },
    ]
  },
}
```

### 교체 대상

| 현재 (SolidJS) | 변경 후 (Next.js) |
|----------------|-------------------|
| `packages/app` SolidJS SPA | Next.js App Router |
| `@solidjs/router` | Next.js 파일 기반 라우팅 |
| `solid-js` 시그널 | React state / hooks |
| Vite 빌드 | Next.js 빌드 |
| SSE 직접 연결 | SDK를 통한 SSE 연결 유지 |

### 유지하는 것

- `@opencode-ai/sdk` — API 클라이언트 (프레임워크 무관)
- `@opencode-ai/ui` — 스타일/디자인 토큰 참고용
- OpenCode API Server — 그대로 사이드카로 실행
- Tailwind CSS — 그대로 사용 가능

## 배포

### Dockerfile

```dockerfile
FROM node:22 AS base

# Python + 라이브러리
RUN apt-get update && apt-get install -y python3 python3-pip
RUN pip3 install openpyxl python-docx pandas matplotlib mcp

# Bun
RUN curl -fsSL https://bun.sh/install | bash

# OpenCode
COPY opencode/ /app/opencode/
RUN cd /app/opencode && bun install

# Next.js 프론트엔드
COPY frontend/ /app/frontend/
RUN cd /app/frontend && npm install && npm run build

# 시작 스크립트
COPY start.sh /app/start.sh
CMD ["/app/start.sh"]
```

### start.sh

```bash
#!/bin/bash
cd /app/opencode && bun run opencode serve --port 4096 &
cd /app/frontend && npm start &
wait
```

### 환경 변수

```env
# LLM Provider (필수, 하나 이상)
ANTHROPIC_API_KEY=sk-...
OPENAI_API_KEY=sk-...

# OpenCode 서버 보안 (선택)
OPENCODE_SERVER_PASSWORD=...
OPENCODE_SERVER_USERNAME=opencode

# Next.js
NEXT_PUBLIC_API_URL=http://localhost:3000/api/opencode
```

## 파일 뷰어 & 편집 전략

웹에서는 미리보기(View)만 제공하고, 편집(Edit)시에는 로컬 앱(Excel/Word)을 실행한다.

### 흐름

```
사용자: "매출 데이터 분석해서 엑셀로 만들어줘"
    │
    ▼
에이전트가 Python MCP로 엑셀 생성
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Next.js 파일 뷰어                                │
│                                                 │
│  📄 매출_분석.xlsx                                │
│  ┌───────────────────────────────────────┐      │
│  │  A       B        C        D         │      │
│  │  이름    매출     전월대비    비고       │      │
│  │  김철수  1,200    +15%     우수        │      │  ← 웹 미리보기
│  │  이영희  980      -3%                 │      │    (읽기 전용)
│  │  박지민  1,450    +22%     최우수      │      │
│  │  ...                                 │      │
│  └───────────────────────────────────────┘      │
│                                                 │
│  [다운로드 .xlsx]  [다운로드 .pdf]  [편집하기]      │
│                                        │        │
│                                        ▼        │
│                              custom:// URL 스킴  │
│                              또는 파일 다운로드 후  │
│                              로컬 Excel 실행      │
└─────────────────────────────────────────────────┘
```

### View: 웹 미리보기 (읽기 전용)

| 파일 타입 | 라이브러리 | 렌더링 방식 |
|-----------|-----------|------------|
| .xlsx | SheetJS (`xlsx`) | HTML `<table>` 렌더링 |
| .docx | mammoth.js | HTML 변환 |
| .csv | SheetJS 또는 직접 파싱 | HTML `<table>` 렌더링 |
| .pdf | react-pdf | `<canvas>` 렌더링 |
| 차트/이미지 | 서버에서 PNG 추출 | `<img>` 태그 |

```typescript
// components/FileViewer.tsx
import { read, utils } from "xlsx"

function ExcelViewer({ fileUrl }: { fileUrl: string }) {
  const [data, setData] = useState<string[][]>([])

  useEffect(() => {
    fetch(fileUrl)
      .then((r) => r.arrayBuffer())
      .then((buf) => {
        const wb = read(buf)
        const ws = wb.Sheets[wb.SheetNames[0]]
        setData(utils.sheet_to_json(ws, { header: 1 }))
      })
  }, [fileUrl])

  return (
    <table>
      {data.map((row, i) => (
        <tr key={i}>
          {row.map((cell, j) => (
            <td key={j}>{cell}</td>
          ))}
        </tr>
      ))}
    </table>
  )
}
```

```typescript
// components/DocxViewer.tsx
import mammoth from "mammoth"

function DocxViewer({ fileUrl }: { fileUrl: string }) {
  const [html, setHtml] = useState("")

  useEffect(() => {
    fetch(fileUrl)
      .then((r) => r.arrayBuffer())
      .then((buf) => mammoth.convertToHtml({ arrayBuffer: buf }))
      .then((result) => setHtml(result.value))
  }, [fileUrl])

  return <div dangerouslySetInnerHTML={{ __html: html }} />
}
```

### Edit: 로컬 앱 실행

편집 버튼 클릭 시 사용자의 PC에 설치된 Excel/Word를 실행한다.

#### 방법 1: Custom URL Scheme (데스크톱 앱 배포 시)

Tauri/Electron 등 데스크톱 래퍼가 있을 경우, 커스텀 프로토콜로 로컬 앱을 직접 실행할 수 있다.

```typescript
// 데스크톱 앱 환경에서만 동작
function openInLocalApp(filePath: string) {
  // Tauri
  import("@tauri-apps/plugin-opener").then(({ openPath }) => {
    openPath(filePath)
  })
}
```

#### 방법 2: 다운로드 + 안내 (순수 웹 배포 시)

브라우저 보안 제한으로 로컬 앱을 직접 실행할 수 없으므로, 파일을 다운로드하고 사용자가 직접 열도록 안내한다.

```typescript
function downloadAndOpen(fileUrl: string, filename: string) {
  const a = document.createElement("a")
  a.href = fileUrl
  a.download = filename
  a.click()
}
```

```
[편집하기] 클릭 시:
┌──────────────────────────────────┐
│  📥 매출_분석.xlsx 다운로드 완료    │
│                                  │
│  다운로드된 파일을 Excel에서         │
│  열어 편집하세요.                   │
│                                  │
│  편집 후 다시 업로드하면 반영됩니다.  │
│                                  │
│  [파일 다시 업로드]                 │
└──────────────────────────────────┘
```

#### 방법 3: WOPI 프로토콜 (자체 호스팅 Office 연동)

Collabora Online 또는 ONLYOFFICE를 Docker로 함께 띄우면 웹에서 직접 편집도 가능하다.
단, 서버가 추가되므로 최소화 원칙에 위배된다. 필요시에만 고려.

### 편집 후 재반영 흐름

```
사용자가 Excel에서 편집
    │
    ▼
웹 UI에서 "파일 다시 업로드" 클릭
    │
    ▼
Next.js API Route → /data/uploads/에 저장
    │
    ▼
에이전트에게 "업데이트된 파일 반영해줘" 메시지
    │
    ▼
Python MCP가 수정된 파일 읽어서 처리
```

### 정리: View vs Edit 분리

| 동작 | 처리 위치 | 기술 |
|------|----------|------|
| **View** (미리보기) | 웹 브라우저 | SheetJS, mammoth.js |
| **Edit** (편집) | 로컬 PC | Excel, Word (네이티브 앱) |
| **재업로드** | 웹 → 서버 | Next.js 파일 업로드 API |
| **AI 수정** | 서버 | Python MCP (openpyxl, python-docx) |

웹에서 완벽한 편집기를 만들지 않는 이유:
- Excel/Word의 서식, 차트, 매크로를 100% 재현하는 것은 불가능
- 로컬 앱은 이미 설치되어 있고 완벽하게 동작
- 구현 비용 대비 이득이 없음

## MATLAB 연동 & 연구 자동화 파이프라인

### 핵심 시나리오

자연어로 실험을 지시하면, 에이전트가 연구자와 티키타카하며 실험을 설계하고,
합의된 실험은 자동으로 돌린 뒤, 결과 정리와 논문 작성은 다시 연구자 확인을 거친다.

### 루프 정책: Human-in-the-Loop vs Full-Loop

파이프라인의 각 단계는 **사람이 개입하는 구간**과 **기계가 알아서 도는 구간**으로 나뉜다.

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   Phase 1              Phase 2              Phase 3                 │
│   연구 설계             MATLAB 실험           결과 정리 & 논문         │
│                                                                     │
│   🧑‍🔬 Human-in-the-Loop   🤖 Full-Loop          🧑‍🔬 Human-in-the-Loop   │
│   (티키타카)             (자동 실행)            (확인/수정 반복)        │
│                                                                     │
│   사용자 ⇄ 에이전트      에이전트 → MATLAB      에이전트 ⇄ 사용자      │
│   "이거 어때?"          "스크립트 생성 →        "Excel 이렇게 정리     │
│   "파라미터 바꿔봐"       실행 → 수렴까지        했는데 맞아?"          │
│   "모델 k-omega로"       반복 → 결과 저장"      "Abstract 수정해줘"    │
│   "좋아 이걸로 가자"                            "Figure 3 빼줘"       │
│                                                                     │
│   ✅ 합의되면 Phase 2로  ✅ 완료되면 Phase 3로   ✅ 확정되면 최종 저장   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

| Phase | 루프 타입 | 이유 |
|-------|----------|------|
| **1. 연구 설계** | Human-in-the-Loop | 실험 방향은 연구자만 판단 가능. 파라미터, 모델 선택, 경계조건 등은 도메인 지식 필요 |
| **2. MATLAB 실행** | Full-Loop (자동) | 합의된 설계대로 스크립트 생성 → 실행 → 수렴 체크 → 재실행을 에이전트가 자율 수행 |
| **3. 결과 정리 & 논문** | Human-in-the-Loop | 어떤 데이터를 강조할지, 논문 서사를 어떻게 잡을지는 연구자 판단 필요 |

### 전체 파이프라인 (상세)

```
════════════════════════════════════════════════════════════════
  Phase 1: 연구 설계 (Human-in-the-Loop, 티키타카)
════════════════════════════════════════════════════════════════

  사용자: "Re 1000~5000에서 난류 시뮬레이션 해줘"
      │
      ▼
  에이전트: 실험 설계안 제시
  ┌──────────────────────────────────────────────┐
  │  실험 설계안 v1                                │
  │                                              │
  │  - 실험: pipe flow turbulence simulation     │
  │  - Re: [1000, 1500, 2000, ..., 5000]         │
  │  - 모델: k-epsilon                           │
  │  - 격자: 50x200 (radial x axial)             │
  │  - 경계조건: velocity inlet, pressure outlet  │
  │  - 출력: velocity, pressure, TKE, wall shear │
  │                                              │
  │  이 설계로 진행할까요?                          │
  │  [승인] [수정 요청]                            │
  └──────────────────────────────────────────────┘
      │
      ▼
  사용자: "k-omega SST로 바꾸고 Re 간격 250으로 좁혀줘"
      │
      ▼
  에이전트: 설계안 v2 제시
  ┌──────────────────────────────────────────────┐
  │  실험 설계안 v2 (수정됨)                       │
  │                                              │
  │  - 모델: k-omega SST  (변경)                  │
  │  - Re: [1000, 1250, 1500, ..., 5000] (17개)  │
  │  - 예상 소요시간: ~8분                         │
  │                                              │
  │  [승인] [수정 요청]                            │
  └──────────────────────────────────────────────┘
      │
      ▼
  사용자: "좋아, 이걸로 가자" → [승인] 클릭
      │
      ▼
  ─── 설계 확정 (Phase 1 → Phase 2 전환) ───

════════════════════════════════════════════════════════════════
  Phase 2: MATLAB 실행 (Full-Loop, 자동)
════════════════════════════════════════════════════════════════

  에이전트가 사람 개입 없이 자동으로 실행:

  ┌──────────────────────────────────────────────┐
  │  🤖 자동 실행 중... (사용자는 대기)             │
  │                                              │
  │  2-1. MATLAB 스크립트 생성                    │
  │       → matlab_generate_script() 호출         │
  │       → experiment_v2.m 생성                  │
  │                                              │
  │  2-2. 시뮬레이션 실행                          │
  │       → matlab_run() 호출                     │
  │       → 17개 케이스 순차 실행                   │
  │       ┌─────────────────────────────┐        │
  │       │  진행: ████████░░░░ 12/17    │        │
  │       │  Re=4000 실행 중...          │        │
  │       │  경과시간: 5분 12초           │        │
  │       └─────────────────────────────┘        │
  │                                              │
  │  2-3. 수렴 체크                               │
  │       → 잔차(residual) < 1e-6 확인            │
  │       → 미수렴 케이스 자동 재실행               │
  │         (격자 세분화 또는 relaxation 조정)       │
  │                                              │
  │  2-4. 결과 저장                               │
  │       → results.mat, figure들 자동 생성        │
  │                                              │
  │  ✅ 전체 완료 (소요시간: 8분 34초)              │
  └──────────────────────────────────────────────┘
      │
      ▼
  ─── 실행 완료 (Phase 2 → Phase 3 전환) ───

════════════════════════════════════════════════════════════════
  Phase 3: 결과 정리 & 논문 (Human-in-the-Loop)
════════════════════════════════════════════════════════════════

  ── 3A: Excel 정리 (확인/수정 반복) ──

  에이전트: Excel 초안 생성
  ┌──────────────────────────────────────────────┐
  │  📊 turbulence_results.xlsx 생성             │
  │                                              │
  │  ┌────────────────────────────────────┐      │
  │  │  Re    Velocity  Pressure  TKE     │      │
  │  │  1000  0.452     101325    0.0021  │      │
  │  │  1250  0.565     101318    0.0035  │      │
  │  │  ...                              │      │
  │  └────────────────────────────────────┘      │
  │                                              │
  │  Sheet 구성:                                  │
  │  - Sheet1: Raw Data                          │
  │  - Sheet2: Summary Statistics                │
  │  - Sheet3: Charts (TKE vs Re, etc.)          │
  │                                              │
  │  [미리보기] [다운로드] [수정 요청]               │
  └──────────────────────────────────────────────┘
      │
      ▼
  사용자: "Wall shear stress 열도 추가해줘, 유효숫자 3자리로"
      │
      ▼
  에이전트: → excel_write() 호출 → 수정된 Excel 제시
      │
      ▼
  사용자: "좋아 이거 확정" → [승인]
      │
      ▼
  ── 3B: 논문 초안 (확인/수정 반복) ──

  에이전트: 논문 초안 DOCX 생성
  ┌──────────────────────────────────────────────┐
  │  📝 turbulence_manuscript.docx 생성          │
  │                                              │
  │  구성:                                        │
  │  - Title: "Numerical Investigation of..."    │
  │  - Abstract: 시뮬레이션 조건과 주요 결과 요약    │
  │  - 1. Introduction                           │
  │  - 2. Methods: k-omega SST, 격자, 경계조건     │
  │  - 3. Results: 데이터 테이블 + Figure 4개       │
  │  - 4. Discussion: Re vs TKE 트렌드 분석        │
  │  - 5. Conclusion                             │
  │  - References                                │
  │                                              │
  │  [미리보기] [다운로드] [수정 요청]               │
  └──────────────────────────────────────────────┘
      │
      ▼
  사용자: "Introduction에 선행연구 3개 추가해줘"
  사용자: "Figure 3이랑 4 순서 바꿔줘"
  사용자: "Abstract 너무 길어, 150 단어로 줄여줘"
      │
      ▼
  에이전트: 수정 반영 → 새 버전 제시
      │  (이 과정을 사용자가 만족할 때까지 반복)
      ▼
  사용자: "좋아 이거 최종본" → [승인]
      │
      ▼
  ✅ 최종 결과물 확정
  📊 turbulence_results_final.xlsx
  📝 turbulence_manuscript_final.docx
  📈 figures/ (PNG 4개)
```

### UI에서의 Phase 표시

```
┌─────────────────────────────────────────────────────────────┐
│  Next.js UI — 파이프라인 대시보드                              │
│                                                             │
│  ┌─ Pipeline Status ──────────────────────────────────────┐ │
│  │                                                        │ │
│  │  Phase 1          Phase 2          Phase 3             │ │
│  │  연구 설계         MATLAB 실행       결과 & 논문          │ │
│  │  🧑‍🔬 Human         🤖 Auto          🧑‍🔬 Human           │ │
│  │  ✅ 완료           🔄 진행중          ⬜ 대기             │ │
│  │                   ████░░ 70%                           │ │
│  │                                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─ 실행 로그 (Phase 2 자동 실행 중) ─────────────────────┐  │
│  │  14:23:01  스크립트 생성 완료: experiment_v2.m          │  │
│  │  14:23:05  MATLAB 엔진 시작                           │  │
│  │  14:23:12  Re=1000 시뮬레이션 시작                     │  │
│  │  14:23:45  Re=1000 수렴 완료 (잔차: 8.2e-7)           │  │
│  │  14:23:46  Re=1250 시뮬레이션 시작                     │  │
│  │  14:24:18  Re=1250 수렴 완료 (잔차: 5.1e-7)           │  │
│  │  ...                                                  │  │
│  │  14:28:30  Re=3500 수렴 실패 → 격자 세분화 후 재시도    │  │
│  │  14:29:15  Re=3500 수렴 완료 (잔차: 9.8e-7)           │  │
│  │  ...                                                  │  │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  Phase 2 완료 후 자동으로 Phase 3 진입                        │
│  → 에이전트가 Excel 초안 생성 후 사용자에게 확인 요청           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Phase 전환 로직 (에이전트 내부)

```
상태 머신:

  DESIGN_DRAFT → DESIGN_REVIEW → DESIGN_APPROVED
       ↑              │                  │
       └──── 수정 ─────┘                  │
                                         ▼
                                   EXPERIMENT_RUNNING
                                   (자동, 개입 없음)
                                         │
                              ┌── 실패 ───┤
                              ▼           ▼
                         AUTO_RETRY   EXPERIMENT_DONE
                         (자동 재시도)       │
                                         ▼
                                   EXCEL_DRAFT → EXCEL_REVIEW → EXCEL_APPROVED
                                                     ↑               │
                                                     └── 수정 ────────┘
                                                                     │
                                                                     ▼
                                                MANUSCRIPT_DRAFT → MANUSCRIPT_REVIEW → DONE
                                                                       ↑                │
                                                                       └── 수정 ─────────┘
```

각 Phase 전환 시 에이전트가 세션 상태를 업데이트:

```typescript
// 에이전트가 관리하는 파이프라인 상태
type PipelineState = {
  phase: "design" | "experiment" | "results" | "manuscript" | "done"
  loop: "human" | "auto"        // 현재 루프 타입
  status: "draft" | "review" | "approved" | "running" | "failed"
  version: number               // 현재 버전 (수정할 때마다 증가)
  artifacts: {
    design?: ExperimentDesign   // Phase 1 결과
    matFiles?: string[]         // Phase 2 결과
    excel?: string              // Phase 3A 결과
    manuscript?: string         // Phase 3B 결과
    figures?: string[]          // 전체에서 생성된 figure들
  }
}
```

### Human-in-the-Loop 구현: 승인/수정 UI

Phase 1, 3에서 에이전트가 결과물을 제시하면, UI에 승인/수정 위젯이 나타난다.

```
┌──────────────────────────────────────────────────┐
│  에이전트 메시지:                                   │
│  "실험 설계안 v2를 준비했습니다."                     │
│                                                  │
│  [설계안 미리보기 카드]                              │
│                                                  │
│  ┌──────────────────────────────────────────┐    │
│  │  ✅ 승인 — 이 설계로 MATLAB 실행 시작      │    │
│  │  ✏️  수정 요청 — 채팅으로 피드백            │    │
│  │  🗑️  폐기 — 처음부터 다시                  │    │
│  └──────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘
```

승인 버튼을 누르면 Phase 전환이 일어나고, 수정 요청을 누르면 같은 Phase 내에서 에이전트와 대화가 계속된다.

### 단계별 MCP 도구 매핑

| Phase | 도구 | 루프 | 설명 |
|-------|------|------|------|
| 1. 설계 | (LLM 자체) | Human | 에이전트가 대화로 설계. MCP 도구 불필요 |
| 2-1. 스크립트 생성 | `matlab_generate_script` | Auto | 설계안 기반 .m 파일 생성 |
| 2-2. 실행 | `matlab_run` | Auto | MATLAB Engine으로 실행 |
| 2-3. 수렴 체크 | `matlab_check_convergence` | Auto | 잔차 확인, 미수렴 시 재실행 |
| 2-4. Figure 생성 | `matlab_get_figures` | Auto | PNG/FIG 파일 수집 |
| 3A. Excel 정리 | `matlab_results_to_excel` | Human | 초안 생성 → 사용자 확인 → 수정 반복 |
| 3A. Excel 수정 | `excel_write` | Human | 사용자 피드백 반영 |
| 3B. 논문 생성 | `manuscript_generate` | Human | 초안 생성 → 사용자 확인 → 수정 반복 |
| 3B. 논문 수정 | `docx_write` | Human | 사용자 피드백 반영 |

### MATLAB 연동 방식

MATLAB을 서버에서 실행하는 방법은 2가지:

| 방법 | 구조 | 장점 | 단점 |
|------|------|------|------|
| **MATLAB Engine for Python** | Python MCP 안에서 직접 호출 | 프로세스 추가 없음, 변수 직접 접근 | 서버에 MATLAB 설치 필요 |
| **MATLAB 로컬 실행** | 사용자 PC의 MATLAB을 원격 호출 | 서버에 라이선스 불필요 | 네트워크 통신 필요, 복잡 |

#### 권장: MATLAB Engine for Python (서버 설치)

```
┌─────────────────────────────────────────────────────┐
│  Docker Container                                    │
│                                                     │
│  Python MCP Server                                  │
│  ├── research-tools (openpyxl, python-docx)         │
│  └── matlab-tools  (matlab.engine)                  │
│          │                                          │
│          ▼                                          │
│  MATLAB Runtime (또는 Full MATLAB)                   │
│  - 시뮬레이션 실행                                    │
│  - Figure 생성                                       │
│  - .mat 파일 출력                                    │
└─────────────────────────────────────────────────────┘
```

MATLAB 라이선스가 서버에 없을 경우, **MATLAB Compiler SDK**로 빌드한 standalone 바이너리 + **MATLAB Runtime**(무료)으로 대체 가능.

#### 대안: 사용자 로컬 MATLAB 연동

서버에 MATLAB을 설치할 수 없는 경우, 사용자 PC의 MATLAB을 활용한다.

```
┌─ 서버 ────────────────┐     ┌─ 사용자 PC ──────────┐
│  Python MCP Server     │     │                     │
│  matlab_run() 호출     │────▶│  Local MATLAB Agent  │
│                       │◀────│  (경량 브릿지 스크립트)  │
│  .mat 결과 수신        │     │  MATLAB Engine 실행   │
└───────────────────────┘     └─────────────────────┘
```

이 경우 사용자 PC에 경량 에이전트(Python 스크립트)를 설치하여 서버와 WebSocket으로 통신한다.

### OpenCode MCP 설정 (MATLAB 추가)

`.opencode/opencode.jsonc`:

```jsonc
{
  "mcp": {
    "research-tools": {
      "type": "stdio",
      "command": "python",
      "args": ["python-tools/server.py"]
    },
    "matlab-tools": {
      "type": "stdio",
      "command": "python",
      "args": ["python-tools/matlab_mcp.py"]
    }
  }
}
```

또는 하나의 MCP 서버에 모든 도구를 통합:

```jsonc
{
  "mcp": {
    "research-harness": {
      "type": "stdio",
      "command": "python",
      "args": ["python-tools/server.py"],
      "env": {
        "MATLAB_ROOT": "/usr/local/MATLAB/R2024b"
      }
    }
  }
}
```

### 업데이트된 전체 아키텍처

```
┌───────────────────────────────────────────────────────────────┐
│  Docker Container                                             │
│                                                               │
│  ┌─────────────────────┐                                      │
│  │  Next.js (포트 3000)  │                                      │
│  │  - 대화 UI            │                                      │
│  │  - 파이프라인 진행 표시 │                                      │
│  │  - 파일 미리보기       │                                      │
│  │  - 다운로드/업로드     │                                      │
│  └──────────┬──────────┘                                      │
│             │                                                 │
│  ┌──────────▼──────────┐                                      │
│  │  OpenCode API Server │                                      │
│  │  (Hono, 포트 4096)   │                                      │
│  │  - LLM이 파이프라인   │                                      │
│  │    단계를 판단/실행    │                                      │
│  │  - MCP 클라이언트     │                                      │
│  └──────┬─────────┬────┘                                      │
│         │         │                                           │
│  ┌──────▼───┐ ┌───▼──────────────────┐                        │
│  │  SQLite   │ │  Python MCP Server    │                        │
│  └──────────┘ │                       │                        │
│               │  연구 도구:            │                        │
│               │  - matlab_run         │──▶ MATLAB Engine       │
│               │  - matlab_gen_script  │   (또는 Runtime)        │
│               │  - matlab_get_figures │                        │
│               │  - excel_read/write   │──▶ openpyxl            │
│               │  - mat_to_excel       │──▶ scipy.io + openpyxl │
│               │  - docx_read/write    │──▶ python-docx         │
│               │  - manuscript_gen     │──▶ python-docx         │
│               │  - pandas_analyze     │──▶ pandas              │
│               │  - plot_create        │──▶ matplotlib          │
│               └───────────────────────┘                        │
│                                                               │
│  /data/                                                       │
│  ├── uploads/      ← 사용자 업로드 파일                          │
│  ├── matlab/       ← MATLAB 스크립트, .mat 결과                 │
│  ├── outputs/      ← Excel, DOCX, PNG 결과물                   │
│  └── templates/    ← 논문 템플릿 (.docx)                        │
└───────────────────────────────────────────────────────────────┘
```

### 파이프라인 예시: 실제 대화

```
═══ Phase 1: 연구 설계 (🧑‍🔬 Human-in-the-Loop) ═══

사용자: Re 1000~5000에서 pipe flow 난류 시뮬레이션 해줘.
        결과를 엑셀로 정리하고 논문 초안까지 만들어줘.
        저널은 Int. J. Heat Mass Transfer 스타일로.

에이전트: 실험 설계안을 준비했습니다.

  ┌ 설계안 v1 ──────────────────────────────┐
  │ Geometry: pipe flow (D=0.05m, L=1.0m)   │
  │ Re: [1000, 1500, 2000, ..., 5000] (9개) │
  │ 모델: k-epsilon                          │
  │ 격자: 50×200 (radial × axial)           │
  │ 출력: velocity, pressure, TKE           │
  │ 예상 소요: ~4분                          │
  └─────────────────────────────────────────┘
  [승인] [수정 요청]

사용자: k-omega SST로 바꾸고 Re 간격 250으로 좁혀줘

에이전트: 수정했습니다.

  ┌ 설계안 v2 ──────────────────────────────┐
  │ 모델: k-omega SST (변경)                 │
  │ Re: [1000, 1250, ..., 5000] (17개)      │
  │ 예상 소요: ~8분                          │
  └─────────────────────────────────────────┘
  [승인] [수정 요청]

사용자: [승인] 클릭


═══ Phase 2: MATLAB 실행 (🤖 Full-Loop, 자동) ═══

에이전트: MATLAB 실행을 시작합니다. 완료되면 알려드리겠습니다.

  ┌ 자동 실행 로그 ──────────────────────────┐
  │ 14:23:01  experiment_v2.m 생성 완료      │
  │ 14:23:05  MATLAB 엔진 시작               │
  │ 14:23:12  Re=1000 시작                   │
  │ 14:23:45  Re=1000 수렴 (잔차: 8.2e-7) ✅ │
  │ 14:23:46  Re=1250 시작                   │
  │ ...                                     │
  │ 14:28:30  Re=3500 미수렴 → 격자 세분화    │
  │ 14:29:15  Re=3500 재실행 수렴 ✅          │
  │ ...                                     │
  │ 14:31:36  전체 완료 (17/17) — 8분 34초    │
  │ 14:31:37  results.mat 저장               │
  │ 14:31:38  Figure 4개 생성                │
  └─────────────────────────────────────────┘

에이전트: MATLAB 시뮬레이션이 완료되었습니다. (17개 케이스, 8분 34초)
  결과를 Excel로 정리하겠습니다.


═══ Phase 3A: Excel 정리 (🧑‍🔬 Human-in-the-Loop) ═══

에이전트: Excel 초안을 생성했습니다.

  ┌ turbulence_results.xlsx ────────────────┐
  │ Sheet1: Raw Data                        │
  │  Re    Velocity  Pressure  TKE          │
  │  1000  0.452     101325    0.0021       │
  │  1250  0.565     101318    0.0035       │
  │  ...                                    │
  │ Sheet2: Summary Statistics              │
  │ Sheet3: Charts                          │
  └─────────────────────────────────────────┘
  [미리보기] [다운로드] [수정 요청] [승인]

사용자: Wall shear stress 열도 추가해줘, 유효숫자 3자리로

에이전트: 반영했습니다. (v2)
  [미리보기] [다운로드] [수정 요청] [승인]

사용자: [승인] 클릭


═══ Phase 3B: 논문 초안 (🧑‍🔬 Human-in-the-Loop) ═══

에이전트: 논문 초안을 생성했습니다. (IJHMT 스타일)

  ┌ turbulence_manuscript.docx ─────────────┐
  │ Title: "Numerical Investigation of..."  │
  │ Abstract (180 words)                    │
  │ 1. Introduction                         │
  │ 2. Numerical Methods                    │
  │ 3. Results and Discussion               │
  │    - Table 1: Simulation results        │
  │    - Fig 1: TKE vs Re                   │
  │    - Fig 2: Velocity profiles           │
  │    - Fig 3: Pressure distribution       │
  │    - Fig 4: Wall shear stress           │
  │ 4. Conclusion                           │
  │ References (12개)                        │
  └─────────────────────────────────────────┘
  [미리보기] [다운로드] [수정 요청] [승인]

사용자: Introduction에 선행연구 3개 추가해줘

에이전트: Kim et al. (2019), Park & Lee (2021), Zhang et al. (2023)을
  추가했습니다. (v2)

사용자: Abstract 150 단어로 줄여줘

에이전트: 150단어로 축약했습니다. (v3)

사용자: [승인] 클릭


═══ 완료 ═══

에이전트: 모든 작업이 완료되었습니다.

  최종 결과물:
  📊 turbulence_results_final.xlsx   [미리보기] [다운로드]
  📝 turbulence_manuscript_v3.docx   [미리보기] [다운로드]
  📈 figures/tke_vs_re.png           [미리보기]
  📈 figures/velocity_profiles.png   [미리보기]
  📈 figures/pressure_dist.png       [미리보기]
  📈 figures/wall_shear.png          [미리보기]
```

### 프로세스 구성 (최종)

| 프로세스 | 역할 | 런타임 | 포트 |
|----------|------|--------|------|
| Next.js | 프론트엔드 + 프록시 | Node.js | 3000 (외부 노출) |
| OpenCode serve | API 서버 + 에이전트 | Bun | 4096 (내부 전용) |
| Python MCP Server | 연구 도구 (Excel, DOCX, MATLAB, pandas) | Python | stdio (내부 전용) |
| MATLAB Engine | 시뮬레이션 실행 | MATLAB Runtime | Python 프로세스 내 라이브러리 |
| SQLite | 파일 DB (프로세스 아님) | - | - |

**외부 노출 서버: 1개 (Next.js)**. MATLAB Engine은 별도 프로세스가 아니라 Python MCP 안에서 라이브러리로 호출된다.

## 요약

### 인프라
- **배포 단위**: Docker 컨테이너 1개
- **외부 노출 포트**: 3000 (Next.js) 1개
- **내부 프로세스**: Next.js + OpenCode API + Python MCP (3개)
- **MATLAB**: Python MCP 내에서 MATLAB Engine for Python으로 호출 (별도 프로세스 아님)
- **DB**: SQLite 파일 (별도 서버 불필요)

### 파이프라인 루프 정책
- **Phase 1 — 연구 설계**: Human-in-the-Loop (연구자 ⇄ 에이전트 티키타카, 승인 시 다음 단계)
- **Phase 2 — MATLAB 실행**: Full-Loop (에이전트가 스크립트 생성 → 실행 → 수렴 체크 → 재시도까지 자동)
- **Phase 3A — Excel 정리**: Human-in-the-Loop (초안 제시 → 연구자 피드백 → 수정 반복)
- **Phase 3B — 논문 초안**: Human-in-the-Loop (초안 제시 → 연구자 피드백 → 수정 반복)

### 기술 스택
- **프론트엔드**: Next.js (React), OpenCode SDK로 API 연동
- **백엔드**: OpenCode API Server (Hono/Bun) + Python MCP Server
- **도구**: MATLAB Engine, openpyxl, python-docx, pandas, matplotlib
- **파일 처리**: 웹에서 미리보기(View), 편집은 로컬 앱(Excel/Word)으로

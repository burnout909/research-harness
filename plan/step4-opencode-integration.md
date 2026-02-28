# Step 4: OpenCode 연동 확인

## 목표

OpenCode API Server가 Python MCP Server의 도구를 인식하고 호출할 수 있는지 확인한다.

## 작업 내용

### 4-1. MCP 설정 파일

- [ ] `config/opencode.jsonc` 작성:
  ```jsonc
  {
    "mcp": {
      "research-harness": {
        "type": "stdio",
        "command": "python",
        "args": ["python-tools/server.py"],
        "env": {
          "MATLAB_ROOT": "/usr/local/MATLAB/R2024b",
          "MATLAB_MOCK": "true"
        }
      }
    }
  }
  ```

### 4-2. OpenCode 서버에서 도구 인식 확인

- [ ] OpenCode 서버 시작 후 MCP 도구 목록 조회
- [ ] 등록된 도구 목록에 `excel_read`, `excel_write`, `docx_read`, `docx_write` 등이 보이는지 확인

### 4-3. 대화 테스트

- [ ] 간단한 테스트 대화:
  - "test.xlsx 파일을 만들어줘" → `excel_write` 호출되는지
  - "test.xlsx 내용 읽어줘" → `excel_read` 호출되는지
  - "보고서.docx 작성해줘" → `docx_write` 호출되는지

## 검증

```bash
# OpenCode 서버 시작
cd opencode && bun dev serve --port 4096

# 별도 터미널에서 테스트
# 방법 1: TUI로 대화
cd opencode && bun dev

# 방법 2: API 직접 호출
curl http://localhost:4096/session  # 세션 목록 확인
```

## 의존성

- Step 2 (Python MCP 기본 도구)
- Step 3은 선택적 (MATLAB mock 모드면 없어도 됨)

## 다음 Step

- → Step 5, 6 (프론트엔드) 과 합류하여 전체 연동

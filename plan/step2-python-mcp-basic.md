# Step 2: Python MCP Server — 기본 도구

## 목표

Python MCP Server를 만들고, Excel/DOCX 기본 도구가 동작하는지 확인한다.

## 작업 내용

### 2-1. MCP 서버 진입점

- [ ] `python-tools/server.py` — MCP 서버 메인, 모든 도구를 등록하고 실행

### 2-2. Excel 도구

- [ ] `python-tools/tools/excel.py`:
  - `excel_read(file_path, sheet?)` → 시트 내용을 JSON으로 반환
  - `excel_write(file_path, data, sheet?)` → 데이터를 Excel 파일로 생성/수정

### 2-3. DOCX 도구

- [ ] `python-tools/tools/docx.py`:
  - `docx_read(file_path)` → 문서 텍스트를 반환
  - `docx_write(file_path, content, template?)` → Word 문서 생성/수정

### 2-4. 분석 도구

- [ ] `python-tools/tools/analysis.py`:
  - `pandas_analyze(file_path, query)` → 데이터 분석 결과 반환
  - `plot_create(data, chart_type, output_path)` → 차트 PNG 생성

### 2-5. 의존성

- [ ] `requirements.txt`:
  ```
  mcp
  openpyxl
  python-docx
  pandas
  matplotlib
  scipy
  ```

## 검증

```bash
# 패키지 설치
cd python-tools && pip install -r requirements.txt

# 서버 실행 (에러 없이 시작되는지)
python server.py

# 테스트 스크립트로 도구 호출
python tests/test_excel.py   # excel_read, excel_write 동작 확인
python tests/test_docx.py    # docx_read, docx_write 동작 확인
```

## 의존성

- Step 1 (디렉토리 구조)

## 다음 Step

- → Step 3 (MATLAB 연동)
- → Step 4 (OpenCode 연동)

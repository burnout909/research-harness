# Step 3: Python MCP Server — MATLAB 연동

## 목표

MATLAB Engine for Python을 통한 스크립트 실행이 동작하는지 확인한다.

## 작업 내용

### 3-1. MATLAB 도구

- [ ] `python-tools/tools/matlab.py`:
  - `matlab_generate_script(experiment_type, parameters)` → .m 파일 생성, 내용 반환
  - `matlab_run(script, work_dir?)` → MATLAB Engine으로 실행, 결과 반환
  - `matlab_check_convergence(mat_file, threshold?)` → 수렴 여부 판정
  - `matlab_get_figures(work_dir?)` → 생성된 figure 파일(.png, .fig) 목록 반환

### 3-2. 기존 도구에 추가

- [ ] `python-tools/tools/excel.py`에 추가:
  - `mat_to_excel(mat_file, output_path)` → .mat → .xlsx 변환 (scipy.io.loadmat → openpyxl)

- [ ] `python-tools/tools/docx.py`에 추가:
  - `manuscript_generate(excel_path, figures, sections, template?, journal_style?)` → 논문 초안 DOCX

### 3-3. Mock 모드

- [ ] MATLAB 미설치 환경을 위한 mock 모드 구현
  - `MATLAB_MOCK=true` 환경변수로 토글
  - 더미 .mat 파일과 더미 figure를 반환
  - 파이프라인 전체 흐름 테스트용

### 3-4. 의존성 추가

- [ ] `requirements.txt`에 추가:
  ```
  matlabengine    # MATLAB이 설치된 환경에서만
  ```

## 검증

```bash
# MATLAB 설치 환경
python -c "import matlab.engine; eng = matlab.engine.start_matlab(); print(eng.sqrt(4.0)); eng.quit()"

# MCP 도구 테스트
python tests/test_matlab.py

# Mock 모드 테스트 (MATLAB 없이)
MATLAB_MOCK=true python tests/test_matlab.py
```

## 의존성

- Step 2 (Python MCP 기본 도구)

## 참고

- MATLAB이 없는 환경에서는 mock 모드로 진행, 나중에 실제 MATLAB 연결
- MATLAB 라이선스가 서버에 없을 경우: MATLAB Compiler SDK로 standalone 바이너리 + MATLAB Runtime(무료) 대안

## 다음 Step

- → Step 4 (OpenCode 연동)

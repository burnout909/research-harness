# Research Harness — 프로젝트 규칙

## 데이터 관리 프로토콜
- 업로드 원본: data/uploads/ (읽기 전용 취급, 수정/삭제 금지)
- 분석 결과: data/outputs/ (가공된 테이블, 그래프)
- MATLAB 작업: data/matlab/ (스크립트, .mat 결과)
- 논문/문서: data/manuscripts/ (초안, 최종본)
- 파일명 규칙: {실험명}_{YYYYMMDD}_{v01}.{ext}
- 기존 파일 덮어쓰기 금지 — 항상 버전 번호 증가

## 승인 프로토콜 (Human-in-the-Loop)
다음 작업은 반드시 연구자 승인 후 진행:
1. 실험 파라미터 최종 확정 (Phase 1 → Phase 2 전환)
2. MATLAB 스크립트 실행 (Phase 2 시작)
3. 최종 산출물 확정 (Excel 테이블, Figure, 논문 초안)
4. 파일 삭제 또는 이동
5. 실험 조건 변경

## 연구 도구 우선순위
1. MCP 도구 (read_excel, analyze_data, create_plot 등) 우선 사용
2. 빌트인 도구 (bash, read, write, glob, grep) 보조적 사용
3. MATLAB 도구는 Phase 2에서만 사용

## 논문 작성 규칙
- generate_manuscript로 초안 생성
- 학술지 양식 준수 (IEEE 등 연구자 지정 양식)
- 그래프는 create_plot으로 생성 (300 DPI, 명확한 라벨링)
- 표는 Excel 데이터 기반으로 자동 생성
- 수식은 LaTeX 표기

## 금지 사항
- data/uploads/ 의 원본 데이터 직접 수정
- 연구자 확인 없는 파일 삭제
- 실험 조건/파라미터 임의 변경
- 불확실한 결과에 대한 단정적 표현

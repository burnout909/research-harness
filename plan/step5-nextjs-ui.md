# Step 5: Next.js 프론트엔드 — 기본 UI

## 목표

Next.js로 대화 UI + 파일 뷰어의 기본 틀을 만든다.

## 작업 내용

### 5-1. API 프록시 설정

- [ ] `next.config.js` — rewrites로 OpenCode API 프록시:
  ```js
  // /api/opencode/* → http://localhost:4096/*
  ```

### 5-2. API 클라이언트

- [ ] `src/lib/api.ts` — OpenCode SDK 래퍼:
  - 세션 생성/목록 조회
  - 메시지 전송
  - SSE(Server-Sent Events) 구독으로 실시간 응답 수신

### 5-3. 대화 UI

- [ ] `src/components/chat/ChatWindow.tsx` — 메시지 목록 + 입력창
- [ ] `src/components/chat/MessageBubble.tsx` — 사용자/에이전트 메시지 구분

### 5-4. 파일 뷰어

- [ ] `src/components/viewer/ExcelViewer.tsx` — SheetJS 기반 엑셀 테이블 렌더링
- [ ] `src/components/viewer/DocxViewer.tsx` — mammoth.js 기반 DOCX → HTML
- [ ] `src/components/viewer/ImageViewer.tsx` — figure/차트 이미지 표시
- [ ] `src/components/viewer/FileCard.tsx` — 파일 카드 (미리보기/다운로드/편집 버튼)

### 5-5. 메인 페이지 레이아웃

- [ ] `src/app/page.tsx` — 2열 레이아웃:
  - 좌측: 대화 UI (ChatWindow)
  - 우측: 파일 뷰어 (생성된 파일 목록 + 미리보기)

### 5-6. 프론트엔드 의존성

- [ ] `package.json`에 추가:
  ```
  xlsx          # SheetJS (엑셀 미리보기)
  mammoth       # DOCX → HTML
  ```

## 검증

```bash
cd frontend && npm run dev
# localhost:3000 접속
```

- [ ] 대화 UI가 렌더링되는지 확인
- [ ] OpenCode API에 메시지 전송 → 응답 수신 확인
- [ ] 테스트 .xlsx 파일 미리보기 동작 확인
- [ ] 테스트 .docx 파일 미리보기 동작 확인
- [ ] 파일 다운로드 버튼 동작 확인

## 의존성

- Step 1 (디렉토리 구조)
- Step 4 (OpenCode API가 떠 있어야 대화 테스트 가능, 단 UI 자체는 독립 개발 가능)

## 다음 Step

- → Step 6 (파이프라인 UI)

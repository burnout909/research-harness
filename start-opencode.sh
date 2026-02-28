#!/bin/bash
# OpenCode 서버 시작 스크립트
# API 키에서 사용 가능한 최상위 모델을 자동 감지하여 설정

set -e
cd "$(dirname "$0")/opencode"

# .env 로드
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

KEY="${GOOGLE_GENERATIVE_AI_API_KEY}"
if [ -z "$KEY" ]; then
  echo "ERROR: GOOGLE_GENERATIVE_AI_API_KEY not set in .env"
  exit 1
fi

# 모델 우선순위 (위에서부터 시도)
MAIN_MODELS=("gemini-3-pro-preview" "gemini-2.5-pro" "gemini-2.0-flash")
SMALL_MODELS=("gemini-3-flash-preview" "gemini-2.5-flash" "gemini-2.0-flash")

check_model() {
  local model="$1"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${KEY}" \
    -H 'Content-Type: application/json' \
    -d '{"contents":[{"parts":[{"text":"hi"}]}]}')
  [ "$status" = "200" ]
}

echo "Checking available models..."

MAIN=""
for m in "${MAIN_MODELS[@]}"; do
  if check_model "$m"; then
    MAIN="$m"
    echo "  Main model: $m ✓"
    break
  else
    echo "  $m ✗"
  fi
done

SMALL=""
for m in "${SMALL_MODELS[@]}"; do
  if check_model "$m"; then
    SMALL="$m"
    echo "  Small model: $m ✓"
    break
  else
    echo "  $m ✗"
  fi
done

if [ -z "$MAIN" ]; then
  echo "ERROR: No usable main model found. Check API key quota."
  exit 1
fi

CONFIG="../opencode.jsonc"
AGENT="../.opencode/agent/research.md"

# opencode.jsonc 업데이트
python3 -c "
import re, sys
with open('$CONFIG', 'r') as f:
    text = f.read()
text = re.sub(r'\"model\":\s*\"google/[^\"]+\"', '\"model\": \"google/$MAIN\"', text)
text = re.sub(r'\"small_model\":\s*\"google/[^\"]+\"', '\"small_model\": \"google/$SMALL\"', text)
with open('$CONFIG', 'w') as f:
    f.write(text)
"

# research.md 업데이트
python3 -c "
import re
with open('$AGENT', 'r') as f:
    text = f.read()
text = re.sub(r'model:\s*google/\S+', 'model: google/$MAIN', text)
with open('$AGENT', 'w') as f:
    f.write(text)
"

echo ""
echo "Config updated: main=google/$MAIN, small=google/$SMALL"
echo "Starting OpenCode server..."
echo ""

# packages/opencode/.env도 동기화
cp .env packages/opencode/.env

BUN="${HOME}/.bun/bin/bun"
exec "$BUN" run --cwd packages/opencode --conditions=browser src/index.ts serve

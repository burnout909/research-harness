#!/bin/bash
set -euo pipefail

# Load environment variables from .env
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

exec bun dev serve "$@"

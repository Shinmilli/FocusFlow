#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FLUTTER_DIR="${HOME}/flutter_sdk"
BRANCH="${FLUTTER_BRANCH:-stable}"

if [[ ! -d "$FLUTTER_DIR/.git" ]]; then
  rm -rf "$FLUTTER_DIR"
  git clone https://github.com/flutter/flutter.git -b "$BRANCH" --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics
flutter precache --web
flutter pub get

# Netlify UI → Environment variables 에서 주입 (없으면 빈 문자열 = API 없이 동작)
# OPENAI_API_KEY 는 웹 번들에 포함되므로 공개 배포에는 비추천
flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL:-}" \
  --dart-define=OPENAI_API_KEY="${OPENAI_API_KEY:-}"

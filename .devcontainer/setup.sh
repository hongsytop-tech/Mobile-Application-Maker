#!/usr/bin/env bash
set -euo pipefail

# Flutter SDK 설치 (stable)
if [ ! -d "$HOME/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
fi

# PATH 설정
SHELL_RC="$HOME/.bashrc"
if ! grep -q 'flutter/bin' "$SHELL_RC"; then
  echo 'export PATH="$PATH:$HOME/flutter/bin"' >> "$SHELL_RC"
fi
export PATH="$PATH:$HOME/flutter/bin"

# Flutter 셋업
flutter config --no-analytics --no-cli-animations || true
flutter precache --web

# 의존성 설치
flutter pub get || true

echo ""
echo "✅ Flutter 환경 준비 완료"
echo "사용법: flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0"

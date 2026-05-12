#!/usr/bin/env bash
set -e

if ! command -v flutter >/dev/null; then
  echo "Installing Flutter SDK (stable)..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"

  # Ensure web is enabled and SDKs are ready
  flutter config --enable-web
  flutter precache --web
  flutter --version
else
  echo "Flutter is already installed"
  flutter --version
fi

#!/bin/bash
set -e

echo "=== Kormo Vercel Build Pipeline ==="

# Check if Flutter is already cached
if [ ! -d "$HOME/flutter/bin" ]; then
  echo "Cloning Flutter stable SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
else
  echo "Using cached Flutter SDK."
fi

export PATH="$PATH:$HOME/flutter/bin"

flutter --version

echo "Building Kormo Flutter Web Release..."
cd app
flutter pub get
flutter build web --release

echo "=== Build Complete! Output at app/build/web ==="

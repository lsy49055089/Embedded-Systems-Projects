#!/usr/bin/env bash
# PC에서 실행 가능한 프로토콜 테스트와 문법 검사를 수행한다.
set -euo pipefail
cd "$(dirname "$0")/.."
python -m unittest discover -s tests -p 'test_*.py' -v
if command -v g++ >/dev/null 2>&1; then
  binary="$(mktemp)"
  trap 'rm -f "$binary"' EXIT
  g++ -std=c++17 -Wall -Wextra -Werror tests/test_packet.cpp -o "$binary"
  "$binary"
else
  echo 'g++ not installed: skipping C++ test'
fi
if command -v g++ >/dev/null 2>&1; then
  for core in 2 3; do
    sketch_exe="$(mktemp)"
    g++ -std=c++17 -Wall -Wextra -Werror \
      -DESP_ARDUINO_VERSION_MAJOR="$core" -Itests/stubs \
      tests/test_firmware_integration.cpp -o "$sketch_exe"
    "$sketch_exe"
    rm -f "$sketch_exe"
  done
fi
if command -v node >/dev/null 2>&1; then node --check firebase/functions/index.js; fi
if command -v flutter >/dev/null 2>&1; then
  (cd flutter_app && flutter pub get && flutter analyze && flutter test --dart-define=SMART_CARRIER_DEMO=true)
else
  echo 'Flutter not installed: Flutter analysis/build not verified'
fi

# 소스 파일과 펌웨어 패킷 계약을 PC에서 검증한다.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $root
try {
    python -m unittest discover -s tests -p 'test_*.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Python 테스트 실패' }
    if (Get-Command g++ -ErrorAction SilentlyContinue) {
        $exe = Join-Path $env:TEMP 'smart_carrier_packet_test.exe'
        g++ -std=c++17 -Wall -Wextra -Werror tests/test_packet.cpp -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'C++ 컴파일 실패' }
        & $exe
        if ($LASTEXITCODE -ne 0) { throw 'C++ 패킷 테스트 실패' }
    } else { Write-Warning 'g++ 미설치: C++ 패킷 테스트는 별도 확인 필요' }
    if (Get-Command g++ -ErrorAction SilentlyContinue) {
        foreach ($core in @(2, 3)) {
            $binary = Join-Path $env:TEMP "smart_carrier_firmware_$core.exe"
            g++ -std=c++17 -Wall -Wextra -Werror "-DESP_ARDUINO_VERSION_MAJOR=$core" -Itests/stubs tests/test_firmware_integration.cpp -o $binary
            if ($LASTEXITCODE -ne 0) { throw "펌웨어 호스트 컴파일 실패: Core $core" }
            & $binary
            if ($LASTEXITCODE -ne 0) { throw "펌웨어 모의 실행 실패: Core $core" }
        }
    }
    if (Get-Command node -ErrorAction SilentlyContinue) {
        node --check firebase/functions/index.js
        if ($LASTEXITCODE -ne 0) { throw 'JavaScript 문법 오류' }
    } else { Write-Warning 'Node.js 미설치: Functions 문법 확인 필요' }
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        Push-Location flutter_app
        try {
            flutter pub get
            if ($LASTEXITCODE -ne 0) { throw 'Flutter 의존성 오류' }
            flutter analyze
            if ($LASTEXITCODE -ne 0) { throw 'Flutter 정적 분석 오류' }
            flutter test --dart-define=SMART_CARRIER_DEMO=true
            if ($LASTEXITCODE -ne 0) { throw 'Flutter 테스트 실패' }
        } finally { Pop-Location }
    } else { Write-Warning 'Flutter SDK 미설치: Flutter 분석/테스트 미수행' }
    Write-Host '현재 설치된 도구에 대한 검사를 완료했습니다.'
} finally { Pop-Location }

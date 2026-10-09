# Windows Flutter 설치 환경에서 앱 정적 분석, 테스트, DEMO APK 빌드를 진행한다.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter SDK가 PATH에 없습니다. flutter --version 명령을 먼저 확인하세요.'
}
Push-Location (Join-Path $root 'flutter_app')
try {
    function Invoke-Flutter([string[]]$Arguments) {
        & flutter @Arguments
        if ($LASTEXITCODE -ne 0) { throw "Flutter 명령 실패: flutter $($Arguments -join ' ')" }
    }

    if (-not (Test-Path 'android/app')) {
        Invoke-Flutter -Arguments @('create', '--platforms=android', '--project-name', 'smart_carrier_app', '.')
        Write-Warning 'Android 프로젝트 생성 후 docs/ANDROID_SETUP.md의 권한 및 Gradle desugaring 설정을 확인하세요.'
    }
    Invoke-Flutter -Arguments @('pub', 'get')
    Invoke-Flutter -Arguments @('analyze')
    Invoke-Flutter -Arguments @('test')
    Invoke-Flutter -Arguments @('test', '--dart-define=SMART_CARRIER_DEMO=true')
    Invoke-Flutter -Arguments @('build', 'apk', '--debug', '--dart-define=SMART_CARRIER_DEMO=true')
    Write-Host 'PASS: Flutter 분석, 일반/DEMO 테스트, DEMO APK 디버그 빌드 성공'
} finally {
    Pop-Location
}

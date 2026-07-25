param()

$ErrorActionPreference = "Stop"

$root = "E:\project 3\MindPulse-AI"
$app = Join-Path $root "mobile_app"

$adb =
  "E:\Android\Sdk\platform-tools\adb.exe"

$flutter =
  "E:\Android\flutter\bin\flutter.bat"

$pixel = "49261FDAQ0018M"

$package =
  "com.mindpulseai.mindpulse_ai"

$activity =
  "$package/.MainActivity"

$apk =
  Join-Path $app `
    "build\app\outputs\flutter-apk\app-debug.apk"

$starter =
  Join-Path $root "start_mindpulse.ps1"


function Test-Port {
  param([int]$Port)

  return $null -ne (
    Get-NetTCPConnection `
      -LocalPort $Port `
      -State Listen `
      -ErrorAction SilentlyContinue |
    Select-Object -First 1
  )
}


function Wait-For-Port {
  param(
    [int]$Port,
    [int]$TimeoutSeconds = 120
  )

  $deadline =
    (Get-Date).AddSeconds($TimeoutSeconds)

  while ((Get-Date) -lt $deadline) {
    if (Test-Port -Port $Port) {
      return $true
    }

    Start-Sleep -Seconds 2
  }

  return $false
}


Write-Host ""
Write-Host "========================================"
Write-Host " MindPulse AI - Pixel 9 Launcher"
Write-Host "========================================"
Write-Host ""


if (-not (Test-Path -LiteralPath $adb)) {
  throw "ADB পাওয়া যায়নি: $adb"
}

if (-not (Test-Path -LiteralPath $starter)) {
  throw "Startup script পাওয়া যায়নি: $starter"
}


Write-Host "Checking Pixel 9 connection..."

$deviceLine = @(
  & $adb devices
) | Where-Object {
  $_ -match "^$([regex]::Escape($pixel))\s+device$"
}

if (-not $deviceLine) {
  Write-Host ""
  Write-Host "PIXEL 9 CONNECTED নয়।" `
    -ForegroundColor Red

  Write-Host ""
  Write-Host "USB cable লাগান এবং USB debugging Allow করুন।"
  Write-Host ""

  Read-Host "তারপর Enter চাপুন"

  $deviceLine = @(
    & $adb devices
  ) | Where-Object {
    $_ -match "^$([regex]::Escape($pixel))\s+device$"
  }

  if (-not $deviceLine) {
    throw "Pixel 9 এখনও পাওয়া যায়নি।"
  }
}

Write-Host "Pixel 9 connected." `
  -ForegroundColor Green


$backendRunning = Test-Port -Port 5000
$aiRunning = Test-Port -Port 8000

if (-not $backendRunning -or -not $aiRunning) {
  Write-Host ""
  Write-Host "Starting MindPulse servers..."

  Start-Process `
    powershell.exe `
    -WorkingDirectory $root `
    -ArgumentList @(
      "-NoExit",
      "-ExecutionPolicy",
      "Bypass",
      "-Command",
      "& '$starter'"
    )

  Write-Host "Waiting for Backend port 5000..."

  if (-not (Wait-For-Port -Port 5000)) {
    throw "Backend port 5000 চালু হয়নি।"
  }

  Write-Host "Backend ready." `
    -ForegroundColor Green

  Write-Host "Waiting for AI service port 8000..."

  if (-not (Wait-For-Port -Port 8000)) {
    throw "AI service port 8000 চালু হয়নি।"
  }

  Write-Host "AI service ready." `
    -ForegroundColor Green
}
else {
  Write-Host ""
  Write-Host "Backend and AI service already running." `
    -ForegroundColor Green
}


Write-Host ""
Write-Host "Connecting Pixel 9 to local servers..."

& $adb -s $pixel reverse --remove-all |
  Out-Null

& $adb -s $pixel reverse tcp:5000 tcp:5000

if ($LASTEXITCODE -ne 0) {
  throw "Port 5000 reverse failed."
}

& $adb -s $pixel reverse tcp:8000 tcp:8000

if ($LASTEXITCODE -ne 0) {
  throw "Port 8000 reverse failed."
}

Write-Host ""
Write-Host "Active reverse ports:"

& $adb -s $pixel reverse --list


if (-not (Test-Path -LiteralPath $apk)) {
  Write-Host ""
  Write-Host "Debug APK পাওয়া যায়নি। Building APK..."

  Set-Location $app

  & $flutter build apk `
    --debug `
    --no-pub `
    --dart-define=API_BASE_URL=http://127.0.0.1:5000/api/v1

  if ($LASTEXITCODE -ne 0) {
    throw "APK build failed."
  }
}


Write-Host ""
Write-Host "Installing latest available APK..."

& $adb -s $pixel install -r $apk

if ($LASTEXITCODE -ne 0) {
  throw "APK installation failed."
}


Write-Host ""
Write-Host "Launching MindPulse AI..."

& $adb -s $pixel shell am force-stop $package

& $adb -s $pixel shell am start -n $activity

if ($LASTEXITCODE -ne 0) {
  throw "App launch failed."
}


Write-Host ""
Write-Host "========================================"
Write-Host " MINDPULSE AI IS READY"
Write-Host "========================================"
Write-Host ""
Write-Host "Backend: http://127.0.0.1:5000"
Write-Host "AI API:  http://127.0.0.1:8000"
Write-Host "Device:  Pixel 9"
Write-Host ""

Read-Host "এই window বন্ধ করতে Enter চাপুন"
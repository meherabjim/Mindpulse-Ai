& {
  $ErrorActionPreference = "Stop"

  $root =
    "E:\project 3\MindPulse-AI"

  $backend =
    Join-Path $root "backend"

  $aiService =
    Join-Path $root "ai_service"

  $mobile =
    Join-Path $root "mobile_app"

  $python =
    Join-Path $aiService ".venv\Scripts\python.exe"

  $flutter =
    "E:\Android\flutter\bin\flutter.bat"

  $adb =
    "E:\Android\Sdk\platform-tools\adb.exe"

  $emulator =
    "E:\Android\Sdk\emulator\emulator.exe"

  $physicalSerial =
    "49261FDAQ0018M"

  $package =
    "com.mindpulseai.mindpulse_ai"

  $apk =
    Join-Path `
      $mobile `
      "build\app\outputs\flutter-apk\app-debug.apk"

  $logRoot =
    Join-Path `
      $root `
      ("runtime_logs\all_devices_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

  function Test-Port {
    param(
      [Parameter(Mandatory)]
      [int]$Port
    )

    return $null -ne (
      Get-NetTCPConnection `
        -LocalPort $Port `
        -State Listen `
        -ErrorAction SilentlyContinue |
      Select-Object -First 1
    )
  }

  function Wait-Port {
    param(
      [Parameter(Mandatory)]
      [int]$Port,

      [Parameter(Mandatory)]
      [string]$Name,

      [int]$TimeoutSeconds = 120
    )

    $deadline =
      (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
      if (Test-Port -Port $Port) {
        Write-Host "${Name}: READY on $Port" `
          -ForegroundColor Green
        return
      }

      Start-Sleep -Seconds 2
    }

    throw "${Name} port $Port চালু হয়নি।"
  }

  function Start-ServiceWindow {
    param(
      [Parameter(Mandatory)]
      [string]$Title,

      [Parameter(Mandatory)]
      [string]$WorkingDirectory,

      [Parameter(Mandatory)]
      [string]$Command
    )

    $windowCommand =
      "`$Host.UI.RawUI.WindowTitle = '$Title'; " +
      "Set-Location '$WorkingDirectory'; " +
      $Command

    Start-Process `
      -FilePath "powershell.exe" `
      -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        $windowCommand
      ) `
      -WorkingDirectory $WorkingDirectory
  }

  function Get-PixelEmulator {
    $lines =
      @(
        & $adb devices |
        Select-String "^emulator-\d+\s+device$"
      )

    foreach ($line in $lines) {
      $serial =
        ($line.Line -split "\s+")[0]

      $avdName =
        (
          & $adb `
            -s $serial `
            emu avd name `
            2>$null |
          Select-Object -First 1 |
          Out-String
        ).Trim()

      if ($avdName -eq "Pixel_9") {
        return $serial
      }
    }

    return $null
  }

  function Start-PixelEmulator {
    $existing =
      Get-PixelEmulator

    if ($existing) {
      Write-Host "Pixel_9 emulator: READY ($existing)" `
        -ForegroundColor Green
      return $existing
    }

    $avds =
      @(
        & $emulator -list-avds |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
      )

    if ($avds -notcontains "Pixel_9") {
      throw "Pixel_9 AVD পাওয়া যায়নি।"
    }

    Write-Host "Starting Pixel_9 emulator..." `
      -ForegroundColor Cyan

    Start-Process `
      -FilePath $emulator `
      -ArgumentList @(
        "-avd",
        "Pixel_9",
        "-no-snapshot-load",
        "-no-boot-anim",
        "-netdelay",
        "none",
        "-netspeed",
        "full"
      )

    $deadline =
      (Get-Date).AddMinutes(8)

    while ((Get-Date) -lt $deadline) {
      Start-Sleep -Seconds 3

      $serial =
        Get-PixelEmulator

      if (-not $serial) {
        continue
      }

      $boot =
        (
          & $adb `
            -s $serial `
            shell getprop sys.boot_completed `
            2>$null |
          Out-String
        ).Trim()

      if ($boot -eq "1") {
        Write-Host "Pixel_9 emulator: READY ($serial)" `
          -ForegroundColor Green
        return $serial
      }
    }

    throw "Pixel_9 emulator 8 মিনিটেও boot হয়নি।"
  }

  function Wait-PhysicalPhone {
    $state =
      (
        & $adb `
          -s $physicalSerial `
          get-state `
          2>&1 |
        Out-String
      ).Trim()

    if ($state -eq "device") {
      Write-Host "Physical phone: READY ($physicalSerial)" `
        -ForegroundColor Green
      return
    }

    Write-Host ""
    Write-Host "Physical phone connected নয়।" `
      -ForegroundColor Yellow
    Write-Host "USB cable লাগান, phone unlock করুন এবং USB debugging Allow দিন।"
    Read-Host "তারপর Enter চাপুন"

    $state =
      (
        & $adb `
          -s $physicalSerial `
          get-state `
          2>&1 |
        Out-String
      ).Trim()

    if ($state -ne "device") {
      throw "Physical phone পাওয়া যায়নি: $physicalSerial"
    }

    Write-Host "Physical phone: READY ($physicalSerial)" `
      -ForegroundColor Green
  }

  function Connect-Device {
    param(
      [Parameter(Mandatory)]
      [string]$Serial,

      [Parameter(Mandatory)]
      [string]$Label
    )

    & $adb -s $Serial reverse --remove-all `
      2>$null |
    Out-Null

    & $adb -s $Serial reverse tcp:5000 tcp:5000 |
    Out-Null

    if ($LASTEXITCODE -ne 0) {
      throw "$Label backend reverse failed."
    }

    & $adb -s $Serial reverse tcp:8000 tcp:8000 |
    Out-Null

    if ($LASTEXITCODE -ne 0) {
      throw "$Label AI reverse failed."
    }

    Write-Host "$Label reverse ports: READY" `
      -ForegroundColor Green
  }

  function Install-And-Open {
    param(
      [Parameter(Mandatory)]
      [string]$Serial,

      [Parameter(Mandatory)]
      [string]$Label
    )

    Write-Host "Installing on $Label..." `
      -ForegroundColor Cyan

    & $adb -s $Serial install -r $apk

    if ($LASTEXITCODE -ne 0) {
      throw "$Label APK installation failed."
    }

    & $adb -s $Serial shell am force-stop $package

    Start-Sleep -Seconds 1

    & $adb `
      -s $Serial `
      shell monkey `
      -p $package `
      -c android.intent.category.LAUNCHER `
      1 |
    Out-Null

    if ($LASTEXITCODE -ne 0) {
      throw "$Label app launch failed."
    }

    Write-Host "$Label app: OPEN" `
      -ForegroundColor Green
  }

  foreach ($required in @(
    $root,
    $backend,
    $aiService,
    $mobile,
    $python,
    $flutter,
    $adb,
    $emulator
  )) {
    if (-not (Test-Path -LiteralPath $required)) {
      throw "Required path পাওয়া যায়নি: $required"
    }
  }

  New-Item `
    -ItemType Directory `
    -Path $logRoot `
    -Force |
  Out-Null

  Write-Host ""
  Write-Host "=============================================="
  Write-Host " MINDPULSE ALL DEVICES START"
  Write-Host "==============================================" `
    -ForegroundColor Cyan

  Set-Location $root

  Write-Host ""
  Write-Host "Current project:" `
    -ForegroundColor Cyan
  git log -1 --oneline
  git status --short

  if (-not (Test-Port -Port 3306)) {
    $mysqlStart = "C:\xampp\mysql_start.bat"
    if (-not (Test-Path -LiteralPath $mysqlStart)) {
      throw "MySQL চালু নেই এবং XAMPP mysql_start.bat পাওয়া যায়নি।"
    }

    Start-Process `
      -FilePath $mysqlStart `
      -WorkingDirectory "C:\xampp" `
      -WindowStyle Minimized

    Wait-Port `
      -Port 3306 `
      -Name "MySQL" `
      -TimeoutSeconds 45
  }
  else {
    Write-Host "MySQL: READY on 3306" `
      -ForegroundColor Green
  }

  if (-not (Test-Port -Port 5000)) {
    Start-ServiceWindow `
      -Title "MindPulse Backend 5000" `
      -WorkingDirectory $backend `
      -Command "npm run dev"

    Wait-Port `
      -Port 5000 `
      -Name "Backend" `
      -TimeoutSeconds 90
  }
  else {
    Write-Host "Backend: READY on 5000" `
      -ForegroundColor Green
  }

  if (-not (Test-Port -Port 8000)) {
    Start-ServiceWindow `
      -Title "MindPulse AI 8000" `
      -WorkingDirectory $aiService `
      -Command (
        "& '$python' -m uvicorn " +
        "app.main:app --host 127.0.0.1 --port 8000 --reload"
      )

    Wait-Port `
      -Port 8000 `
      -Name "FastAPI AI" `
      -TimeoutSeconds 90
  }
  else {
    Write-Host "FastAPI AI: READY on 8000" `
      -ForegroundColor Green
  }

  $backendHealth =
    Invoke-RestMethod `
      -Method Get `
      -Uri "http://127.0.0.1:5000/api/v1/health" `
      -TimeoutSec 15

  $aiHealth =
    Invoke-RestMethod `
      -Method Get `
      -Uri "http://127.0.0.1:8000/health" `
      -TimeoutSec 15

  Write-Host "Backend health: PASSED" `
    -ForegroundColor Green
  Write-Host "AI health: PASSED" `
    -ForegroundColor Green

  & $adb start-server |
  Out-Null

  $emulatorSerial =
    Start-PixelEmulator

  Wait-PhysicalPhone

  Connect-Device `
    -Serial $emulatorSerial `
    -Label "Laptop Pixel_9"

  Connect-Device `
    -Serial $physicalSerial `
    -Label "Physical phone"

  Write-Host ""
  Write-Host "Building one APK for both devices..." `
    -ForegroundColor Cyan

  Set-Location $mobile

  & $flutter build apk `
    --debug `
    "--dart-define=API_BASE_URL=http://127.0.0.1:5000/api/v1"

  if ($LASTEXITCODE -ne 0) {
    throw "Debug APK build failed."
  }

  if (-not (Test-Path -LiteralPath $apk)) {
    throw "Built APK পাওয়া যায়নি: $apk"
  }

  Install-And-Open `
    -Serial $emulatorSerial `
    -Label "Laptop Pixel_9 emulator"

  Install-And-Open `
    -Serial $physicalSerial `
    -Label "Physical phone"

  Start-Process "http://127.0.0.1:5000/admin-dashboard/"
  Start-Process "http://127.0.0.1:8000/docs"

  Write-Host ""
  Write-Host "=============================================="
  Write-Host " MINDPULSE OPEN ON LAPTOP AND PHONE"
  Write-Host "==============================================" `
    -ForegroundColor Green

  Write-Host ""
  Write-Host "Laptop emulator: $emulatorSerial"
  Write-Host "Physical phone: $physicalSerial"
  Write-Host "Backend: http://127.0.0.1:5000"
  Write-Host "AI docs: http://127.0.0.1:8000/docs"
  Write-Host "Admin: http://127.0.0.1:5000/admin-dashboard/"
  Write-Host "Saved login/app data: KEPT"
  Write-Host "Runtime logs: $logRoot"
}

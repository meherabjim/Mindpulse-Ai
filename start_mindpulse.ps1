Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot =
    "E:\project 3\MindPulse-AI"

$backendRoot =
    "$projectRoot\backend"

$aiRoot =
    "$projectRoot\ai_service"

$mobileRoot =
    "$projectRoot\mobile_app"

$python =
    "$aiRoot\.venv\Scripts\python.exe"

$flutter =
    "E:\Android\flutter\bin\flutter.bat"

$adb =
    "E:\Android\Sdk\platform-tools\adb.exe"

$emulator =
    "E:\Android\Sdk\emulator\emulator.exe"

$mysqlStart =
    "C:\xampp\mysql_start.bat"

$xamppControl =
    "C:\xampp\xampp-control.exe"


function Test-ListeningPort {
    param(
        [Parameter(Mandatory)]
        [int] $Port
    )

    $connection =
        Get-NetTCPConnection `
            -LocalPort $Port `
            -State Listen `
            -ErrorAction SilentlyContinue |
        Select-Object -First 1

    return $null -ne $connection
}


function Wait-ForPort {
    param(
        [Parameter(Mandatory)]
        [int] $Port,

        [Parameter(Mandatory)]
        [string] $ServiceName,

        [int] $TimeoutSeconds = 45
    )

    $deadline =
        (Get-Date).AddSeconds(
            $TimeoutSeconds
        )

    while (
        (Get-Date) -lt $deadline
    ) {
        if (
            Test-ListeningPort `
                -Port $Port
        ) {
            Write-Host `
                "$ServiceName is ready on port $Port." `
                -ForegroundColor Green

            return
        }

        Start-Sleep -Seconds 1
    }

    throw (
        "$ServiceName did not open " +
        "port $Port within " +
        "$TimeoutSeconds seconds."
    )
}


Write-Host ""
Write-Host "========================================"
Write-Host " Starting MindPulse AI"
Write-Host "========================================"
Write-Host ""


# ========================================
# 1. Start MySQL
# ========================================

if (
    Test-ListeningPort -Port 3306
) {
    Write-Host `
        "MySQL is already running on port 3306." `
        -ForegroundColor Green
} else {
    Write-Host "Starting XAMPP MySQL..."

    if (
        Test-Path $mysqlStart
    ) {
        Start-Process `
            -FilePath $mysqlStart `
            -WorkingDirectory "C:\xampp" `
            -WindowStyle Minimized

        try {
            Wait-ForPort `
                -Port 3306 `
                -ServiceName "MySQL" `
                -TimeoutSeconds 30
        } catch {
            if (
                Test-Path $xamppControl
            ) {
                Start-Process `
                    -FilePath $xamppControl
            }

            throw (
                "MySQL did not start automatically. " +
                "Start MySQL from XAMPP Control Panel, " +
                "then run this script again."
            )
        }
    } elseif (
        Test-Path $xamppControl
    ) {
        Start-Process `
            -FilePath $xamppControl

        throw (
            "XAMPP Control Panel opened. " +
            "Start MySQL and run this script again."
        )
    } else {
        throw "XAMPP was not found in C:\xampp."
    }
}


# ========================================
# 2. Start Node backend
# ========================================

if (
    Test-ListeningPort -Port 5000
) {
    Write-Host `
        "Backend is already running on port 5000." `
        -ForegroundColor Green
} else {
    Write-Host "Starting Node backend..."

    $backendCommand =
        "Set-Location '$backendRoot'; " +
        "npm run dev"

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @(
            "-NoExit",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            $backendCommand
        ) `
        -WindowStyle Normal

    Wait-ForPort `
        -Port 5000 `
        -ServiceName "Node backend" `
        -TimeoutSeconds 60
}


# ========================================
# 3. Start FastAPI AI service
# ========================================

if (
    Test-ListeningPort -Port 8000
) {
    Write-Host `
        "AI service is already running on port 8000." `
        -ForegroundColor Green
} else {
    Write-Host "Starting FastAPI AI service..."

    if (
        -not (Test-Path $python)
    ) {
        throw (
            "AI virtual-environment Python " +
            "was not found: $python"
        )
    }

    $aiCommand =
        "Set-Location '$aiRoot'; " +
        "& '$python' -m uvicorn " +
        "app.main:app " +
        "--host 0.0.0.0 " +
        "--port 8000 " +
        "--reload"

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @(
            "-NoExit",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            $aiCommand
        ) `
        -WindowStyle Normal

    Wait-ForPort `
        -Port 8000 `
        -ServiceName "FastAPI AI service" `
        -TimeoutSeconds 60
}


# ========================================
# 4. Start ADB and emulator
# ========================================

if (
    -not (Test-Path $adb)
) {
    throw "ADB was not found: $adb"
}

if (
    -not (Test-Path $emulator)
) {
    throw "Android emulator was not found: $emulator"
}

& $adb start-server | Out-Null

$deviceLine =
    & $adb devices |
    Select-String `
        '^(emulator-\d+)\s+device$' |
    Select-Object -First 1

if (
    -not $deviceLine
) {
    Write-Host "Starting Pixel_9 emulator..."

    Start-Process `
        -FilePath $emulator `
        -ArgumentList @(
            "-avd",
            "Pixel_9"
        )

    & $adb wait-for-device
} else {
    Write-Host `
        "Android emulator is already connected." `
        -ForegroundColor Green
}


# ========================================
# 5. Wait for Android boot
# ========================================

Write-Host "Waiting for Android boot..."

$bootCompleted = ""

while (
    $bootCompleted -ne "1"
) {
    Start-Sleep -Seconds 3

    $bootOutput =
        & $adb shell `
            getprop `
            sys.boot_completed `
            2>$null

    $bootCompleted =
        "$bootOutput".Trim()

    Write-Host "Boot status: $bootCompleted"
}

$deviceLine =
    & $adb devices |
    Select-String `
        '^(emulator-\d+)\s+device$' |
    Select-Object -First 1

if (
    -not $deviceLine
) {
    throw (
        "Emulator booted but no usable " +
        "device was detected."
    )
}

$deviceId =
    (
        $deviceLine.Line `
        -split '\s+'
    )[0]

Write-Host `
    "Emulator ready: $deviceId" `
    -ForegroundColor Green


# ========================================
# 6. Show final service status
# ========================================

Write-Host ""
Write-Host "========================================"
Write-Host " MindPulse services are ready"
Write-Host "========================================"

Write-Host "MySQL:       http://127.0.0.1:3306"
Write-Host "Backend API: http://127.0.0.1:5000"
Write-Host "AI Service:  http://127.0.0.1:8000"
Write-Host "AI Docs:     http://127.0.0.1:8000/docs"
Write-Host "Emulator:    $deviceId"
Write-Host ""


# ========================================
# 7. Start Flutter
# ========================================

if (
    -not (Test-Path $flutter)
) {
    throw "Flutter was not found: $flutter"
}

Set-Location $mobileRoot

Write-Host "Starting Flutter app..."
Write-Host ""

& $flutter run `
    -t "lib\main.dart" `
    -d $deviceId `
    --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1

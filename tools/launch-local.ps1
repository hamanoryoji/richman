$ErrorActionPreference = 'Continue'
$ws = Split-Path -Parent $PSScriptRoot
$root = Join-Path $ws '_incoming\server\richonline-main\server'
$client = Join-Path $ws '_incoming\client\Richonline'
$exe = Join-Path $root 'build\RichOnline.Server.exe'
$data = Join-Path $root 'data'

if (-not (Get-Process RichOnline.Server -ErrorAction SilentlyContinue)) {
    $cmd = '"' + $exe + '" --data-dir "' + $data + '" --pipe richonline-local --client-profile richonline'
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = $cmd; CurrentDirectory = (Join-Path $root 'build')
    } | Out-Null
    Start-Sleep -Seconds 5
    Write-Output 'server started'
} else {
    Write-Output 'server already running'
}

$kpd = Join-Path $client 'online-client\local.kpd'
if (-not (Test-Path $kpd)) { throw "missing local config: $kpd" }

Get-Process RnClient -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
cmd /c start "" /D "$client" "$client\RnClient.exe" "online-client\local.kpd" 0
Write-Output 'client started; log in with any NEW username + password (auto-register)'

param([switch]$Reconfigure)
$ErrorActionPreference = 'Continue'

$root = 'C:\Users\Monty\Documents\deepseek-harness\default-workspace\_incoming\server\richonline-main'
$client = 'C:\Users\Monty\Documents\deepseek-harness\default-workspace\_incoming\client\Richonline'
$env:PATH = "C:\tools\llvm-mingw\bin;C:\Users\Monty\AppData\Roaming\Python\Python314\Scripts;$env:PATH"

Push-Location $root
try {
    if ($Reconfigure -or -not (Test-Path 'server\build\build.ninja')) {
        Write-Output '=== configure ==='
        cmake -S server -B server/build -G Ninja `
            -DCMAKE_C_COMPILER=clang `
            -DCMAKE_CXX_COMPILER=clang++ `
            -DCMAKE_BUILD_TYPE=Release `
            -DBUILD_TESTING=OFF `
            -DRICHONLINE_CLIENT_DIR="$client"
        Write-Output "configure exit=$LASTEXITCODE"
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }

    Write-Output '=== build ==='
    $sw = [Diagnostics.Stopwatch]::StartNew()
    cmake --build server/build --parallel 8 2>&1 | Tee-Object -FilePath "$root\server\build\build.log"
    $code = $LASTEXITCODE
    Write-Output ("build exit={0} elapsed={1}s" -f $code, [int]$sw.Elapsed.TotalSeconds)
    if ($code -ne 0) { exit $code }

    Write-Output '=== artifacts ==='
    Get-ChildItem 'server\build\*.exe' | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
} finally {
    Pop-Location
}

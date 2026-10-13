param(
    [ValidateSet("Start", "Unregister")]
    [string]$Mode = "Start",
    [switch]$ElevatedTask
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$registrar = Join-Path $root "winxime-tsf-register.exe"
$dll = Join-Path $root "winxime_tsf.dll"
$server = Join-Path $root "winxime-server.exe"
$icon = Join-Path $root "resources\icon.ico"

foreach ($required in @($registrar, $dll, $server, $icon)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing portable package file: $required"
    }
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if ($ElevatedTask) {
    if (-not $isAdmin) { throw "Administrator privileges are required to change TSF registration." }
    if ($Mode -eq "Start") {
        & $registrar -register $dll $icon
    } else {
        & $registrar -d
        & $registrar -unregister-user $dll
    }
    if ($LASTEXITCODE -ne 0) { throw "TSF registration command failed with exit code $LASTEXITCODE" }
    exit 0
}

if (-not $isAdmin) {
    $args = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Mode {1} -ElevatedTask' -f $MyInvocation.MyCommand.Path, $Mode
    $p = Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "Elevated TSF task failed or was cancelled (exit $($p.ExitCode))." }
} else {
    if ($Mode -eq "Start") {
        & $registrar -register $dll $icon
    } else {
        & $registrar -d
        & $registrar -unregister-user $dll
    }
    if ($LASTEXITCODE -ne 0) { throw "TSF task failed with exit code $LASTEXITCODE" }
}

if ($Mode -eq "Start") {
    Start-Process -FilePath $server -WorkingDirectory $root
    Write-Host "XimeYao server started. Switch input methods using Win+Space."
} else {
    Write-Host "XimeYao TSF unregistered. Your %APPDATA%\Xime data was NOT deleted."
    Write-Host "Close and reopen applications if their input method list is stale."
}

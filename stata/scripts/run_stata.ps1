param(
    [Parameter(Mandatory = $true)][string]$StataExe,
    [Parameter(Mandatory = $true)][string]$DoFile,
    [Parameter(Mandatory = $true)][string]$WorkDir
)

if (-not $env:ComSpec) {
    $env:ComSpec = Join-Path $env:SystemRoot "System32\cmd.exe"
}
if (-not $env:TEMP) {
    $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
    $env:TEMP = Join-Path $localAppData "Temp"
}
if (-not $env:TMP) {
    $env:TMP = $env:TEMP
}

$tempBase = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$runTemp = Join-Path $tempBase ("gracedr-stata-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runTemp | Out-Null
$env:TEMP = $runTemp
$env:TMP = $runTemp

try {
    Start-Process `
        -FilePath $StataExe `
        -ArgumentList "/e", "do", "`"$DoFile`"" `
        -Wait `
        -WorkingDirectory $WorkDir
}
finally {
    Remove-Item -Recurse -Force -Path $runTemp -ErrorAction SilentlyContinue
}

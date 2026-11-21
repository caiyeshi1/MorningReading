# 一键编译脚本（Windows PowerShell）
# 用法：双击 build.bat，或
#       powershell -ExecutionPolicy Bypass -File .\build.ps1
#
# 会自动在以下位置寻找 DevEco Studio 与 SDK：
#   1) D:\Huawei\DevEcoStudio   /  D:\Huawei\Sdk\hos      （推荐，普通目录）
#   2) ..\toolchain\DevEcoApp   /  ..\toolchain\sdk\hos   （早期的 DSH 工作区内安装）

$ErrorActionPreference = 'Stop'

$proj = $PSScriptRoot
$toolchain = (Resolve-Path (Join-Path $proj '..\toolchain')).Path

function FirstExisting([string[]]$paths, [string]$probe) {
    foreach ($p in $paths) {
        if (Test-Path (Join-Path $p $probe)) { return $p }
    }
    return $null
}

$DevEco = FirstExisting @('D:\Huawei\DevEcoStudio', (Join-Path $toolchain 'DevEcoApp')) 'tools\hvigor\bin\hvigorw.bat'
$Sdk    = FirstExisting @('D:\Huawei\Sdk\hos', (Join-Path $toolchain 'sdk\hos')) '26.0.0\ets'

if (-not $DevEco) { throw "找不到 DevEco Studio（D:\Huawei\DevEcoStudio 或 toolchain\DevEcoApp）" }
if (-not $Sdk)    { throw "找不到 SDK（D:\Huawei\Sdk\hos 或 toolchain\sdk\hos）" }

Write-Host "DevEco : $DevEco"
Write-Host "SDK    : $Sdk"

$env:HVIGOR_USER_HOME      = Join-Path $toolchain 'hvigor-home'
$env:DEVECO_SDK_HOME       = $Sdk
$env:OHOS_BASE_SDK_HOME    = $Sdk
$env:JAVA_HOME             = Join-Path $DevEco 'jbr'
$env:npm_config_cache      = Join-Path $toolchain 'npm-cache'
$env:npm_config_userconfig = Join-Path $toolchain 'hvigor-home\.npmrc'
$env:PATH = (Join-Path $DevEco 'tools\node') + ';' + (Join-Path $DevEco 'jbr\bin') + ';' + $env:PATH

Push-Location $proj
try {
    & (Join-Path $DevEco 'tools\hvigor\bin\hvigorw.bat') --mode module -p product=default assembleHap --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "编译失败（exit $LASTEXITCODE）" }
} finally {
    Pop-Location
}

$hap = Join-Path $proj 'entry\build\default\outputs\default\entry-default-unsigned.hap'
if (Test-Path $hap) {
    Write-Host ""
    Write-Host "编译成功：$hap" -ForegroundColor Green
    Write-Host ("大小：{0:N1} MB" -f ((Get-Item $hap).Length / 1MB))
    Write-Host "提示：未签名 HAP 不能直接装到手机，请在 DevEco Studio 里配置自动签名后 Run/Build。"
} else {
    throw "未找到 HAP 产物"
}

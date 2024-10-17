param (
    [string]$BUILD_DIR
)

$ErrorActionPreference = "Stop"

function Get-DefaultParallelLevel {
    if ($IsWindows) {
        (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors
    } elseif ($IsMacOS) {
        sysctl -n hw.logicalcpu
    } else {
        Get-Content "/proc/cpuinfo" | Select-String "processor" | Measure-Object | Select-Object -ExpandProperty Count
    }
}

if (-not $env:CTEST_PARALLEL_LEVEL) {
    $env:CTEST_PARALLEL_LEVEL = Get-DefaultParallelLevel
}

$env:IREE_VULKAN_DISABLE = $env:IREE_VULKAN_DISABLE -or 1
$env:IREE_METAL_DISABLE = $env:IREE_METAL_DISABLE -or 1
$env:IREE_CUDA_ENABLE = $env:IREE_CUDA_ENABLE -or 0

$labelExcludeArgs = @()
if ($env:IREE_VULKAN_DISABLE -eq 1) { $labelExcludeArgs += "^driver=vulkan$" }
if ($env:IREE_METAL_DISABLE -eq 1) { $labelExcludeArgs += "^driver=metal$" }

$ctestArgs = @(
    "--test-dir", $BUILD_DIR,
    "--timeout", "900",
    "--output-on-failure",
    "--no-tests=error",
    "-VV"
)

if ($labelExcludeArgs.Count -gt 0) {
    $labelExcludeRegex = ($labelExcludeArgs -join '|')
    $ctestArgs += "--label-exclude", "($labelExcludeRegex)"
}

$ctestArgsString = $ctestArgs -join ' '
Write-Host "*************** Running CTest ***************"
Start-Process "ctest" -ArgumentList $ctestArgsString -Wait -NoNewWindow


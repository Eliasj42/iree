# Run all ctest tests in a build directory, adding automatic filtering
# based on environment variables and defaults. The build directory is the first argument.

param (
    [string]$BUILD_DIR
)

# Exit on error and treat unset variables as errors
$ErrorActionPreference = "Stop"

function Get-DefaultParallelLevel {
    if ($IsMacOS) {
        sysctl -n hw.logicalcpu
    } else {
        (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors
    }
}

# Default environment settings, respecting user-provided values
$env:CTEST_PARALLEL_LEVEL = $env:CTEST_PARALLEL_LEVEL -or (Get-DefaultParallelLevel)
$env:IREE_VULKAN_DISABLE = $env:IREE_VULKAN_DISABLE -or 1
$env:IREE_METAL_DISABLE = $env:IREE_METAL_DISABLE -or 1
$env:IREE_CUDA_ENABLE = $env:IREE_CUDA_ENABLE -or 0
$env:IREE_HIP_ENABLE = $env:IREE_HIP_ENABLE -or 0
$env:IREE_VULKAN_F16_DISABLE = $env:IREE_VULKAN_F16_DISABLE -or 1
$env:IREE_NVIDIA_GPU_TESTS_DISABLE = $env:IREE_NVIDIA_GPU_TESTS_DISABLE -or 1
$env:IREE_NVIDIA_SM80_TESTS_DISABLE = $env:IREE_NVIDIA_SM80_TESTS_DISABLE -or 1
$env:IREE_AMD_RDNA3_TESTS_DISABLE = $env:IREE_AMD_RDNA3_TESTS_DISABLE -or 1
$env:IREE_MULTI_DEVICE_TESTS_DISABLE = $env:IREE_MULTI_DEVICE_TESTS_DISABLE -or 1

# Collect test exclusion labels based on settings
$labelExcludeArgs = @()
if ($env:IREE_VULKAN_DISABLE -eq 1) { $labelExcludeArgs += "^driver=vulkan$" }
if ($env:IREE_METAL_DISABLE -eq 1) { $labelExcludeArgs += "^driver=metal$" }
if ($env:IREE_CUDA_ENABLE -eq 0) { $labelExcludeArgs += "^driver=cuda$" }
if ($env:IREE_HIP_ENABLE -eq 0) { $labelExcludeArgs += "^driver=hip$" }
if ($env:IREE_VULKAN_F16_DISABLE -eq 1) { $labelExcludeArgs += "^vulkan_uses_vk_khr_shader_float16_int8$" }
if ($env:IREE_NVIDIA_GPU_TESTS_DISABLE -eq 1) { $labelExcludeArgs += "^requires-gpu" }
if ($env:IREE_NVIDIA_SM80_TESTS_DISABLE -eq 1) { $labelExcludeArgs += "^requires-gpu-sm80$" }
if ($env:IREE_AMD_RDNA3_TESTS_DISABLE -eq 1) { $labelExcludeArgs += "^requires-gpu-rdna3$" }
if ($env:IREE_MULTI_DEVICE_TESTS_DISABLE -eq 1) { $labelExcludeArgs += "^requires-multiple-devices$" }

# Include extra exclusion labels, if specified
if ($env:IREE_EXTRA_COMMA_SEPARATED_CTEST_LABELS_TO_EXCLUDE) {
    $labelExcludeArgs += $env:IREE_EXTRA_COMMA_SEPARATED_CTEST_LABELS_TO_EXCLUDE -split ','
}

# Platform-specific test exclusions
$excludedTests = @()
if ($IsWindows) {
    $excludedTests += @(
        "iree/tests/e2e/matmul/e2e_matmul_vmvx_dt_uk_i8_small_vmvx_local-task",
        "iree/tests/e2e/matmul/e2e_matmul_vmvx_dt_uk_f32_small_vmvx_local-task",
        "iree/tests/e2e/tensor_ops/check_vmvx_ukernel_local-task_pack.mlir",
        "iree/tests/e2e/tensor_ops/check_vmvx_ukernel_local-task_unpack.mlir",
        "iree/tests/e2e/tosa_ops/check_vmvx_local-sync_microkernels_fully_connected.mlir",
        "iree/tests/e2e/tosa_ops/check_vmvx_local-sync_microkernels_matmul.mlir"
    )
}

# CTest arguments
$ctestArgs = @(
    "--test-dir", $BUILD_DIR,
    "--timeout", "900",
    "--output-on-failure",
    "--no-tests=error"
)

if ($env:IREE_CTEST_TESTS_REGEX) { $ctestArgs += "--tests-regex", $env:IREE_CTEST_TESTS_REGEX }
if ($env:IREE_CTEST_LABEL_REGEX) { $ctestArgs += "--label-regex", $env:IREE_CTEST_LABEL_REGEX }
if ($env:IREE_CTEST_REPEAT_UNTIL_FAIL_COUNT) { $ctestArgs += "--repeat-until-fail", $env:IREE_CTEST_REPEAT_UNTIL_FAIL_COUNT }

if ($labelExcludeArgs.Count -gt 0) {
    $labelExcludeRegex = ($labelExcludeArgs -join '|')
    $ctestArgs += "--label-exclude", "($labelExcludeRegex)"
}

if ($excludedTests.Count -gt 0) {
    $excludedTestsRegex = ($excludedTests -join '|')
    $ctestArgs += "--exclude-regex", "($excludedTestsRegex)"
}

Write-Host "*************** Running CTest ***************"
Start-Process "ctest" -ArgumentList $ctestArgs -Wait -NoNewWindow

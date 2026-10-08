# ==============================================================================
# Simulation Runner for CH7516 DP to LVDS Design
# ==============================================================================

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$Iverilog = "$ProjectRoot\tools\iverilog\app\bin\iverilog.exe"
$Vvp = "$ProjectRoot\tools\iverilog\app\bin\vvp.exe"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Running CH7516 DisplayPort to LVDS Verilog Verification Suite" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. Compile and Run Unit Tests
Write-Host "`n[Step 1/2] Compiling and running Unit Tests..." -ForegroundColor Yellow
& $Iverilog -g2012 -o "$PSScriptRoot\tb_unit_tests.vvp" `
    "$ProjectRoot\rtl\dp_8b10b_decoder.v" `
    "$ProjectRoot\rtl\dp_descrambler.v" `
    "$ProjectRoot\rtl\lvds_formatter_vesa8.v" `
    "$PSScriptRoot\tb_unit_tests.v"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Unit test compilation failed!" -ForegroundColor Red
    exit 1
}

& $Vvp "$PSScriptRoot\tb_unit_tests.vvp"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Unit test simulation failed!" -ForegroundColor Red
    exit 1
}

# 2. Compile and Run Top-Level Verification
Write-Host "`n[Step 2/2] Compiling and running Top-Level System Testbench..." -ForegroundColor Yellow
& $Iverilog -g2012 -o "$PSScriptRoot\tb_ch7516_top.vvp" `
    "$ProjectRoot\rtl\dp_8b10b_decoder.v" `
    "$ProjectRoot\rtl\dp_descrambler.v" `
    "$ProjectRoot\rtl\dp_pixel_unpacker_4lane.v" `
    "$ProjectRoot\rtl\video_async_fifo.v" `
    "$ProjectRoot\rtl\video_timing_generator.v" `
    "$ProjectRoot\rtl\video_bist_pattern.v" `
    "$ProjectRoot\rtl\lvds_formatter_vesa8.v" `
    "$ProjectRoot\rtl\lvds_serializer_7to1.v" `
    "$ProjectRoot\rtl\ch7516_dp_to_lvds_top.v" `
    "$PSScriptRoot\tb_ch7516_top.v"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Top testbench compilation failed!" -ForegroundColor Red
    exit 1
}

& $Vvp "$PSScriptRoot\tb_ch7516_top.vvp"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Top testbench simulation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n=================================================================" -ForegroundColor Green
Write-Host " ALL CH7516 VERILOG SIMULATIONS COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green

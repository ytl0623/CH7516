# ==============================================================================
# Simulation Runner for CH7516 RISC-V TileLink Design
# ==============================================================================

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$Iverilog = "$ProjectRoot\tools\iverilog\app\bin\iverilog.exe"
$Vvp = "$ProjectRoot\tools\iverilog\app\bin\vvp.exe"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Running CH7516 RISC-V TileLink MMIO Verification" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

& $Iverilog -g2012 -o "$PSScriptRoot\tb_ch7516_riscv_tilelink.vvp" `
    "$ProjectRoot\rtl\dp_8b10b_decoder.v" `
    "$ProjectRoot\rtl\dp_descrambler.v" `
    "$ProjectRoot\rtl\dp_pixel_unpacker_4lane.v" `
    "$ProjectRoot\rtl\video_async_fifo.v" `
    "$ProjectRoot\rtl\video_timing_generator.v" `
    "$ProjectRoot\rtl\video_bist_pattern.v" `
    "$ProjectRoot\rtl\lvds_formatter_vesa8.v" `
    "$ProjectRoot\rtl\lvds_serializer_7to1.v" `
    "$ProjectRoot\rtl\ch7516_dp_to_lvds_top.v" `
    "$ProjectRoot\rtl\ch7516_tilelink_mmio.v" `
    "$PSScriptRoot\tb_ch7516_riscv_tilelink.v"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] RISC-V testbench compilation failed!" -ForegroundColor Red
    exit 1
}

& $Vvp "$PSScriptRoot\tb_ch7516_riscv_tilelink.vvp"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] RISC-V testbench simulation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n=================================================================" -ForegroundColor Green
Write-Host " RISC-V TILELINK SIMULATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green

@echo off
set PROJECT_ROOT=%~dp0..
set IVERILOG=%PROJECT_ROOT%\tools\iverilog\app\bin\iverilog.exe
set VVP=%PROJECT_ROOT%\tools\iverilog\app\bin\vvp.exe

echo =================================================================
echo  Running CH7516 RISC-V TileLink MMIO Verification
echo =================================================================

"%IVERILOG%" -g2012 -o "%~dp0tb_ch7516_riscv_tilelink.vvp" ^
    "%PROJECT_ROOT%\rtl\dp_8b10b_decoder.v" ^
    "%PROJECT_ROOT%\rtl\dp_descrambler.v" ^
    "%PROJECT_ROOT%\rtl\dp_pixel_unpacker_4lane.v" ^
    "%PROJECT_ROOT%\rtl\video_async_fifo.v" ^
    "%PROJECT_ROOT%\rtl\video_timing_generator.v" ^
    "%PROJECT_ROOT%\rtl\video_bist_pattern.v" ^
    "%PROJECT_ROOT%\rtl\lvds_formatter_vesa8.v" ^
    "%PROJECT_ROOT%\rtl\lvds_serializer_7to1.v" ^
    "%PROJECT_ROOT%\rtl\ch7516_dp_to_lvds_top.v" ^
    "%PROJECT_ROOT%\rtl\ch7516_tilelink_mmio.v" ^
    "%~dp0tb_ch7516_riscv_tilelink.v"

if %ERRORLEVEL% neq 0 (
    echo [ERROR] RISC-V testbench compilation failed!
    exit /b %ERRORLEVEL%
)

"%VVP%" "%~dp0tb_ch7516_riscv_tilelink.vvp"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] RISC-V testbench simulation failed!
    exit /b %ERRORLEVEL%
)

echo.
echo =================================================================
echo  RISC-V TILELINK SIMULATION COMPLETED SUCCESSFULLY!
echo =================================================================

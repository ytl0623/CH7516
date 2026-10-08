@echo off
set PROJECT_ROOT=%~dp0..
set IVERILOG=%PROJECT_ROOT%\tools\iverilog\app\bin\iverilog.exe
set VVP=%PROJECT_ROOT%\tools\iverilog\app\bin\vvp.exe

echo =================================================================
echo  Running CH7516 DisplayPort to LVDS Verilog Verification Suite
echo =================================================================

echo.
echo [Step 1/2] Compiling and running Unit Tests...
"%IVERILOG%" -g2012 -o "%~dp0tb_unit_tests.vvp" ^
    "%PROJECT_ROOT%\rtl\dp_8b10b_decoder.v" ^
    "%PROJECT_ROOT%\rtl\dp_descrambler.v" ^
    "%PROJECT_ROOT%\rtl\lvds_formatter_vesa8.v" ^
    "%~dp0tb_unit_tests.v"

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Unit test compilation failed!
    exit /b %ERRORLEVEL%
)

"%VVP%" "%~dp0tb_unit_tests.vvp"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Unit test simulation failed!
    exit /b %ERRORLEVEL%
)

echo.
echo [Step 2/2] Compiling and running Top-Level System Testbench...
"%IVERILOG%" -g2012 -o "%~dp0tb_ch7516_top.vvp" ^
    "%PROJECT_ROOT%\rtl\dp_8b10b_decoder.v" ^
    "%PROJECT_ROOT%\rtl\dp_descrambler.v" ^
    "%PROJECT_ROOT%\rtl\dp_pixel_unpacker_4lane.v" ^
    "%PROJECT_ROOT%\rtl\video_async_fifo.v" ^
    "%PROJECT_ROOT%\rtl\video_timing_generator.v" ^
    "%PROJECT_ROOT%\rtl\video_bist_pattern.v" ^
    "%PROJECT_ROOT%\rtl\lvds_formatter_vesa8.v" ^
    "%PROJECT_ROOT%\rtl\lvds_serializer_7to1.v" ^
    "%PROJECT_ROOT%\rtl\ch7516_dp_to_lvds_top.v" ^
    "%~dp0tb_ch7516_top.v"

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Top testbench compilation failed!
    exit /b %ERRORLEVEL%
)

"%VVP%" "%~dp0tb_ch7516_top.vvp"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Top testbench simulation failed!
    exit /b %ERRORLEVEL%
)

echo.
echo =================================================================
echo  ALL CH7516 VERILOG SIMULATIONS COMPLETED SUCCESSFULLY!
echo =================================================================

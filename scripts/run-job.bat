@echo off
setlocal

set "PDI_HOME=D:\data-integration"
set "PROJECT_HOME=%~dp0.."

call "%PDI_HOME%\Kitchen.bat" ^
  /file:"%PROJECT_HOME%\main\System_IBFT.kjb" ^
  /level:Basic

set "EXIT_CODE=%ERRORLEVEL%"
echo.
echo Kitchen exit code: %EXIT_CODE%
pause
exit /b %EXIT_CODE%
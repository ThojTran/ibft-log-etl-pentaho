<<<<<<< HEAD
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
=======
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
>>>>>>> 995f68a5108a3cdfd7c3854aa3f7c85331e302f6
exit /b %EXIT_CODE%
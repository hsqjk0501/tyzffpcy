@echo off
cd /d "%~dp0"
echo.
echo ============================================
echo   Pushing game to GitHub, please wait...
echo   If a GitHub sign-in window pops up,
echo   please complete the login there.
echo ============================================
echo.
git add index.html photos/ change-photos.ps1
git diff --cached --quiet || git commit -m "update photos"
git push origin main
if errorlevel 1 goto fail
echo.
echo   [OK] Pushed successfully!
echo.
echo   URL: https://hsqjk0501.github.io/tyzffpcy/
echo   Refresh it in about 1 minute to see the new version.
goto end
:fail
echo.
echo   [FAILED] Not signed in or no network.
echo   Please retry and finish the GitHub sign-in window.
:end
echo.
pause
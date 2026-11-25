@echo off
echo.
echo [1/2] Building Flutter Web (Release)...
call flutter build web --release
if errorlevel 1 (
    echo.
    echo [ERROR] Flutter build failed! Aborting deployment.
    exit /b %errorlevel%
)

echo.
echo [2/2] Deploying to Firebase Hosting...
call firebase deploy --only hosting
if errorlevel 1 (
    echo.
    echo [ERROR] Firebase deployment failed!
    exit /b %errorlevel%
)

echo.
echo [SUCCESS] Deployed to https://assetpulse-pro.web.app

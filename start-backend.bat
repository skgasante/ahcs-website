@echo off
echo Starting AHCS Backend Server...
echo Make sure you have Node.js installed (https://nodejs.org)
echo.
cd backend
npm install
if %errorlevel% neq 0 (
    echo Error installing dependencies. Please install Node.js first.
    pause
    exit /b 1
)
npm start
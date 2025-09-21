@echo off
echo Starting Xiangqi Flutter App...
echo.

echo Checking Flutter installation...
flutter --version
echo.

echo Getting dependencies...
flutter pub get
echo.

echo Running app on Windows...
flutter run -d windows

@echo off
echo Testing Engine Integration for Xiangqi Flutter App
echo.

echo Checking if engines exist...
if exist "engines\pikafish\win\pikafish.exe" (
    echo ✓ Pikafish engine found
) else (
    echo ✗ Pikafish engine not found
)

if exist "engines\pikafish\win\pikafish.nnue" (
    echo ✓ Pikafish NNUE file found
) else (
    echo ✗ Pikafish NNUE file not found
)

if exist "engines\eleeye\win\eleeye.exe" (
    echo ✓ EleEye engine found
) else (
    echo ✗ EleEye engine not found
)

echo.
echo Testing Pikafish engine...
engines\pikafish\win\pikafish.exe < test_pikafish.txt
echo.

echo Testing EleEye engine...
engines\eleeye\win\eleeye.exe < test_eleeye.txt
echo.

echo Engine testing completed!
pause

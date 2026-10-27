@echo off
setlocal
cd /d "%~dp0"

set "EMU_ID="
for /f "tokens=1 delims=•" %%i in ('flutter emulators ^| findstr /c:"• android"') do (
  if not defined EMU_ID set "EMU_ID=%%i"
)
for /f "tokens=* delims= " %%i in ("%EMU_ID%") do set "EMU_ID=%%i"

if not defined EMU_ID (
  echo Android emulator bulunamadi.
  echo Once Android Studio ^> Device Manager ile bir emulator olustur.
  echo Ardindan tekrar bu dosyayi calistir.
  exit /b 1
)

echo Emulator baslatiliyor: %EMU_ID%
flutter emulators --launch %EMU_ID%

echo Cihazlar bekleniyor...
flutter devices

echo Uygulama emulatorde calistiriliyor...
flutter run -d %EMU_ID%

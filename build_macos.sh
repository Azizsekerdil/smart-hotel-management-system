#!/usr/bin/env bash
# macOS .app paketi uretir (GitHub Actions macos-latest uzerinde calisir).
# Not: "set -u" bilincli olarak KULLANILMAZ - macOS'un bash 3.2'si bos dizi
# acilimini ("${DIZI[@]}") unbound sayar ve derleme aninda patlar.
set -eo pipefail

cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "HATA: macOS .app paketi bir Mac uzerinde olusturulmalidir."
  exit 1
fi

APP_NAME="AkilliKonaklama"

PYTHON_BIN="${PYTHON_BIN:-python3}"
"$PYTHON_BIN" -m pip install --upgrade pip
"$PYTHON_BIN" -m pip install -r requirements.txt
"$PYTHON_BIN" -m pip install pyinstaller

rm -rf build/macos "dist/${APP_NAME}.app"
mkdir -p build/macos

# --- Ikon: Windows .ico macOS'ta gecersiz; png'den .icns uretilir ---
ICON_ARGS=()
ICON_PNG="app/ui/resources/icons/app.png"
if command -v sips >/dev/null && command -v iconutil >/dev/null && [[ -f "$ICON_PNG" ]]; then
  ICONSET="build/macos/${APP_NAME}.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "build/macos/${APP_NAME}.icns"
  ICON_ARGS=(--icon "$PROJECT_ROOT/build/macos/${APP_NAME}.icns")
fi

# --- Veri dosyalari (packaging/hotel.spec ile ayni kapsam) ---
# --specpath kullanildigi icin yollar MUTLAK verilir.
DATA_ARGS=(
  --add-data "$PROJECT_ROOT/alembic:alembic"
  --add-data "$PROJECT_ROOT/alembic.ini:."
  --add-data "$PROJECT_ROOT/.env.example:."
)
[[ -d app/ui/resources ]] && DATA_ARGS+=(--add-data "$PROJECT_ROOT/app/ui/resources:app/ui/resources")
[[ -d app/ui/i18n ]] && DATA_ARGS+=(--add-data "$PROJECT_ROOT/app/ui/i18n:app/ui/i18n")

"$PYTHON_BIN" -m PyInstaller --noconfirm --clean --onedir --windowed \
  --workpath build/macos/pyinstaller --specpath build/macos \
  --distpath dist \
  --name "$APP_NAME" \
  --osx-bundle-identifier "com.akillikonaklama.desktop" \
  --paths "$PROJECT_ROOT" \
  "${ICON_ARGS[@]}" "${DATA_ARGS[@]}" \
  --collect-submodules app.ui.pages \
  --collect-submodules app.ui.dialogs \
  --collect-submodules alembic \
  --hidden-import logging.config \
  --hidden-import logging.handlers \
  --hidden-import sqlalchemy.dialects.sqlite \
  --hidden-import keyring.backends.macOS \
  --hidden-import reportlab.graphics.barcode \
  --exclude-module PySide6.QtQuick \
  --exclude-module PySide6.QtQml \
  --exclude-module PySide6.QtWebEngineCore \
  --exclude-module PySide6.QtWebEngineWidgets \
  --exclude-module PySide6.QtMultimedia \
  --exclude-module PySide6.Qt3DCore \
  --exclude-module PySide6.QtDataVisualization \
  --exclude-module PySide6.QtBluetooth \
  --exclude-module PySide6.QtNfc \
  --exclude-module PySide6.QtPositioning \
  --exclude-module PySide6.QtSensors \
  --exclude-module PySide6.QtSerialPort \
  --exclude-module PySide6.QtTest \
  --exclude-module pytest \
  --exclude-module black \
  --exclude-module ruff \
  --exclude-module mypy \
  --exclude-module matplotlib \
  --exclude-module tkinter \
  "$PROJECT_ROOT/app/main.py"

APP_PATH="dist/${APP_NAME}.app"
[[ -d "$APP_PATH" ]] || { echo "HATA: $APP_PATH olusturulamadi."; exit 1; }

ditto -c -k --keepParent "$APP_PATH" "dist/${APP_NAME}-macOS.zip"
echo "Tamamlandi: $APP_PATH"
echo "Dagitim ZIP'i: dist/${APP_NAME}-macOS.zip"

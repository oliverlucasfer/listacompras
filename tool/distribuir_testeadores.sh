#!/usr/bin/env bash
# Distribui um APK de teste ao grupo `testadores` (Firebase App Distribution,
# F5-T05b). O build sai por ABI (`--split-per-abi`) e sem os símbolos de debug
# do `libapp.so` (`--split-debug-info`), reduzindo o download: o arm64 tem
# cerca de metade de um APK "fat" com os três ABIs.
#
# Uso:
#   FIREBASE_APP_ID="1:1234567890:android:abc123" ./tool/distribuir_testeadores.sh "notas da versão"
#
# O app-id é o do console do Firebase (Projeto → Configurações → seu app Android).
set -euo pipefail

APP_ID="${FIREBASE_APP_ID:-}"
if [ -z "$APP_ID" ]; then
  echo "Defina FIREBASE_APP_ID (app-id do console do Firebase)." >&2
  exit 1
fi

NOTES="${1:-Minhas Listas (RF-31): app local, sem conta, com backup exportar/importar.}"

flutter build apk --release \
  --split-per-abi \
  --target-platform android-arm,android-arm64 \
  --split-debug-info=build/symbols

APK="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
echo "APK arm64: $APK"

firebase appdistribution:distribute "$APK" \
  --app "$APP_ID" --groups testadores --release-notes "$NOTES"

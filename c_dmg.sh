#!/usr/bin/env bash

# Define variables for clarity
APP_NAME="youtube_widget_macos" # Replace with your actual app name
APP_PATH="build/macos/Build/Products/Release/$APP_NAME.app"
DMG_NAME="$APP_NAME Installer.dmg"
DMG_BACKGROUND_IMAGE="dmg_assets/dmg_background.png" # Optional: path to your background image
# DMG_LICENSE_FILE="dmg_assets/LICENSE.rtf" # Optional: path to your RTF license file

create-dmg \
  --volname "$APP_NAME Installer" \
  --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
  --background "$DMG_BACKGROUND_IMAGE" \
  --window-pos 200 120 \
  --window-size 700 500 \
  --icon-size 100 \
  --text-size 14 \
  "$DMG_NAME" \
  "$APP_PATH"
  # If you have a license file, uncomment the line below:
  # --eula "$DMG_LICENSE_FILE" \

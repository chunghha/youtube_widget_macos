#!/bin/bash

# Script to generate macOS .iconset PNGs from a single source image using ImageMagick's convert.
# After running this script, you'll need to use 'iconutil' to create the .icns file.

# --- Configuration ---
SOURCE_ICON="icon.png" # Your 512x512 icon file
OUTPUT_DIR="AppIcon.iconset" # The folder where resized PNGs will be stored
# ---------------------

# Check if ImageMagick's 'magick' command is available
if ! command -v magick &> /dev/null
then
    echo "Error: ImageMagick 'magick' command not found."
    echo "Please install ImageMagick (e.g., 'brew install imagemagick' on macOS)."
    echo "If you have an older version of ImageMagick, you might need to use 'convert' instead of 'magick convert'."
    exit 1
fi

# Check if the source icon exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo "Error: Source icon '$SOURCE_ICON' not found."
    echo "Please make sure '$SOURCE_ICON' is in the same directory as this script, or update the SOURCE_ICON variable."
    exit 1
fi

# Create the output directory
if [ -d "$OUTPUT_DIR" ]; then
    echo "Removing existing '$OUTPUT_DIR' directory..."
    rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"
echo "Created '$OUTPUT_DIR' directory."

# Define the required icon sizes and their corresponding filenames
declare -A ICON_SIZES
ICON_SIZES=(
    [16]="icon_16x16.png"
    [32]="icon_16x16@2x.png icon_32x32.png"
    [64]="icon_32x32@2x.png"
    [128]="icon_128x128.png"
    [256]="icon_128x128@2x.png icon_256x256.png"
    [512]="icon_256x256@2x.png icon_512x512.png"
    [1024]="icon_512x512@2x.png" # This will be 1024x1024, named as 512@2x
)

echo "Generating icon sizes..."
for size in "${!ICON_SIZES[@]}"; do
    filenames=${ICON_SIZES[$size]}
    for filename in $filenames; do
        echo "  - Resizing to ${size}x${size} for $filename"
        # Changed 'convert' to 'magick convert'
        magick convert "$SOURCE_ICON" -resize "${size}x${size}" "$OUTPUT_DIR/$filename"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to convert $SOURCE_ICON to $filename."
            exit 1
        fi
    done
done

echo "All PNGs generated successfully in '$OUTPUT_DIR/'."
echo ""
echo "--- Next Steps ---"
echo "1. Navigate to the directory containing '$OUTPUT_DIR' in your terminal."
echo "   Example: cd $(dirname "$0")"
echo "2. Run 'iconutil' to create the .icns file:"
echo "   iconutil -c icns $OUTPUT_DIR"
echo "3. This will create 'AppIcon.icns' in the same directory."
echo "4. Copy 'AppIcon.icns' to your Flutter project's macOS assets:"
echo "   cp AppIcon.icns your_flutter_project_root/macos/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "5. Clean and rebuild your Flutter macOS app:"
echo "   cd your_flutter_project_root"
echo "   flutter clean"
echo "   flutter build macos"
echo "   flutter run -d macos"
echo "------------------"

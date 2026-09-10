#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 <ipa_path> <output_path>"
    exit 1
fi

IPA_PATH="$1"
OUTPUT_PATH="$2"
START_TIME=$(date +%s)

if [[ ! -f "$IPA_PATH" ]]; then
    echo -e "${RED}Error: .ipa file not found: $IPA_PATH${NC}"
    exit 1
fi

if [[ -z "$OUTPUT_PATH" ]]; then
    OUTPUT_PATH=$(mktemp -d)
    echo -e "${YELLOW}Output path not specified. Using temporary directory: $OUTPUT_PATH${NC}"
fi

IPA_DIRNAME=$(dirname "$IPA_PATH")
IPA_BASENAME=$(basename "$IPA_PATH")

EXTRACT_DIR="$IPA_DIRNAME/${IPA_BASENAME%.ipa}_extract"
mkdir -p "$EXTRACT_DIR"

trap 'rm -rf "$EXTRACT_DIR"' EXIT

unzip -q "$IPA_PATH" -d "$EXTRACT_DIR"

APP_PATH=$(find "$EXTRACT_DIR/Payload" -maxdepth 1 -type d -name "*.app" | head -n 1)
DEFAULT_APP_PATH="$APP_PATH"
FLUTTER_APP_PATH="$APP_PATH/Frameworks/App.framework/App"
UNITY_APP_PATH="$APP_PATH/Frameworks/UnityFramework.framework/UnityFramework"

APP_TYPE="native"

if [[ -f "$FLUTTER_APP_PATH" ]]; then
    APP_TYPE="flutter"
elif [[ -f "$UNITY_APP_PATH" ]]; then
    APP_TYPE="unity"
fi

case $APP_TYPE in
    native)
        echo "Native iOS application"
        ;;
    flutter)
        echo "Flutter iOS application"
        APP_PATH="$FLUTTER_APP_PATH"
        ;;
    unity)
        echo "Unity iOS application"
        APP_PATH="$UNITY_APP_PATH"
        ;;
    *)
        echo -e "${RED}Error: Unknown application type${NC}"
        exit 1
        ;;
esac

if [[ -z "$APP_PATH" ]]; then
    echo -e "${RED}Error: .app directory not found in .ipa file${NC}"
    exit 1
fi

APP_NAME=$(basename "$APP_PATH" .app)
DEFAULT_APP_NAME=$(basename "$DEFAULT_APP_PATH" .app)
BINARY_PATH="$APP_PATH/$APP_NAME"
DEFAULT_BINARY_PATH="$DEFAULT_APP_PATH/$DEFAULT_APP_NAME"

if [[ ! -f "$BINARY_PATH" ]]; then
    BINARY_PATH=$(find "$APP_PATH" -maxdepth 1 -type f -perm +111 | head -n 1)
fi

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "Error: binary not found"
    exit 1
fi

BINARY_DIRNAME=$(dirname "$DEFAULT_BINARY_PATH")
INFO_PLIST="$BINARY_DIRNAME/Info.plist"

handle_result() {
    local file="$1"
    local title="$2"
    if [[ "$(wc -l < "$file" | tr -d ' ')" -gt 0 ]]; then
        echo -e "${GREEN}$title exported: $file${NC}"
    else
        echo -e "${RED}Failed to create $title${NC}"
    fi
}

strings "$BINARY_PATH" | awk 'length>=1 && /[^ -~]/==0' | sort -u > "$OUTPUT_PATH/strings.txt" || touch "$OUTPUT_PATH/strings.txt"
if [[ "$APP_TYPE" != "native" ]]; then 
    find "$DEFAULT_APP_PATH" -type f \( -name "*.framework/*" -o -name "*.dylib" \) -perm +111 | \
    while read binary; do
        strings "$binary" >> "$OUTPUT_PATH/strings.txt"
    done
fi
handle_result "$OUTPUT_PATH/strings.txt" "Strings"

if [[ "$APP_TYPE" == "flutter" ]]; then
    WORKING_PATH="$DEFAULT_BINARY_PATH"
else
    WORKING_PATH="$BINARY_PATH"
fi

otool -L "$WORKING_PATH" | sort > "$OUTPUT_PATH/frameworks.txt" || touch "$OUTPUT_PATH/frameworks.txt"
handle_result "$OUTPUT_PATH/frameworks.txt" "Frameworks"

nm -u "$WORKING_PATH" | sort > "$OUTPUT_PATH/external_symbols.txt" || touch "$OUTPUT_PATH/external_symbols.txt"
handle_result "$OUTPUT_PATH/external_symbols.txt" "External symbols"

otool -oV "$WORKING_PATH" > "$OUTPUT_PATH/objc.txt" || touch "$OUTPUT_PATH/objc.txt"
handle_result "$OUTPUT_PATH/objc.txt" "Objective-C"

shasum -a 256 "$BINARY_PATH" | awk '{print $1}' > "$OUTPUT_PATH/binary_hash.txt" || touch "$OUTPUT_PATH/binary_hash.txt"
handle_result "$OUTPUT_PATH/binary_hash.txt" "Binary hash"

plutil -p "$INFO_PLIST" > "$OUTPUT_PATH/info_plist.txt" || touch "$OUTPUT_PATH/info_plist.txt"
handle_result "$OUTPUT_PATH/info_plist.txt" "Info.plist"

find "$DEFAULT_APP_PATH" \( -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.pdf" \) \) \
    -print0 | \
    while IFS= read -r -d '' media; do
        shasum -a 256 "$media" | awk '{print $1}'
    done | sort -u > "$OUTPUT_PATH/assets_hashes.txt" || touch "$OUTPUT_PATH/assets_hashes.txt"

find "$APP_PATH" \( -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.pdf" \) \) \
    -print0 | \
    while IFS= read -r -d '' media; do
        shasum -a 256 "$media" | awk '{print $1}'
    done | sort -u >> "$OUTPUT_PATH/assets_hashes.txt"
handle_result "$OUTPUT_PATH/assets_hashes.txt" "Assets hashes"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo -e "${CYAN}Extraction completed ${MINUTES}:$(printf "%02d" $SECONDS)${NC}"
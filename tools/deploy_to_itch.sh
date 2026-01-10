#!/bin/bash

# Configuration
# Replace these with your Itch.io username and game slug
ITCH_USER="mangelsr"
GAME_SLUG="fourty-last-bet"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting deployment for $ITCH_USER/$GAME_SLUG...${NC}"

# Check if butler is installed
if ! command -v butler &> /dev/null; then
    echo -e "${RED}Error: butler is not installed.${NC}"
    echo "Please install it from: https://itch.io/docs/butler/installing.html"
    exit 1
fi

# Check for build directory (adjust path as needed)
BUILD_DIR="../builds"
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${RED}Error: Build directory '$BUILD_DIR' not found.${NC}"
    echo "Please make sure you have exported your project to the 'builds' directory."
    exit 1
fi

# Deploy
# You can specify channels like 'windows', 'linux', 'mac', 'web'
# This script assumes a structure like builds/web, builds/linux, etc.

echo "Looking for builds in $BUILD_DIR..."

for channel in "$BUILD_DIR"/*; do
    if [ -d "$channel" ]; then
        channel_name=$(basename "$channel")
        echo -e "Pushing channel: ${GREEN}$channel_name${NC}"
        butler push "$channel" "$ITCH_USER/$GAME_SLUG:$channel_name"
    fi
done

echo -e "${GREEN}Deployment complete!${NC}"
echo "Check your page at: https://$ITCH_USER.itch.io/$GAME_SLUG"

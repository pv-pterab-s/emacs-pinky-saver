#!/bin/bash

# Define file name for the recording
FILENAME=~/voice-interface/recordings/$(date +%Y%m%d%H%M%S).wav

# Ensure the recordings directory exists
mkdir -p ~/voice-interface/recordings

# Check for the operating system
OS=$(uname)

# Recording command based on the operating system
if [[ "$OS" == "Linux" ]]; then
    # Use parecord for Linux
    parecord --file-format=wav --format=u8 --rate=8000 --channels=1 "$FILENAME"
elif [[ "$OS" == "Darwin" ]]; then
    # Use sox for macOS ('Darwin' indicates macOS)
    sox -d -r 8000 -c 1 -b 8 "$FILENAME"
else
    echo "Unsupported operating system."
    exit 1
fi

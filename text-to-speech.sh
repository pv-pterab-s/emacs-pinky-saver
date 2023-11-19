#!/bin/bash
# -*- compile-command: "./text-to-speech.sh 'hey there'"; -*-
set -e

TEXT="$1"

API_TOKEN="YOUR_OPENAI_API_TOKEN"

curl https://api.openai.com/v1/audio/speech \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"tts-1\",
    \"input\": \"$TEXT\",
    \"voice\": \"nova\",
    \"response_format\": \"opus\"
  }" \
  --output ~/voice-interface/recordings/speech.opus

mplayer ~/voice-interface/recordings/speech.opus

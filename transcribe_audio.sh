#!/bin/bash
# -*- compile-command: "./transcribe_audio.sh"; -*-
set -e

# Path to the audio file to be transcribed
AUDIO_FILE=$1

# Your OpenAI API Token
API_TOKEN="YOUR_OPENAI_API_TOKEN"

# OpenAI Transcription API URL
API_URL="https://api.openai.com/v1/audio/transcriptions"

# Make the API request and save the response
curl --silent --request POST \
     --url $API_URL \
     --header "Authorization: Bearer $API_TOKEN" \
     --header 'Content-Type: multipart/form-data' \
     --form file=@$AUDIO_FILE \
     --form model=whisper-1 > ~/voice-interface/recordings/transcription_response.json

# Extract and output the transcription
# This assumes the response format includes a field "text" with the transcription
jq '.text' -r ~/voice-interface/recordings/transcription_response.json

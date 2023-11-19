#!/bin/bash

# Read the PID from the file and kill the recording process
kill $(cat ~/recordings/recording.pid)

# Optionally, remove the PID file
rm ~/recordings/recording.pid


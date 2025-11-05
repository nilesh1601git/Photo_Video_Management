#!/bin/bash

# load_modules.sh - Helper script to load all modules
# This script should be sourced from the main scripts to load all utility modules

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/file_utils.sh"
source "$SCRIPT_DIR/date_utils.sh"
source "$SCRIPT_DIR/exif_utils.sh"


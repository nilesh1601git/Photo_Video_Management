#!/bin/bash

# modify_time_avi.sh
# Modifies EXIF timestamps for AVI files based on filename
# Usage: modify_time_avi.sh [--dry-run] [file_pattern]

# Get the directory where this script is located (handle symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ -L "$SCRIPT_PATH" ]]; then
    # Resolve symlink to actual file
    SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Load modules
source "$SCRIPT_DIR/module/load_modules.sh"

# Default values
DRY_RUN=false
PATTERN="*.AVI"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            PATTERN="$1"
            shift
            ;;
    esac
done

# Check for exiftool
if ! check_exiftool; then
    exit 1
fi

print_info "Fixing EXIF timestamps using filename..."

# Process files matching pattern
for file in $PATTERN; do
    [[ -f "$file" ]] || continue
    
    print_info "Processing: $file"
    modify_exif_timestamp_from_filename "$file" "$DRY_RUN"
done

print_success "Done!"

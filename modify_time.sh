#!/bin/bash

# modify_time.sh
# Modifies EXIF timestamps based on filename
# Usage: modify_time.sh [--dry-run] [pattern]
# Example: ./modify_time.sh --dry-run *.AVI

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules
source "$SCRIPT_DIR/module/load_modules.sh"

# Default values
DRY_RUN=false
PATTERN="*.AVI"

# Parse command line arguments
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

if [[ -n "$1" ]]; then
    PATTERN="$1"
fi

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

#!/bin/bash

# rename_by_createdate.sh
# Renames a single file based on EXIF CreateDate
# Usage: rename_by_createdate.sh [--dry-run] <file>

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules
source "$SCRIPT_DIR/lib/load_modules.sh"

# Default values
DRY_RUN=false

# Parse command line arguments
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

file="$1"

if [[ -z "$file" ]]; then
    print_error "Usage: $0 [--dry-run] <file>"
    exit 1
fi

if [[ ! -f "$file" ]]; then
    print_error "File '$file' not found."
    exit 1
fi

# Check for exiftool
if ! check_exiftool; then
    exit 1
fi

created=$(get_exif_createdate "$file")

if [[ -z "$created" ]]; then
    print_error "No CreateDate found in '$file'."
    exit 1
fi

# Format date: YYYYMMDD_HHMMSS
formatted=$(echo "$created" | sed 's/[: ]//g' | cut -c1-15 | sed 's/\(........\)\(......\)/\1_\2/')
ext="${file##*.}"
ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
new_name="${formatted}.${ext_lower}"

if [[ "$file" == "$new_name" ]]; then
    print_success "'$file' is already correctly named."
elif [[ -e "$new_name" ]]; then
    print_warning "'$new_name' already exists. Skipping rename."
else
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Dry Run: '$file' → '$new_name'"
    else
        print_success "Renaming '$file' → '$new_name'"
        mv "$file" "$new_name"
    fi
fi

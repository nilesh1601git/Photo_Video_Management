#!/bin/bash

# bulk_rename_by_createdate.sh
# Renames multiple files based on EXIF CreateDate
# Usage: bulk_rename_by_createdate.sh [--dry-run] <pattern>
# Example: ./bulk_rename_by_createdate.sh --dry-run *.JPG

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules
source "$SCRIPT_DIR/module/load_modules.sh"

# Default values
DRY_RUN=false

# Parse command line arguments
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

# Pattern to match files
pattern="$1"

if [[ -z "$pattern" ]]; then
    print_error "Usage: $0 [--dry-run] <pattern>"
    exit 1
fi

# Loop through matching files
for file in $pattern; do
    if [[ -f "$file" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            ./rename_by_createdate.sh --dry-run "$file"
        else
            ./rename_by_createdate.sh "$file"
        fi
    fi
done

#!/bin/bash

# bulk_rename_by_createdate.sh
# Usage: bulk_rename_by_createdate.sh [--dry-run] <pattern>
# Example: ./bulk_rename_by_createdate.sh --dry-run *.JPG

dry_run_flag=""
if [[ "$1" == "--dry-run" ]]; then
    dry_run_flag="--dry-run"
    shift
fi

# Pattern to match files
pattern="$1"

if [[ -z "$pattern" ]]; then
    echo "Usage: $0 [--dry-run] <pattern>"
    exit 1
fi

# Loop through matching files
for file in $pattern; do
    if [[ -f "$file" ]]; then
        ./rename_by_createdate.sh $dry_run_flag "$file"
    fi
done

